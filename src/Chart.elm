module Chart exposing (scatter, sparkline)

import Html exposing (Html)
import Html.Attributes as Attr
import Pricing
import Svg
import Svg.Attributes as SA
import Time


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
    Svg.svg [ SA.viewBox "0 0 460 60", SA.preserveAspectRatio "none", Attr.class "w-full h-[60px] block" ]
        (if n <= 1 then
            [ Svg.line [ SA.x1 "0", SA.x2 "460", SA.y1 "30", SA.y2 "30", SA.stroke "#e3b54c", SA.strokeWidth "2" ] [] ]

         else
            [ Svg.polygon [ SA.points area, SA.fill "rgba(227,181,76,0.10)" ] []
            , Svg.polyline [ SA.points line, SA.fill "none", SA.stroke "#e3b54c", SA.strokeWidth "2" ] []
            ]
        )


{-| Scatter of the last 30 days of prices with the median and typical range,
plus a strip of daily counts underneath.
-}
scatter : Time.Posix -> List ( Pricing.Point, Pricing.Status ) -> Maybe Pricing.Estimate -> Html msg
scatter now classified estimate =
    let
        dayMs =
            86400000

        end =
            toFloat (Time.posixToMillis now)

        start =
            end - 30 * dayMs

        recent =
            List.filter (\( p, _ ) -> toFloat (Time.posixToMillis p.at) >= start) classified

        prices =
            List.map (\( p, _ ) -> toFloat p.price) recent

        lo =
            (List.minimum prices |> Maybe.withDefault 0) * 0.85

        hi =
            (List.maximum prices |> Maybe.withDefault 1) * 1.15

        span =
            if hi - lo < 1 then
                1

            else
                hi - lo

        w =
            800

        h =
            200

        x t =
            (toFloat (Time.posixToMillis t) - start) / (end - start) * w

        y p =
            h - (p - lo) / span * h

        dot ( p, status ) =
            case status of
                Pricing.Counted ->
                    Svg.circle [ SA.cx (fmt (x p.at)), SA.cy (fmt (y (toFloat p.price))), SA.r "4.5", SA.fill "#e3b54c", SA.stroke "#0a1014", SA.strokeWidth "1.5" ] []

                Pricing.Outlier ->
                    Svg.circle [ SA.cx (fmt (x p.at)), SA.cy (fmt (y (toFloat p.price))), SA.r "4.5", SA.fill "none", SA.stroke "#e06a5f", SA.strokeWidth "1.5" ] []

                Pricing.Repeat ->
                    Svg.circle [ SA.cx (fmt (x p.at)), SA.cy (fmt (y (toFloat p.price))), SA.r "3.5", SA.fill "none", SA.stroke "#6d7d85", SA.strokeWidth "1.5" ] []

        bandAndMedian =
            case estimate of
                Just e ->
                    [ Svg.rect
                        [ SA.x "0"
                        , SA.width (fmt w)
                        , SA.y (fmt (y (toFloat e.high)))
                        , SA.height (fmt (max 2 (y (toFloat e.low) - y (toFloat e.high))))
                        , SA.fill "rgba(44,90,42,0.35)"
                        ]
                        []
                    , Svg.line [ SA.x1 "0", SA.x2 (fmt w), SA.y1 (fmt (y (toFloat e.median))), SA.y2 (fmt (y (toFloat e.median))), SA.stroke "#7fd05f", SA.strokeWidth "1.5" ] []
                    ]

                Nothing ->
                    []

        dayCounts =
            List.range 0 29
                |> List.map
                    (\d ->
                        recent
                            |> List.filter
                                (\( p, _ ) ->
                                    let
                                        t =
                                            toFloat (Time.posixToMillis p.at)
                                    in
                                    t >= start + toFloat d * dayMs && t < start + toFloat (d + 1) * dayMs
                                )
                            |> List.length
                    )

        maxCount =
            List.maximum dayCounts |> Maybe.withDefault 1 |> max 1

        bars =
            dayCounts
                |> List.indexedMap
                    (\i c ->
                        let
                            bh =
                                if c == 0 then
                                    0

                                else
                                    4 + toFloat c / toFloat maxCount * 30
                        in
                        Svg.rect [ SA.x (fmt (toFloat i * (w / 30) + 2)), SA.width (fmt (w / 30 - 4)), SA.y (fmt (34 - bh)), SA.height (fmt bh), SA.fill "#24414f" ] []
                    )
    in
    Html.div [ Attr.class "flex flex-col gap-2" ]
        [ Html.div [ Attr.class "flex justify-between text-[11px] text-faint" ]
            [ Html.span [] [ Html.text "30 days ago" ], Html.span [] [ Html.text "now" ] ]
        , Svg.svg [ SA.viewBox ("0 0 " ++ fmt w ++ " " ++ fmt h), SA.preserveAspectRatio "none", Attr.class "w-full h-[200px] block overflow-visible" ]
            (bandAndMedian ++ List.map dot recent)
        , Svg.svg [ SA.viewBox ("0 0 " ++ fmt w ++ " 34"), SA.preserveAspectRatio "none", Attr.class "w-full h-[34px] block border-t border-line pt-1" ] bars
        , Html.div [ Attr.class "text-xs text-faint" ] [ Html.text "Prices posted per day" ]
        ]
