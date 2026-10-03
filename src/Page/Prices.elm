module Page.Prices exposing (viewIndex, viewItem)

import Chart
import Derived
import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Item
import Market
import Pricing
import Route
import Time
import Types exposing (FrontendModel, FrontendMsg)
import Ui


itemUrl : String -> Item.Variant -> String
itemUrl id variant =
    Route.toString (Route.ItemPrice id variant)


viewIndex : FrontendModel -> Html FrontendMsg
viewIndex model =
    let
        withEstimates =
            Derived.activeSeries model
                |> List.filterMap (\( item, q ) -> Derived.estimateFor model (Item.priceKey item.id q) |> Maybe.map (\e -> ( item, q, e )))
                |> List.sortBy (\( _, _, e ) -> negate (e.counted + e.excluded))
    in
    Html.div [ Attr.class "w-full max-w-4xl mx-auto px-4 md:px-7 py-6 flex flex-col gap-5" ]
        [ Html.h1 [ Attr.class "font-display font-extrabold text-[30px]" ] [ Html.text "Prices" ]
        , Html.p [ Attr.class "text-body max-w-2xl" ]
            [ Html.text "Preview estimates from what traders ask, bid and offer here. There are no confirmed trades yet, so treat these as a rough guide to value." ]
        , Html.div [ Attr.class "hidden sm:grid grid-cols-[minmax(0,2fr)_1fr_1.2fr_1fr] gap-3 px-3.5 font-bold text-[11px] tracking-[0.12em] text-faint" ]
            [ Html.div [] [ Html.text "ITEM" ], Html.div [] [ Html.text "ESTIMATE" ], Html.div [] [ Html.text "TYPICAL RANGE" ], Html.div [ Attr.class "text-right" ] [ Html.text "PRICES" ] ]
        , Html.div [ Attr.class "flex flex-col gap-2", Ui.testId "price-index" ]
            (List.map
                (\( item, q, est ) ->
                    Html.a
                        [ Attr.href (itemUrl item.id q)
                        , Attr.class "grid grid-cols-[minmax(0,2fr)_1fr] sm:grid-cols-[minmax(0,2fr)_1fr_1.2fr_1fr] gap-3 items-center px-3.5 py-2.5 rounded-[10px] bg-card border border-[#22343d] hover:bg-raised no-underline text-ink hover:text-ink"
                        , Ui.testId ("price-row-" ++ Item.priceKey item.id q)
                        ]
                        [ Html.div [ Attr.class "flex items-center gap-3 min-w-0" ]
                            [ Ui.itemIcon "w-10 h-10" item q
                            , Html.div [ Attr.class "min-w-0" ] [ Html.div [ Attr.class "font-semibold truncate" ] [ Html.text item.name ], Ui.gradeTag item q ]
                            ]
                        , Ui.coinAmount est.median
                        , Html.div [ Attr.class "hidden sm:block text-sm text-soft" ] [ Html.text (Ui.formatInt est.low ++ "–" ++ Ui.formatInt est.high) ]
                        , Html.div [ Attr.class "hidden sm:block text-right text-[13px] text-muted" ] [ Html.text (Ui.plural est.counted "price" "prices" ++ " · " ++ Ui.plural est.traders "trader" "traders") ]
                        ]
                )
                withEstimates
            )
        , Html.p [ Attr.class "text-sm text-faint" ]
            [ Html.text ("Only items with live listings show up here. Trailpost knows " ++ String.fromInt (List.length Item.all) ++ " WalkScape items; search for one in ")
            , Html.a [ Attr.href "/new" ] [ Html.text "a new listing" ]
            , Html.text "."
            ]
        ]


viewItem : FrontendModel -> String -> Item.Variant -> Html FrontendMsg
viewItem model itemId requested =
    case Item.byId itemId of
        Nothing ->
            Html.div [ Attr.class "p-10 text-center text-muted" ] [ Html.text "We don't know that item." ]

        Just item ->
            let
                variant =
                    { fine = requested.fine && item.canBeFine
                    , quality =
                        case item.kind of
                            Item.Crafted ->
                                Just (Maybe.withDefault Item.Normal requested.quality)

                            _ ->
                                Nothing
                    }

                key =
                    Item.priceKey item.id variant

                points =
                    Market.pricePoints model.now model.listings model.offers key

                classified =
                    Pricing.classify points

                est =
                    Pricing.estimate points

                listingCount =
                    model.listings
                        |> Dict.values
                        |> List.filter (\l -> not l.closed && Market.isLive model.now l && Item.priceKey l.itemId l.variant == key)
                        |> List.length

                tile label value sub color =
                    Html.div [ Attr.class "rounded-xl bg-card border border-edge px-4 py-3" ]
                        [ Html.div [ Attr.class "text-[13px] text-muted" ] [ Html.text label ]
                        , Html.div [ Attr.class ("font-bold text-2xl " ++ color) ] [ Html.text value ]
                        , Html.div [ Attr.class "text-xs text-faint" ] [ Html.text sub ]
                        ]
            in
            Html.div [ Attr.class "flex-1 grid lg:grid-cols-[minmax(0,1fr)_330px] gap-6 px-4 md:px-7 py-6" ]
                [ Html.div [ Attr.class "flex flex-col gap-4 min-w-0" ]
                    [ Html.div [ Attr.class "flex flex-col sm:flex-row sm:items-center gap-4" ]
                        [ Html.div [ Attr.class "flex items-center gap-4 flex-1" ]
                            [ Ui.itemIcon "w-[68px] h-[68px] rounded-xl" item variant
                            , Html.div []
                                [ Html.h1 [ Attr.class "font-display font-extrabold text-[30px] leading-tight", Ui.testId "item-name" ] [ Html.text item.name ]
                                , Ui.gradeTag item variant
                                ]
                            ]
                        , Html.div [ Attr.class "flex gap-2.5" ]
                            [ Html.a [ Attr.href "/market", Attr.class "rounded-[10px] bg-raised border border-rule text-soft hover:text-ink no-underline font-semibold px-4 py-2.5 text-sm" ]
                                [ Html.text (Ui.plural listingCount "listing" "listings") ]
                            , Html.a [ Attr.href "/new", Attr.class "rounded-[10px] bg-go hover:bg-gohi text-white hover:text-white no-underline font-bold tracking-wider px-4 py-2.5 text-sm" ] [ Html.text "POST A LISTING" ]
                            ]
                        ]
                    , if item.canBeFine then
                        Html.div [ Attr.class "flex gap-1.5", Ui.testId "fine-switch" ]
                            [ variantLink "price-regular" (itemUrl item.id { variant | fine = False }) (not variant.fine) "Regular"
                            , variantLink "price-fine" (itemUrl item.id { variant | fine = True }) variant.fine "✦ Fine"
                            ]

                      else
                        Ui.empty
                    , case item.kind of
                        Item.Crafted ->
                            Html.div [ Attr.class "flex flex-wrap gap-1.5" ]
                                (Item.allQualities
                                    |> List.map
                                        (\q ->
                                            let
                                                active =
                                                    Just q == variant.quality
                                            in
                                            Html.a
                                                [ Attr.href (itemUrl item.id { variant | quality = Just q })
                                                , Attr.class "px-2.5 py-1 rounded-md text-[13px] no-underline"
                                                , Attr.style "border" ("1px solid " ++ Item.qualityColor q)
                                                , Attr.style "color"
                                                    (if active then
                                                        "#0a1014"

                                                     else
                                                        Item.qualityColor q
                                                    )
                                                , Attr.style "background"
                                                    (if active then
                                                        Item.qualityColor q

                                                     else
                                                        "transparent"
                                                    )
                                                ]
                                                [ Html.text (Item.qualityLabel q) ]
                                        )
                                )

                        _ ->
                            Ui.empty
                    , case est of
                        Just e ->
                            Html.div [ Attr.class "grid grid-cols-2 md:grid-cols-4 gap-2.5", Ui.testId "price-stats" ]
                                [ tile "Preview estimate" (Ui.formatInt e.median) "median of counted prices" "text-gold"
                                , tile "Typical range" (Ui.formatInt e.low ++ "–" ++ Ui.formatInt e.high) "middle 50% of prices" "text-ink"
                                , tile "Prices counted" (String.fromInt e.counted) ("from " ++ String.fromInt e.traders ++ " unique traders") "text-ink"
                                , tile "Excluded" (String.fromInt e.excluded) "outliers + same-day repeats" "text-warn"
                                ]

                        Nothing ->
                            Html.div [ Attr.class "rounded-xl border border-dashed border-rule p-8 text-center text-muted", Ui.testId "no-prices" ]
                                [ Html.text "No prices for this item yet. Post a listing or make an offer to start the estimate." ]
                    , if List.isEmpty points then
                        Ui.empty

                      else
                        Ui.card [ Attr.class "p-4 flex flex-col gap-3" ]
                            [ Html.div [ Attr.class "flex flex-wrap gap-4 text-[13px] text-muted" ]
                                [ Html.b [ Attr.class "text-ink" ] [ Html.text "30 days" ]
                                , legend "bg-gold" "counted price"
                                , legend "border border-[#e06a5f]" "outlier, excluded"
                                , legend "bg-leaf h-0.5 w-3 rounded-none" "estimate"
                                , legend "bg-[#2c5a2a] rounded-sm" "typical range"
                                ]
                            , Chart.scatter model.now classified est
                            ]
                    , if List.isEmpty classified then
                        Ui.empty

                      else
                        pointTable model classified est
                    ]
                , Html.aside [ Attr.class "flex flex-col gap-4" ]
                    [ Ui.card [ Attr.class "p-5 flex flex-col gap-3 text-sm text-body" ]
                        [ Html.h2 [ Attr.class "font-display font-extrabold text-xl text-gold" ] [ Html.text "How this estimate is made" ]
                        , method "Asking prices, bids and offers." "Trading isn't live, so there are no confirmed trades yet. Every coin price someone posts or offers here counts."
                        , method "Median, not average." "One huge price can't drag the number around."
                        , method "One vote per trader per day." "Re-posting the same item counts once. Your latest price that day is the one used."
                        , method "Outliers cut." "Prices more than 2.5× the typical spread from the median are shown but left out."
                        ]
                    , Ui.card [ Attr.class "p-5 flex flex-col gap-2" ]
                        [ Html.div [ Attr.class "font-bold text-[11px] tracking-[0.14em] text-muted" ] [ Html.text "DATA HEALTH" ]
                        , Html.p [ Attr.class "text-sm text-body" ]
                            [ Html.text
                                (case est of
                                    Just e ->
                                        String.fromInt e.traders
                                            ++ " unique traders. "
                                            ++ (if e.traders < 5 then
                                                    "That's not many yet, so this estimate can move a lot."

                                                else
                                                    "Enough people that no single trader sets this price."
                                               )

                                    Nothing ->
                                        "No data yet."
                                )
                            ]
                        , Html.div [ Attr.class "h-2 rounded-full bg-rule overflow-hidden" ]
                            [ Html.div
                                [ Attr.class "h-full bg-gold"
                                , Attr.style "width" (String.fromInt (min 100 ((est |> Maybe.map .traders |> Maybe.withDefault 0) * 10)) ++ "%")
                                ]
                                []
                            ]
                        ]
                    ]
                ]


legend : String -> String -> Html msg
legend swatch text =
    Html.span [ Attr.class "flex items-center gap-1.5" ]
        [ Html.span [ Attr.class ("inline-block w-2 h-2 rounded-full " ++ swatch) ] [], Html.text text ]


method : String -> String -> Html msg
method title body =
    Html.p [] [ Html.b [ Attr.class "text-ink" ] [ Html.text (title ++ " ") ], Html.text body ]


pointTable : FrontendModel -> List ( Pricing.Point, Pricing.Status ) -> Maybe Pricing.Estimate -> Html msg
pointTable model classified est =
    let
        sourceLabel s =
            case s of
                Pricing.Ask ->
                    "Asking"

                Pricing.Bid ->
                    "Buying at"

                Pricing.Offer ->
                    "Offer"

        statusCell ( p, s ) =
            case s of
                Pricing.Counted ->
                    Html.span [ Attr.class "text-leaf" ] [ Html.text "Counted" ]

                Pricing.Outlier ->
                    let
                        pct =
                            est |> Maybe.map (\e -> Pricing.deviationPercent e.median p.price) |> Maybe.withDefault 0
                    in
                    Html.span [ Attr.class "text-warn" ]
                        [ Html.text
                            ("Excluded: outlier"
                                ++ (if pct /= 0 then
                                        ", "
                                            ++ (if pct > 0 then
                                                    "+"

                                                else
                                                    "−"
                                               )
                                            ++ String.fromInt (abs pct)
                                            ++ "%"

                                    else
                                        ""
                                   )
                            )
                        ]

                Pricing.Repeat ->
                    Html.span [ Attr.class "text-gold" ] [ Html.text "Excluded: same trader, same day" ]
    in
    Html.div [ Attr.class "flex flex-col gap-1.5", Ui.testId "price-points" ]
        (Html.div [ Attr.class "grid grid-cols-[0.8fr_0.8fr_1.4fr_1.6fr] gap-3 px-3.5 font-bold text-[11px] tracking-[0.12em] text-faint" ]
            [ Html.div [] [ Html.text "WHEN" ], Html.div [] [ Html.text "PRICE" ], Html.div [] [ Html.text "TRADER" ], Html.div [] [ Html.text "STATUS" ] ]
            :: (classified
                    |> List.sortBy (\( p, _ ) -> negate (Time.posixToMillis p.at))
                    |> List.take 30
                    |> List.map
                        (\( p, s ) ->
                            Html.div [ Attr.class "grid grid-cols-[0.8fr_0.8fr_1.4fr_1.6fr] gap-3 items-center px-3.5 py-2.5 rounded-lg bg-card text-sm" ]
                                [ Html.div [ Attr.class "text-muted" ] [ Html.text (Ui.timeAgo model.now p.at) ]
                                , Html.div [ Attr.class "font-bold text-gold" ] [ Html.text (Ui.formatInt p.price) ]
                                , Html.div [ Attr.class "min-w-0 truncate" ]
                                    [ Html.a [ Attr.href ("/u/" ++ p.trader), Attr.class "text-ink hover:text-gold no-underline" ] [ Html.text p.trader ]
                                    , Html.span [ Attr.class "text-faint text-xs" ] [ Html.text (" · " ++ sourceLabel p.source) ]
                                    ]
                                , Html.div [ Attr.class "text-[13px]" ] [ statusCell ( p, s ) ]
                                ]
                        )
               )
        )


variantLink : String -> String -> Bool -> String -> Html msg
variantLink id href active label =
    Html.a
        [ Attr.id id
        , Attr.href href
        , Attr.class
            ("px-3 py-1 rounded-md text-[13px] font-semibold no-underline border "
                ++ (if active then
                        "bg-gold border-gold text-[#0a1014] hover:text-[#0a1014]"

                    else
                        "border-rule text-soft hover:text-ink"
                   )
            )
        ]
        [ Html.text label ]
