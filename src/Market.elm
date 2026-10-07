module Market exposing
    ( activeListingCount
    , checkAccept
    , checkClose
    , checkNewOffer
    , confirmTrade
    , describe
    , describeTrade
    , isLive
    , item
    , markFellThrough
    , maxActiveListings
    , openOfferFrom
    , parseCoins
    , parsePrice
    , pricePoints
    , tradePending
    , tradeTerms
    , wasAccepted
    , unitPrice
    , validateDraft
    , validateOffer
    )

{-| Shared rules about listings and offers, used by both backend and frontend.
-}

import Dict exposing (Dict)
import Item exposing (Item)
import Pricing
import Time
import Types exposing (Listing, ListingDraft, Offer, OfferStatus(..), Payment(..), Side(..))


maxActiveListings : Int
maxActiveListings =
    20


maxPrice : Int
maxPrice =
    1000000000


maxQuantity : Int
maxQuantity =
    1000000


{-| For listing notes and offer messages.
-}
maxTextLength : Int
maxTextLength =
    280


isLive : Time.Posix -> Listing -> Bool
isLive now listing =
    Time.posixToMillis listing.liveAt <= Time.posixToMillis now


activeListingCount : String -> List Listing -> Int
activeListingCount trader listings =
    listings |> List.filter (\l -> l.trader == trader && not l.closed) |> List.length


item : Listing -> Maybe Item
item listing =
    Item.byId listing.itemId


{-| "Selling 2x fine Iron bar" or "Buying 1x rare Camel egg", for logs and
admin lists.
-}
describe : Listing -> String
describe listing =
    (case listing.side of
        Selling ->
            "Selling "

        Buying ->
            "Buying "
    )
        ++ describeItems listing


{-| "Juno Trek sells 1x Shovel axe to Wanderling for 9800 coins", with the
coins written the way the trade window shows them.
-}
describeTrade : Listing -> Offer -> String
describeTrade listing offer =
    let
        terms =
            tradeTerms listing offer
    in
    terms.seller ++ " sells " ++ describeItems listing ++ " to " ++ terms.buyer ++ " for " ++ String.fromInt terms.coins ++ " coins"


describeItems : Listing -> String
describeItems listing =
    String.fromInt listing.quantity
        ++ "x "
        ++ (if listing.variant.fine then
                "fine "

            else if listing.variant.rare then
                "rare "

            else
                ""
           )
        ++ (item listing |> Maybe.map (\i -> Item.fullName i listing.variant) |> Maybe.withDefault listing.itemId)


unitPrice : Listing -> Maybe Int
unitPrice listing =
    case listing.payment of
        Coins price ->
            Just price


{-| What changes hands if `offer` on `listing` is traded: who hands over the
items, who pays, and the total coins (the offer's price each, or the listed
price for an offer "at your price").
-}
tradeTerms : Listing -> Offer -> { seller : String, buyer : String, coins : Int }
tradeTerms listing offer =
    let
        each =
            case ( offer.price, listing.payment ) of
                ( Just price, _ ) ->
                    price

                ( Nothing, Coins price ) ->
                    price

        coins =
            each * listing.quantity
    in
    case listing.side of
        Selling ->
            { seller = listing.trader, buyer = offer.from, coins = coins }

        Buying ->
            { seller = offer.from, buyer = listing.trader, coins = coins }


{-| `trader`'s open offer on a listing, if they have one. A trader has at
most one; making another offer updates it.
-}
openOfferFrom : String -> Int -> List Offer -> Maybe Offer
openOfferFrom trader listingId offers =
    offers
        |> List.filter (\o -> o.listingId == listingId && o.from == trader && o.status == OfferOpen)
        |> List.head



-- TRADES


{-| Accepted at some point: pending, completed or fell through.
-}
wasAccepted : OfferStatus -> Bool
wasAccepted status =
    case status of
        OfferAccepted ->
            True

        OfferCompleted _ ->
            True

        OfferFellThrough _ ->
            True

        _ ->
            False


{-| An accepted offer on the listing that nobody has resolved yet. While there
is one, the listing is reserved for that trade.
-}
tradePending : Int -> List Offer -> Bool
tradePending listingId offers =
    List.any (\o -> o.listingId == listingId && o.status == OfferAccepted) offers


whenNoTradePending : String -> Listing -> List Offer -> Result String ()
whenNoTradePending err listing offers =
    if tradePending listing.id offers then
        Err err

    else
        Ok ()


checkAccept : Listing -> List Offer -> Result String ()
checkAccept =
    whenNoTradePending "Finish the pending trade on this listing before you accept another offer."


checkNewOffer : Listing -> List Offer -> Result String ()
checkNewOffer =
    whenNoTradePending "A trade is pending on this listing, so it isn't taking offers right now."


checkClose : Listing -> List Offer -> Result String ()
checkClose =
    whenNoTradePending "You can't close this listing while a trade is pending. Mark the trade as gone through or fallen through first."


{-| A pending trade that `trader` is one side of.
-}
pendingTradeFor : String -> Listing -> Offer -> Result String Offer
pendingTradeFor trader listing offer =
    if trader /= listing.trader && trader /= offer.from then
        Err "Only the two traders can do that."

    else if offer.status /= OfferAccepted then
        Err "That trade isn't pending."

    else
        Ok offer


{-| `trader` says the trade went through. Once both sides have, it's completed.
-}
confirmTrade : String -> Time.Posix -> Listing -> Offer -> Result String Offer
confirmTrade trader now listing offer =
    pendingTradeFor trader listing offer
        |> Result.map
            (\o ->
                let
                    confirmed =
                        if trader == listing.trader then
                            { o | listerConfirmed = True }

                        else
                            { o | offererConfirmed = True }
                in
                if confirmed.listerConfirmed && confirmed.offererConfirmed then
                    { confirmed | status = OfferCompleted now }

                else
                    confirmed
            )


{-| `trader` says the trade fell through. Either side can, and it's final.
-}
markFellThrough : String -> String -> Time.Posix -> Listing -> Offer -> Result String Offer
markFellThrough trader reason now listing offer =
    pendingTradeFor trader listing offer
        |> Result.andThen
            (\o ->
                checkText "reason" reason
                    |> Result.andThen
                        (\trimmed ->
                            if String.isEmpty trimmed then
                                Err "Say what happened, in a few words."

                            else
                                Ok { o | status = OfferFellThrough { by = trader, at = now, reason = trimmed } }
                        )
            )



-- VALIDATION


{-| Read a coin amount the way players type it: "9400", "9,400" or "9.4k".
-}
parseCoins : String -> Maybe Int
parseCoins s =
    let
        t =
            s |> String.replace "," "" |> String.replace " " "" |> String.toLower
    in
    if String.endsWith "k" t then
        String.toFloat (String.dropRight 1 t) |> Maybe.map (\f -> round (f * 1000))

    else
        String.toInt t


{-| A coin price typed into a form, checked the same way the backend checks it.
-}
parsePrice : String -> Result String Int
parsePrice s =
    parseCoins s
        |> Result.fromMaybe "Enter a price in coins, like 1200 or 1.2k."
        |> Result.andThen checkPrice


checkPrice : Int -> Result String Int
checkPrice price =
    if price <= 0 then
        Err "Enter a price above zero."

    else if price > maxPrice then
        Err "Keep the price under a billion coins."

    else
        Ok price


checkText : String -> String -> Result String String
checkText what text =
    if String.length text > maxTextLength then
        Err ("Keep your " ++ what ++ " under " ++ String.fromInt maxTextLength ++ " characters.")

    else
        Ok (String.trim text)


{-| Check a new listing. The frontend runs this before sending, and the
backend runs it again on what arrives.
-}
validateDraft : ListingDraft -> Result String ListingDraft
validateDraft draft =
    case Item.byId draft.itemId of
        Nothing ->
            Err "Pick an item from the list."

        Just listed ->
            if Item.normalizeVariant listed draft.variant /= draft.variant then
                Err "This item doesn't come in that version."

            else if draft.quantity <= 0 then
                Err "Enter a quantity above zero."

            else if draft.quantity > maxQuantity then
                Err "Keep the quantity under a million."

            else
                Result.map2 (\_ note -> { draft | note = note })
                    (case draft.payment of
                        Coins price ->
                            checkPrice price
                    )
                    (checkText "note" draft.note)


{-| Check an offer's price (`Nothing` means "at your price") and message.
-}
validateOffer : Maybe Int -> String -> Result String { price : Maybe Int, message : String }
validateOffer price message =
    Result.map2 (\p m -> { price = p, message = m })
        (case price of
            Just p ->
                checkPrice p |> Result.map Just

            Nothing ->
                Ok Nothing
        )
        (checkText "message" message)



-- PRICES


{-| Price points for one listing: its own coin price, plus each offer on it
that wasn't withdrawn. An offer "at your price" counts as another vote for the
listed price.
-}
listingPoints : List Offer -> Listing -> List Pricing.Point
listingPoints offers listing =
    case unitPrice listing of
        Just price ->
            let
                own =
                    { price = price
                    , trader = listing.trader
                    , at = listing.createdAt
                    , source =
                        if listing.side == Selling then
                            Pricing.Ask

                        else
                            Pricing.Bid
                    }

                fromOffers =
                    offers
                        |> List.filter (\o -> o.listingId == listing.id && o.status /= OfferWithdrawn)
                        |> List.map
                            (\o ->
                                { price = Maybe.withDefault price o.price
                                , trader = o.from
                                , at = o.at
                                , source = Pricing.Offer
                                }
                            )
            in
            own :: fromOffers

        Nothing ->
            []


{-| All price points for a price series (see `Item.priceKey`), from live listings.
-}
pricePoints : Time.Posix -> Dict Int Listing -> Dict Int Offer -> String -> List Pricing.Point
pricePoints now listings offers key =
    let
        offerList =
            Dict.values offers
    in
    listings
        |> Dict.values
        |> List.filter (\l -> isLive now l && Item.priceKey l.itemId l.variant == key)
        |> List.concatMap (listingPoints offerList)
        |> List.sortBy (.at >> Time.posixToMillis)
