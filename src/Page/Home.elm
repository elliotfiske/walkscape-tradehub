module Page.Home exposing (view)

import Chart
import Derived
import Html exposing (Html)
import Html.Attributes as Attr
import Item
import Market
import Pricing
import Route
import Types exposing (FrontendModel, FrontendMsg)
import Ui


{-| The price series with the most data, to feature on the homepage.
-}
featured : FrontendModel -> Maybe ( Item.Item, Item.Variant, List Pricing.Point )
featured model =
    Derived.activeSeries model
        |> List.map (\( item, q ) -> ( item, q, Market.pricePoints model.now model.listings model.offers (Item.priceKey item.id q) ))
        |> List.filter (\( _, _, points ) -> not (List.isEmpty points))
        |> List.sortBy (\( _, _, points ) -> negate (List.length points))
        |> List.head


view : FrontendModel -> Html FrontendMsg
view model =
    Html.div [ Attr.class "flex flex-col" ]
        [ Html.section [ Attr.class "grid md:grid-cols-[1.1fr_1fr] gap-8 md:gap-14 items-center px-4 md:px-[72px] py-10 md:py-20 border-b border-line" ]
            [ Html.div []
                [ Html.div [ Attr.class "font-bold text-[11px] tracking-[0.16em] text-gold mb-4" ] [ Html.text "A FAN-MADE MARKET FOR WALKSCAPE" ]
                , Html.h1 [ Attr.class "font-display font-extrabold text-[38px] md:text-[60px] leading-[1.02] tracking-tight mb-5" ]
                    [ Html.text "Know the fair price", Html.br [] [], Html.text "before trading opens." ]
                , Html.p [ Attr.class "text-body text-lg leading-relaxed max-w-lg mb-7" ]
                    [ Html.text "Post what you'd sell or buy, and make offers on other people's listings. Nothing changes hands yet, but every price goes into an estimate anyone can check." ]
                , Html.div [ Attr.class "flex flex-col sm:flex-row gap-3" ]
                    (if model.me == Nothing then
                        [ Html.a [ Attr.href "/signin", Attr.id "hero-signin", Attr.class "rounded-xl bg-go hover:bg-gohi text-white hover:text-white no-underline font-bold tracking-wider px-7 py-3.5 text-center border border-white/10" ] [ Html.text "SIGN IN TO POST" ]
                        , Html.a [ Attr.href "/market", Attr.id "hero-browse", Attr.class "rounded-xl bg-raised hover:bg-tab text-soft hover:text-ink no-underline font-semibold px-6 py-3.5 text-center border border-rule" ] [ Html.text "Browse the market" ]
                        ]

                     else
                        [ Html.a [ Attr.href "/market", Attr.id "hero-browse", Attr.class "rounded-xl bg-go hover:bg-gohi text-white hover:text-white no-underline font-bold tracking-wider px-7 py-3.5 text-center border border-white/10" ] [ Html.text "GO TO THE MARKET" ] ]
                    )
                , if model.me == Nothing then
                    Html.p [ Attr.class "text-faint text-sm mt-4" ] [ Html.text "Sign in with Discord. Trailpost only sees your username." ]

                  else
                    Ui.empty
                ]
            , featuredCard model
            ]
        , Html.section [ Attr.class "grid sm:grid-cols-2 lg:grid-cols-4 gap-7 px-4 md:px-[72px] py-10 border-b border-line" ]
            [ feature "Why post if nothing trades?" "Every listing and offer is a vote in an item's price. More votes means a better guess for everyone. Listings reset when trading launches, but your account and name stay."
            , feature "Better than asking around" "A reply in a trade channel is one person's guess. Estimates here are the median of everyone's prices, one vote per trader per day, with outliers cut."
            , feature "Safe to try" "Discord only shares your username with Trailpost, and nothing here touches your WalkScape account."
            , feature "No pressure tactics" "No countdowns anywhere. New listings wait 15 minutes before going live, so no deal appears and disappears before you can check it."
            ]
        , Html.section [ Attr.class "px-4 md:px-[72px] py-10 border-b border-line" ]
            [ Html.h2 [ Attr.class "font-display font-extrabold text-[28px] mb-6" ] [ Html.text "Getting started takes a minute" ]
            , Html.div [ Attr.class "grid md:grid-cols-3 gap-6" ]
                [ startStep 1 "Sign in" "With Discord."
                , startStep 2 "Claim your name" "Type the name you play under. Names are first-come for now. Once trading opens you'll verify yours, and if someone else grabbed it, it moves to you."
                , startStep 3 "Post and offer" "List what you'd sell or buy, and make offers on other people's listings."
                ]
            ]
        , Html.section [ Attr.class "px-4 md:px-[72px] py-10 border-b border-line", Ui.testId "about" ]
            [ Html.h2 [ Attr.class "font-display font-extrabold text-[28px] mb-4" ] [ Html.text "Who made this" ]
            , Html.div [ Attr.class "flex flex-col gap-3 text-body leading-relaxed max-w-2xl" ]
                [ Html.p [] [ Html.text "I'm Elliot, a WalkScape player. I built this so we'd have prices figured out before trading opens." ]
                , Html.p []
                    [ Html.text "It's a preview, so I'm still working out how it should work. If something's confusing or missing, tell me in the "
                    , Html.a [ Attr.href Ui.feedbackThreadUrl, Attr.target "_blank", Attr.rel "noopener" ] [ Html.text "Trailpost thread on the WalkScape Discord" ]
                    , Html.text "."
                    ]
                , Html.p []
                    [ Html.b [ Attr.class "text-ink" ] [ Html.text "Moderation: " ]
                    , Html.text "Nothing trades here yet, so there isn't much to moderate. The only problem I can think of is offensive names, and verification fixes that once trading opens. For real trades I'm weighing a few options: reviewing reports myself (slow, but I know the context), recruiting community volunteers as moderators (faster, but more people to trust), or no reports at all and just showing each trader's history (no ban hammer, but new players look sketchy). If you have opinions, the thread's the place."
                    ]
                ]
            ]
        , Html.footer [ Attr.class "px-4 md:px-[72px] py-6 text-faint text-[13px]" ]
            [ Html.text "Trailpost is a fan project and isn't affiliated with the WalkScape team." ]
        ]


feature : String -> String -> Html msg
feature title body =
    Html.div []
        [ Html.h3 [ Attr.class "font-display font-extrabold text-xl text-gold mb-2" ] [ Html.text title ]
        , Html.p [ Attr.class "text-body leading-relaxed" ] [ Html.text body ]
        ]


startStep : Int -> String -> String -> Html msg
startStep n title body =
    Html.div [ Attr.class "flex gap-4" ]
        [ Html.span [ Attr.class "flex-none w-7 h-7 rounded-full bg-raised border border-rule grid place-items-center text-[13px] font-bold text-gold" ] [ Html.text (String.fromInt n) ]
        , Html.div []
            [ Html.div [ Attr.class "font-semibold text-lg" ] [ Html.text title ]
            , Html.p [ Attr.class "text-body" ] [ Html.text body ]
            ]
        ]


featuredCard : FrontendModel -> Html FrontendMsg
featuredCard model =
    case featured model of
        Just ( item, quality, points ) ->
            let
                est =
                    Pricing.estimate points
            in
            Html.a
                [ Attr.href (Route.toString (Route.ItemPrice item.id quality))
                , Attr.class "block no-underline text-ink hover:text-ink"
                , Ui.testId "featured-price"
                ]
                [ Ui.card [ Attr.class "p-5 rounded-2xl" ]
                    [ Html.div [ Attr.class "flex items-center gap-3.5" ]
                        [ Ui.itemIcon "w-[52px] h-[52px]" item quality
                        , Html.div [ Attr.class "flex-1" ]
                            [ Html.div [ Attr.class "font-bold text-lg" ] [ Html.text item.name ]
                            , Ui.gradeTag item quality
                            ]
                        , case est of
                            Just e ->
                                Html.div [ Attr.class "text-right" ]
                                    [ Html.div [ Attr.class "flex items-center gap-2 justify-end" ]
                                        [ Ui.coin "w-5 h-5", Html.span [ Attr.class "font-bold text-2xl text-gold" ] [ Html.text (Ui.formatInt e.median) ] ]
                                    , Html.div [ Attr.class "text-xs text-muted" ] [ Html.text "preview estimate" ]
                                    ]

                            Nothing ->
                                Ui.empty
                        ]
                    , Html.div [ Attr.class "my-5" ] [ Chart.sparkline points ]
                    , Html.div [ Attr.class "text-[13px] text-muted" ]
                        [ Html.text
                            (case est of
                                Just e ->
                                    "Median of " ++ String.fromInt e.counted ++ " prices from " ++ String.fromInt e.traders ++ " traders · not confirmed trades"

                                Nothing ->
                                    ""
                            )
                        ]
                    ]
                ]

        Nothing ->
            case Item.byId "shovel_axe" of
                Just item ->
                    Ui.card [ Attr.class "p-5 rounded-2xl", Ui.testId "featured-price" ]
                        [ Html.div [ Attr.class "flex items-center gap-3.5" ]
                            [ Ui.itemIcon "w-[52px] h-[52px]" item Item.plain
                            , Html.div [ Attr.class "flex-1" ]
                                [ Html.div [ Attr.class "font-bold text-lg" ] [ Html.text item.name ]
                                , Ui.gradeTag item Item.plain
                                ]
                            ]
                        , Html.div [ Attr.class "my-5 h-[60px] rounded-lg border border-dashed border-rule grid place-items-center text-sm text-faint" ]
                            [ Html.text "No prices yet" ]
                        , Html.div [ Attr.class "text-[13px] text-muted" ]
                            [ Html.text
                                (if Derived.isReady model then
                                    "Be the first to post a listing and start the price history."

                                 else
                                    "Sign in and post a listing to start the price history."
                                )
                            ]
                        ]

                Nothing ->
                    Ui.empty
