module Page.Giveaway exposing (banner, view)

{-| The giveaway page (`/giveaway`) and the banner every other page shows
while there's a giveaway on. See `Giveaway` for how entries are counted.
-}

import Derived
import Dict
import Giveaway
import Html exposing (Html)
import Html.Attributes as Attr
import Item
import Route
import Time
import Types exposing (FrontendModel, FrontendMsg(..), Giveaway, ItemLine)
import Ui


myEntries : FrontendModel -> Giveaway -> Maybe Giveaway.Entries
myEntries model giveaway =
    Derived.myName model |> Maybe.map (Giveaway.entries giveaway model.listings model.offers)


{-| A strip under the header that links to the giveaway page: what's up for
grabs, how long is left, and how many entries you have.
-}
banner : FrontendModel -> Html msg
banner model =
    case ( model.route, Giveaway.current model.now (Dict.values model.giveaways) ) of
        ( Route.GiveawayPage, _ ) ->
            Ui.empty

        ( _, Just giveaway ) ->
            let
                ( status, cta ) =
                    case giveaway.winner of
                        Just winner ->
                            ( "GIVEAWAY ENDED"
                            , if Derived.myName model == Just winner then
                                chip "bg-leaf text-shell" "You won!"

                              else
                                chip "border border-[#4a3470] text-soft" ("Won by " ++ winner)
                            )

                        Nothing ->
                            if Giveaway.hasEnded model.now giveaway then
                                ( "GIVEAWAY ENDED", chip "border border-[#4a3470] text-soft" "Drawing soon" )

                            else
                                ( "GIVEAWAY · ENDS IN " ++ Giveaway.timeLeft model.now giveaway.endsAt
                                , case myEntries model giveaway of
                                    Just entries ->
                                        if entries.entered then
                                            chip "border border-goldhi/60 text-goldhi" (String.fromInt (Giveaway.total entries) ++ "/" ++ String.fromInt Giveaway.maxEntries ++ " entries")

                                        else
                                            chip "bg-go text-white uppercase tracking-wider" "Enter"

                                    Nothing ->
                                        chip "bg-go text-white uppercase tracking-wider" "Enter"
                                )

                chip cls text =
                    Html.span [ Attr.class ("flex-none rounded-lg px-3 py-1.5 text-xs font-bold whitespace-nowrap " ++ cls), Ui.testId "giveaway-banner-cta" ] [ Html.text text ]
            in
            Html.a
                [ Attr.href (Route.toString Route.GiveawayPage)
                , Attr.class "flex items-center gap-3 px-4 md:px-7 py-2.5 border-b border-[#4a3470] bg-gradient-to-r from-[#24163a] via-[#170f26] to-bar no-underline text-ink hover:text-ink"
                , Ui.testId "giveaway-banner"
                ]
                [ Html.div [ Attr.class "hidden sm:flex -space-x-2 flex-none" ]
                    (giveaway.prizes |> List.filterMap (prizeIcon "w-9 h-9 bg-card"))
                , Html.div [ Attr.class "flex-1 min-w-0" ]
                    [ Html.div [ Attr.class "font-bold text-[11px] tracking-[0.14em] text-[#d7b8f5] tabular-nums", Ui.testId "giveaway-banner-status" ] [ Html.text status ]
                    , Html.div [ Attr.class "font-semibold text-sm truncate" ]
                        [ Html.text (giveaway.title ++ ": " ++ (giveaway.prizes |> List.map prizeName |> String.join ", ")) ]
                    ]
                , cta
                ]

        ( _, Nothing ) ->
            Ui.empty


prizeIcon : String -> ItemLine -> Maybe (Html msg)
prizeIcon size line =
    Item.byId line.itemId |> Maybe.map (\item -> Ui.itemIcon size item line.variant)


prizeName : ItemLine -> String
prizeName line =
    (if line.quantity > 1 then
        String.fromInt line.quantity ++ " × "

     else
        ""
    )
        ++ (Item.byId line.itemId |> Maybe.map (\item -> Item.fullName item line.variant) |> Maybe.withDefault line.itemId)


view : FrontendModel -> Html FrontendMsg
view model =
    let
        giveaways =
            Dict.values model.giveaways

        past =
            giveaways
                |> List.filter (\g -> g.winner /= Nothing && Just g /= Giveaway.current model.now giveaways)
                |> List.sortBy (.endsAt >> Time.posixToMillis >> negate)
    in
    Html.div [ Attr.class "w-full max-w-3xl mx-auto px-4 py-6 flex flex-col gap-4" ]
        ((case Giveaway.current model.now giveaways of
            Just giveaway ->
                [ hero model giveaway
                , prizesCard giveaway
                , entriesCard model giveaway
                , rules
                ]

            Nothing ->
                [ Ui.pageMessage [ Ui.testId "no-giveaway" ]
                    [ Html.h1 [ Attr.class "font-display text-3xl text-ink mb-3" ] [ Html.text "No giveaway right now" ]
                    , Html.p [] [ Html.text "Check back soon. When there's one on, it shows at the top of every page." ]
                    ]
                ]
         )
            ++ (if List.isEmpty past then
                    []

                else
                    [ Ui.card [ Attr.class "p-4 flex flex-col gap-2", Ui.testId "past-giveaways" ]
                        (Ui.sectionLabel "Past winners"
                            :: List.map
                                (\g ->
                                    Html.div [ Attr.class "flex items-baseline gap-2 text-sm flex-wrap" ]
                                        [ Html.span [ Attr.class "font-semibold text-ink" ] [ Html.text g.title ]
                                        , Html.span [ Attr.class "text-muted" ] [ Html.text "won by" ]
                                        , winnerLink (Maybe.withDefault "" g.winner)
                                        , Html.span [ Attr.class "text-faint text-xs" ] [ Html.text (Ui.timeAgo model.now g.endsAt) ]
                                        ]
                                )
                                past
                        )
                    ]
               )
        )


winnerLink : String -> Html msg
winnerLink name =
    Html.a [ Attr.href (Route.toString (Route.Profile name)), Attr.class "font-semibold" ] [ Html.text name ]


hero : FrontendModel -> Giveaway -> Html msg
hero model giveaway =
    Html.div [ Attr.class "rounded-2xl border border-[#4a3470] bg-gradient-to-br from-[#24163a] to-card p-5 md:p-7 flex flex-col gap-4", Ui.testId "giveaway-hero" ]
        [ Html.div []
            [ Html.div [ Attr.class "font-bold text-[11px] tracking-[0.16em] text-[#d7b8f5] mb-2" ] [ Html.text "TRAILPOST GIVEAWAY" ]
            , Html.h1 [ Attr.class "font-display font-extrabold text-[34px] md:text-[44px] leading-tight" ] [ Html.text giveaway.title ]
            ]
        , Html.div [ Attr.class "flex items-end gap-6 flex-wrap" ]
            [ case giveaway.winner of
                Just winner ->
                    Html.div [ Ui.testId "giveaway-winner" ]
                        [ Html.div [ Attr.class "text-xs text-muted uppercase tracking-wider" ] [ Html.text "Winner" ]
                        , Html.div [ Attr.class "font-display font-extrabold text-3xl text-goldhi" ] [ winnerLink winner ]
                        ]

                Nothing ->
                    if Giveaway.hasEnded model.now giveaway then
                        Html.div [ Ui.testId "giveaway-countdown" ]
                            [ Html.div [ Attr.class "text-xs text-muted uppercase tracking-wider" ] [ Html.text "Ended" ]
                            , Html.div [ Attr.class "font-display font-extrabold text-3xl text-goldhi" ] [ Html.text "Drawing soon" ]
                            ]

                    else
                        Html.div [ Ui.testId "giveaway-countdown" ]
                            [ Html.div [ Attr.class "text-xs text-muted uppercase tracking-wider" ] [ Html.text "Ends in" ]
                            , Html.div [ Attr.class "font-display font-extrabold text-[40px] leading-none text-goldhi tabular-nums" ] [ Html.text (Giveaway.timeLeft model.now giveaway.endsAt) ]
                            ]
            , Html.div [ Ui.testId "giveaway-entrants" ]
                [ Html.div [ Attr.class "text-xs text-muted uppercase tracking-wider" ] [ Html.text "Entered" ]
                , Html.div [ Attr.class "font-bold text-2xl text-ink" ] [ Html.text (Ui.plural (List.length giveaway.entrants) "trader" "traders") ]
                ]
            ]
        ]


prizesCard : Giveaway -> Html msg
prizesCard giveaway =
    Ui.card [ Attr.class "p-4 flex flex-col gap-3", Ui.testId "giveaway-prizes" ]
        [ Ui.sectionLabel
            (if List.length giveaway.prizes > 1 then
                "Prizes · one winner gets all of them"

             else
                "Prize"
            )
        , Html.div [ Attr.class "grid sm:grid-cols-2 gap-2" ]
            (giveaway.prizes
                |> List.map
                    (\line ->
                        let
                            variant =
                                line.variant
                        in
                        Html.div [ Attr.class "flex items-center gap-3 rounded-xl bg-raised border border-edge p-2.5" ]
                            [ prizeIcon "w-12 h-12" line |> Maybe.withDefault Ui.empty
                            , case Item.byId line.itemId of
                                Just item ->
                                    -- The grade tag says the quality, so the name leaves it out.
                                    Html.div [ Attr.class "min-w-0" ]
                                        [ Html.div [ Attr.class "font-bold" ] [ Html.text (prizeName { line | variant = { variant | quality = Nothing } }) ]
                                        , Ui.gradeTag item line.variant
                                        ]

                                Nothing ->
                                    Html.div [ Attr.class "font-bold" ] [ Html.text line.itemId ]
                            ]
                    )
            )
        ]


entriesCard : FrontendModel -> Giveaway -> Html FrontendMsg
entriesCard model giveaway =
    let
        ended =
            Giveaway.hasEnded model.now giveaway

        entries =
            myEntries model giveaway |> Maybe.withDefault { entered = False, listed = False, offered = False, traded = False }

        banned =
            (model.me |> Maybe.andThen .ban) /= Nothing

        isWinner =
            giveaway.winner /= Nothing && giveaway.winner == Derived.myName model

        top =
            if isWinner then
                [ Ui.callout Ui.Good
                    [ Attr.class "p-4 text-sm leading-relaxed", Ui.testId "giveaway-you-won" ]
                    [ Html.b [ Attr.class "text-leaf" ] [ Html.text "You won! " ]
                    , Html.text "An admin will invite you to trade in WalkScape and put the prizes in. You don't put anything in, so just press Accept once the prizes are there."
                    ]
                ]

            else if model.me == Nothing then
                [ Html.a [ Attr.href (Route.toString Route.SignIn), Attr.id "giveaway-signin", Ui.buttonStyle Ui.Primary Ui.Block ]
                    [ Html.text
                        (if ended then
                            "Sign in"

                         else
                            "Sign in to enter"
                        )
                    ]
                ]

            else if not (Derived.isReady model) then
                [ Ui.nameGate (Derived.onboardingRoute model) "Entries go to your WalkScape name, so the winner can be invited to trade." ]

            else if entries.entered then
                [ Html.div [ Attr.class "flex items-baseline gap-2", Ui.testId "giveaway-entries" ]
                    [ Html.span [ Attr.class "font-display font-extrabold text-4xl text-goldhi" ] [ Html.text (String.fromInt (Giveaway.total entries)) ]
                    , Html.span [ Attr.class "text-soft font-semibold" ]
                        [ Html.text
                            ("of "
                                ++ String.fromInt Giveaway.maxEntries
                                ++ " entries"
                                ++ (if ended then
                                        ""

                                    else
                                        ". You're in."
                                   )
                            )
                        ]
                    ]
                ]

            else if ended then
                [ Html.p [ Attr.class "text-muted text-sm", Ui.testId "giveaway-missed" ] [ Html.text "You didn't enter this one." ] ]

            else if banned then
                [ Html.p [ Attr.class "text-warn text-sm" ] [ Html.text "Banned accounts can't enter." ] ]

            else
                [ Ui.button Ui.Primary Ui.Block "giveaway-enter" (GiveawayEnterClicked giveaway.id) "Enter the giveaway"
                , Html.p [ Attr.class "text-sm text-muted", Ui.testId "giveaway-would-have" ]
                    [ Html.text
                        ("You'd start with "
                            ++ Ui.plural (Giveaway.total { entries | entered = True }) "entry" "entries"
                            ++ "."
                        )
                    ]
                ]

        row id done title hint =
            Html.div [ Attr.class "flex items-start gap-3 py-2 border-t border-line", Ui.testId ("giveaway-entry-" ++ id) ]
                [ Html.span
                    [ Attr.class
                        ("flex-none w-6 h-6 rounded-full grid place-items-center text-xs font-bold "
                            ++ (if done then
                                    "bg-leaf text-shell"

                                else
                                    "border border-rule text-faint"
                               )
                        )
                    ]
                    [ Html.text
                        (if done then
                            "✓"

                         else
                            "+1"
                        )
                    ]
                , Html.div [ Attr.class "flex-1 min-w-0" ]
                    [ Html.div
                        [ Attr.class
                            (if done then
                                "font-semibold text-ink"

                             else
                                "font-semibold text-soft"
                            )
                        ]
                        [ Html.text title ]
                    , if done then
                        Ui.empty

                      else
                        Html.div [ Attr.class "text-[13px] text-muted" ] hint
                    ]
                ]
    in
    Ui.card [ Attr.class "p-4 flex flex-col gap-3" ]
        (Ui.sectionLabel "Your entries"
            :: top
            ++ [ Html.div [ Attr.class "flex flex-col" ]
                    [ row "entered" entries.entered "Enter the giveaway" [ Html.text "Opting in is your first entry." ]
                    , row "listed"
                        entries.listed
                        "Post a listing"
                        [ Html.text "Anything you'd sell or buy. "
                        , Html.a [ Attr.href (Route.toString (Route.NewListing Nothing)) ] [ Html.text "Post one" ]
                        ]
                    , row "offered"
                        entries.offered
                        "Make an offer on someone's listing"
                        [ Html.text "At their price or your own. "
                        , Html.a [ Attr.href (Route.toString Route.Market) ] [ Html.text "Browse the market" ]
                        ]
                    , row "traded" entries.traded "Complete a trade" [ Html.text "Once an offer's accepted and you both confirm the trade went through." ]
                    ]
               , Html.p [ Attr.class "text-xs text-faint" ] [ Html.text "Each counts once. Things you did since the giveaway started count, even from before you entered." ]
               ]
        )


rules : Html msg
rules =
    Ui.card [ Attr.class "p-4 flex flex-col gap-2 text-sm text-body leading-relaxed", Ui.testId "giveaway-rules" ]
        [ Ui.sectionLabel "How it works"
        , Html.p [] [ Html.text "When the giveaway ends, an admin draws one winner at random. Each entry is a ticket in the draw, so 4 entries give you 4 times the chance of 1." ]
        , Html.p [] [ Html.text "The winner gets every prize. An admin invites them to trade in WalkScape and puts the prizes in. You never have to put anything in to claim a prize, so if someone asks you to, it's a scam." ]
        , Html.p [ Attr.class "text-faint" ] [ Html.text "Trailpost is a fan project. The WalkScape team doesn't run this giveaway." ]
        ]
