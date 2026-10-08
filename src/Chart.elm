module Chart exposing (scatter, sparkline)

import Html exposing (Html)
import Html.Attributes as Attr
import Pricing
import Svg
import Svg.Attributes as SA
import Time
import Ui


fmt : Float -> String
fmt =
    String.fromFloat


sparkline : List Pricing.Point -> Html msg
sparkline points =
    let
        prices =
            List.map (.price >> toFloat) points

        lo =
            List.minimum prices |> Maybe.withDefault 0

        hi =
            List.maximum prices |> Maybe.withDefault 1

        span =
            if hi - lo < 1 then
                1

            else
                hi - lo

        n =
            List.length prices

        coords =
            prices
                |> List.indexedMap
                    (\i p ->
                        ( if n <= 1 then
                            230

                          else
                            toFloat i / toFloat (n - 1) * 460
                        , 52 - (p - lo) / span * 44
                        )
                    )

        line =
            coords |> List.map (\( x, y ) -> fmt x ++ "," ++ fmt y) |> String.join " "

        area =
            "0,60 " ++ line ++ " 460,60"
    in
    Svg.svg [ SA.viewBox "0 0 460 60", SA.preserveAspectRatio "none", SA.class "w-full h-[60px] block" ]
        (if n <= 1 then
            [ Svg.line [ SA.x1 "0", SA.x2 "460", SA.y1 "30", SA.y2 "30", SA.stroke "#e3b54c", SA.strokeWidth "2" ] [] ]

         else
            [ Svg.polygon [ SA.points area, SA.fill "rgba(227,181,76,0.10)" ] []
            , Svg.polyline [ SA.points line, SA.fill "none", SA.stroke "#e3b54c", SA.strokeWidth "2" ] []
            ]
        )


{-| The last 30 days of prices around the estimate and its typical range.
It's positioned HTML rather than a stretched SVG so the marks stay round at any
width. The time axis fits the data (minutes, hours or days), so an item whose
few prices are all from today isn't squeezed against "now". Outliers sit in a
lane above or below the scale instead of stretching it. Each mark shows its
details on hover, or on tap (focus).
-}
scatter : Time.Posix -> List ( Pricing.Point, Pricing.Status ) -> Maybe Pricing.Estimate -> Html msg
scatter now classified estimate =
    let
        ageMinutes p =
            toFloat (Time.posixToMillis now - Time.posixToMillis p.at) / 60000

        recent =
            List.filter (\( p, _ ) -> ageMinutes p <= 30 * 1440) classified
    in
    if List.isEmpty recent then
        Html.p [ Attr.class "text-sm text-muted", Ui.testId "price-chart" ] [ Html.text "No prices in the last 30 days." ]

    else
        scatterOf now ageMinutes recent estimate


scatterOf : Time.Posix -> (Pricing.Point -> Float) -> List ( Pricing.Point, Pricing.Status ) -> Maybe Pricing.Estimate -> Html msg
scatterOf now ageMinutes recent estimate =
    let
        windowMinutes =
            recent
                |> List.map (Tuple.first >> ageMinutes)
                |> List.maximum
                |> Maybe.withDefault 0
                |> (\oldest -> oldest * 1.1 + 5)
                |> clamp 30 (30 * 1440)

        onScale =
            (recent |> List.filter (\( _, s ) -> s /= Pricing.Outlier) |> List.map (Tuple.first >> .price >> toFloat))
                ++ (estimate |> Maybe.map (\e -> [ toFloat e.low, toFloat e.high ]) |> Maybe.withDefault [])

        rawLo =
            List.minimum onScale |> Maybe.withDefault 0

        rawHi =
            List.maximum onScale |> Maybe.withDefault 1

        pad =
            max ((rawHi - rawLo) * 0.12) (max 1 (rawHi * 0.05))

        lo =
            max 0 (rawLo - pad)

        hi =
            rawHi + pad

        hasAbove =
            List.any (\( p, _ ) -> toFloat p.price > hi) recent

        hasBelow =
            List.any (\( p, _ ) -> toFloat p.price < lo) recent

        height =
            220

        lane =
            20

        plotTop =
            if hasAbove then
                lane + 6

            else
                8

        plotBottom =
            if hasBelow then
                height - lane - 6

            else
                height - 8

        y v =
            if v > hi then
                lane / 2

            else if v < lo then
                height - lane / 2

            else
                plotTop + (1 - (v - lo) / (hi - lo)) * (plotBottom - plotTop)

        x minutes =
            clamp 0 100 ((1 - minutes / windowMinutes) * 100)

        px v =
            String.fromFloat v ++ "px"

        pct v =
            String.fromFloat v ++ "%"

        hline extra top =
            Html.div [ Attr.class ("absolute left-0 right-0 " ++ extra), Attr.style "top" (px top) ] []

        sideLabel top text =
            Html.span [ Attr.class "absolute right-full mr-2 -translate-y-1/2 text-[11px] text-faint whitespace-nowrap", Attr.style "top" (px top) ] [ Html.text text ]

        grid =
            yTicks lo hi
                |> List.concatMap
                    (\t ->
                        [ hline "border-t border-line" (y t)
                        , sideLabel (y t) (Ui.formatInt (round t))
                        ]
                    )

        lanes =
            (if hasAbove then
                [ hline "border-t border-dashed border-rule" (lane / 2), sideLabel (lane / 2) "higher" ]

             else
                []
            )
                ++ (if hasBelow then
                        [ hline "border-t border-dashed border-rule" (height - lane / 2), sideLabel (height - lane / 2) "lower" ]

                    else
                        []
                   )

        estimateMarks =
            case estimate of
                Just e ->
                    [ Html.div
                        [ Attr.class "absolute left-0 right-0 bg-gold/10"
                        , Attr.style "top" (px (y (toFloat e.high)))
                        , Attr.style "height" (px (max 3 (y (toFloat e.low) - y (toFloat e.high))))
                        ]
                        []
                    , hline "border-t-[1.5px] border-dashed border-gold/80" (y (toFloat e.median))
                    , Html.span
                        [ Attr.class "absolute left-full ml-3 -translate-y-1/2 rounded-full border border-gold/50 bg-[#2b2512] px-2 py-0.5 text-xs font-semibold text-gold whitespace-nowrap"
                        , Attr.style "top" (px (y (toFloat e.median)))
                        ]
                        [ Html.text ("est " ++ Ui.formatInt e.median) ]
                    ]

                Nothing ->
                    []

        -- At most five ticks, a round number of minutes, hours or days apart.
        tickStep =
            [ 5, 10, 15, 30, 60, 120, 180, 360, 720, 1440, 2880, 4320, 10080 ]
                |> List.filter (\m -> windowMinutes / toFloat m <= 4)
                |> List.head
                |> Maybe.withDefault 10080

        tick minutes =
            Html.span [ Attr.class "absolute -translate-x-1/2 whitespace-nowrap", Attr.style "left" (pct (x (toFloat minutes))) ]
                [ Html.text
                    (if minutes == 0 then
                        "now"

                     else if tickStep < 60 then
                        String.fromInt minutes ++ "m ago"

                     else if tickStep < 1440 then
                        String.fromInt (minutes // 60) ++ "h ago"

                     else
                        String.fromInt (minutes // 1440) ++ "d ago"
                    )
                ]

        mark ( p, status ) =
            let
                left =
                    x (ageMinutes p)
            in
            Html.div
                [ Attr.class "group absolute w-6 h-6 -translate-x-1/2 -translate-y-1/2 flex items-center justify-center rounded-full outline-none focus-visible:ring-1 focus-visible:ring-muted hover:z-10 focus:z-10"
                , Attr.style "left" (pct left)
                , Attr.style "top" (px (y (toFloat p.price)))
                , Attr.tabindex 0
                ]
                [ shape p.source (status == Pricing.Counted)
                , tooltip now
                    (if left > 50 then
                        "right-full mr-1"

                     else
                        "left-full ml-1"
                    )
                    ( p, status )
                ]

        -- Left-out marks first, so counted ones sit on top.
        marks =
            List.filter (\( _, s ) -> s /= Pricing.Counted) recent ++ List.filter (\( _, s ) -> s == Pricing.Counted) recent
    in
    Html.div [ Attr.class "flex flex-col gap-3", Ui.testId "price-chart" ]
        [ Html.div [ Attr.class "flex flex-wrap items-center gap-x-4 gap-y-1 text-[13px] text-muted" ]
            (Html.b [ Attr.class "text-ink" ] [ Html.text "Prices posted" ] :: legend recent)
        , Html.div [ Attr.class "pl-11 pr-[84px]" ]
            [ Html.div [ Attr.class "relative", Attr.style "height" (px height) ]
                (grid ++ lanes ++ estimateMarks ++ List.map mark marks)
            , Html.div [ Attr.class "relative h-4 mt-1.5 text-[11px] text-faint" ]
                (List.range 0 (floor windowMinutes // tickStep) |> List.map ((*) tickStep >> tick))
            ]
        ]


{-| Seller's prices are teal circles, buyer's blue squares and trades gold
diamonds. Hollow means the estimate left it out.
-}
shape : Pricing.Source -> Bool -> Html msg
shape source counted =
    let
        ( form, fill, outline ) =
            case source of
                Pricing.Ask ->
                    ( "rounded-full", "bg-ask", "border-ask" )

                Pricing.OfferToSell ->
                    ( "rounded-full", "bg-ask", "border-ask" )

                Pricing.Bid ->
                    ( "rounded-[2px]", "bg-bid", "border-bid" )

                Pricing.OfferToBuy ->
                    ( "rounded-[2px]", "bg-bid", "border-bid" )

                Pricing.Trade ->
                    ( "rotate-45 rounded-[1px]", "bg-gold", "border-gold" )
    in
    Html.span
        [ Attr.class
            ("block flex-none "
                ++ form
                ++ (if counted then
                        " w-3.5 h-3.5 border-2 border-card " ++ fill

                    else
                        " w-2.5 h-2.5 border-[1.5px] opacity-80 " ++ outline
                   )
            )
        ]
        []


tooltip : Time.Posix -> String -> ( Pricing.Point, Pricing.Status ) -> Html msg
tooltip now placement ( p, status ) =
    let
        ( statusClass, statusText ) =
            case status of
                Pricing.Counted ->
                    ( "text-leaf", "counted" )

                Pricing.Outlier ->
                    ( "text-warn", "outlier, left out" )

                Pricing.Repeat ->
                    ( "text-muted", "same trader, same day, left out" )

                Pricing.NotUsed ->
                    ( "text-muted", "not used" )
    in
    Html.div
        [ Attr.class ("absolute top-1/2 -translate-y-1/2 hidden group-hover:block group-focus:block z-20 pointer-events-none max-w-[220px] rounded-lg border border-rule bg-tab px-2.5 py-1.5 text-xs text-body shadow-lg whitespace-nowrap " ++ placement) ]
        [ Html.div [] [ Html.b [ Attr.class "text-ink text-[13px]" ] [ Html.text (Ui.formatInt p.price) ], Html.text (" · " ++ Pricing.sourceLabel p.source) ]
        , Html.div [ Attr.class "truncate" ] [ Html.text p.trader ]
        , Html.div [] [ Html.text (Ui.timeAgo now p.at ++ " · "), Html.span [ Attr.class statusClass ] [ Html.text statusText ] ]
        ]


legend : List ( Pricing.Point, Pricing.Status ) -> List (Html msg)
legend recent =
    let
        has sources =
            List.any (\( p, _ ) -> List.member p.source sources) recent

        item source label =
            Html.span [ Attr.class "flex items-center gap-1.5" ] [ shape source True, Html.text label ]
    in
    List.filterMap identity
        [ if has [ Pricing.Ask, Pricing.OfferToSell ] then
            Just (item Pricing.Ask "selling")

          else
            Nothing
        , if has [ Pricing.Bid, Pricing.OfferToBuy ] then
            Just (item Pricing.Bid "buying")

          else
            Nothing
        , if has [ Pricing.Trade ] then
            Just (item Pricing.Trade "traded")

          else
            Nothing
        , if List.any (\( _, s ) -> s /= Pricing.Counted) recent then
            Just
                (Html.span [ Attr.class "flex items-center gap-1.5" ]
                    [ Html.span [ Attr.class "block w-2.5 h-2.5 rounded-full border-[1.5px] border-muted" ] [], Html.text "hollow = left out" ]
                )

          else
            Nothing
        ]


{-| About four round-numbered price ticks between `lo` and `hi`.
-}
yTicks : Float -> Float -> List Float
yTicks lo hi =
    let
        raw =
            (hi - lo) / 4

        magnitude =
            10 ^ toFloat (floor (logBase 10 raw))

        step =
            [ 1, 2, 5, 10 ]
                |> List.map ((*) magnitude)
                |> List.filter (\s -> s >= raw)
                |> List.head
                |> Maybe.withDefault (10 * magnitude)
                |> max 1

        first =
            toFloat (ceiling (lo / step)) * step
    in
    List.range 0 10
        |> List.map (\i -> first + toFloat i * step)
        |> List.filter (\t -> t <= hi)
