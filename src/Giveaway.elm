module Giveaway exposing
    ( Entries
    , current
    , entries
    , hasEnded
    , hoursFromDays
    , isOpen
    , isRunning
    , maxEntries
    , open
    , pickWeighted
    , timeLeft
    , total
    , validateDraft
    )

{-| Giveaway rules shared by both sides: who has how many entries, which
giveaway is on, and drawing the winner.

Entering gives 1 entry. Posting a listing, making an offer and completing a
trade each give 1 more, once each, if they happened while the giveaway ran. They
count even if they happened before the trader entered.

-}

import Dict exposing (Dict)
import Market
import Time
import Types exposing (Giveaway, GiveawayDraft, Listing, Offer, OfferStatus(..))


type alias Entries =
    { entered : Bool
    , listed : Bool
    , offered : Bool
    , traded : Bool
    }


maxEntries : Int
maxEntries =
    4


{-| The longest a giveaway can run: 60 days.
-}
maxHours : Int
maxHours =
    60 * 24


millis : Time.Posix -> Int
millis =
    Time.posixToMillis


during : Giveaway -> Time.Posix -> Bool
during giveaway at =
    millis giveaway.startsAt <= millis at && millis at < millis giveaway.endsAt


isRunning : Time.Posix -> Giveaway -> Bool
isRunning now giveaway =
    millis now < millis giveaway.endsAt


hasEnded : Time.Posix -> Giveaway -> Bool
hasEnded now giveaway =
    not (isRunning now giveaway)


{-| Running, or over and waiting for its winner to be drawn.
-}
isOpen : Giveaway -> Bool
isOpen giveaway =
    giveaway.winner == Nothing


{-| The giveaway that hasn't been drawn yet. There's at most one.
-}
open : List Giveaway -> Maybe Giveaway
open =
    List.filter isOpen >> List.head


{-| The giveaway to show people: the open one, or else the last one drawn, for
a week after it ended so its winner is announced.
-}
current : Time.Posix -> List Giveaway -> Maybe Giveaway
current now giveaways =
    case open giveaways of
        Just giveaway ->
            Just giveaway

        Nothing ->
            giveaways
                |> List.filter (\g -> millis now - millis g.endsAt < 7 * 24 * 60 * 60 * 1000)
                |> List.sortBy (.endsAt >> millis >> negate)
                |> List.head


{-| What `name` has done that counts for this giveaway. `entered` is whether
they opted in; the rest only count once they have.
-}
entries : Giveaway -> Dict Int Listing -> Dict Int Offer -> String -> Entries
entries giveaway listings offers name =
    let
        offerList =
            Dict.values offers

        isTrader offer =
            offer.from == name || (Dict.get offer.listingId listings |> Maybe.map .trader) == Just name
    in
    { entered = List.member name giveaway.entrants
    , listed = listings |> Dict.values |> List.any (\l -> l.trader == name && during giveaway l.createdAt)
    , offered = offerList |> List.any (\o -> o.from == name && during giveaway o.at)
    , traded =
        offerList
            |> List.any
                (\o ->
                    case o.status of
                        OfferCompleted at ->
                            during giveaway at && isTrader o

                        _ ->
                            False
                )
    }


{-| How many entries in the draw: none until they enter.
-}
total : Entries -> Int
total e =
    if e.entered then
        [ True, e.listed, e.offered, e.traded ] |> List.filter identity |> List.length

    else
        0


{-| "7" or "1.5" days as whole hours, at least one.
-}
hoursFromDays : String -> Result String Int
hoursFromDays text =
    case String.toFloat (String.trim text) of
        Just days ->
            let
                hours =
                    round (days * 24)
            in
            if hours < 1 then
                Err "Run it for at least an hour."

            else if hours > maxHours then
                Err ("Run it for at most " ++ String.fromInt (maxHours // 24) ++ " days.")

            else
                Ok hours

        Nothing ->
            Err "Enter how many days it runs, like 7."


{-| The admin form runs this before sending, and the backend again on what
arrives.
-}
validateDraft : GiveawayDraft -> Result String GiveawayDraft
validateDraft draft =
    let
        title =
            String.trim draft.title
    in
    if String.isEmpty title then
        Err "Give the giveaway a name, like \"Travel bundle\"."

    else if String.length title > 60 then
        Err "Keep the name under 60 characters."

    else if List.isEmpty draft.prizes then
        Err "Add at least one prize."

    else if List.length draft.prizes > Market.maxOfferItems then
        Err ("Add at most " ++ String.fromInt Market.maxOfferItems ++ " prizes.")

    else if draft.hours < 1 || draft.hours > maxHours then
        Err ("Run it for between an hour and " ++ String.fromInt (maxHours // 24) ++ " days.")

    else
        draft.prizes
            |> List.map Market.validateLine
            |> List.foldr (Result.map2 (::)) (Ok [])
            |> Result.map (\prizes -> { draft | title = title, prizes = prizes })


{-| The winner for a random number `roll` in [0, total weight): each name gets
a slice as wide as its weight.
-}
pickWeighted : Int -> List ( String, Int ) -> Maybe String
pickWeighted roll weighted =
    case weighted of
        ( name, weight ) :: rest ->
            if roll < weight || List.isEmpty rest then
                Just name

            else
                pickWeighted (roll - weight) rest

        [] ->
            Nothing


{-| "3d 4h", "4h 12m" or "12m 05s" until `endsAt`.
-}
timeLeft : Time.Posix -> Time.Posix -> String
timeLeft now endsAt =
    let
        seconds =
            max 0 ((millis endsAt - millis now) // 1000)

        days =
            seconds // 86400

        hours =
            modBy 24 (seconds // 3600)

        mins =
            modBy 60 (seconds // 60)

        pad n =
            String.padLeft 2 '0' (String.fromInt n)
    in
    if days > 0 then
        String.fromInt days ++ "d " ++ String.fromInt hours ++ "h"

    else if hours > 0 then
        String.fromInt hours ++ "h " ++ pad mins ++ "m"

    else
        String.fromInt mins ++ "m " ++ pad (modBy 60 seconds) ++ "s"
