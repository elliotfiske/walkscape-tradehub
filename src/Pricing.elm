module Pricing exposing
    ( Estimate
    , Point
    , Source(..)
    , Status(..)
    , classify
    , deviationPercent
    , estimate
    , isWarning
    , warnPercent
    )

{-| Preview price estimates.

Trading isn't live yet, so there are no confirmed trades to take a median of.
Instead each estimate comes from the coin prices people post: asking prices on
sell listings, bids on buy listings, and offers made on listings.

The rules follow the design's "How this price is made" panel:

  - **Median, not average.** One silly price can't drag the number around.
  - **One vote per trader per day.** Re-posting the same item doesn't count twice;
    a trader's latest price that day is the one that counts.
  - **Outliers cut.** Prices more than 2.5x the typical spread away from the
    median are shown but left out.

-}

import Set
import Time


type Source
    = Ask
    | Bid
    | Offer


type alias Point =
    { price : Int
    , trader : String
    , at : Time.Posix
    , source : Source
    }


type Status
    = Counted
    | Outlier
    | Repeat


type alias Estimate =
    { median : Int
    , low : Int
    , high : Int
    , counted : Int
    , excluded : Int
    , traders : Int
    }


{-| Listings and offers more than this far from the estimate get a warning.
-}
warnPercent : Int
warnPercent =
    25


outlierFactor : Float
outlierFactor =
    2.5


dayOf : Time.Posix -> Int
dayOf t =
    Time.posixToMillis t // 86400000


{-| Tag every point with whether it counts toward the estimate.
The result keeps the input order.
-}
classify : List Point -> List ( Point, Status )
classify points =
    let
        indexed =
            List.indexedMap Tuple.pair points

        -- The latest point per (trader, day) is the one that counts.
        isLatestForTraderDay ( i, p ) =
            indexed
                |> List.any
                    (\( j, q ) ->
                        (j /= i)
                            && (q.trader == p.trader)
                            && (dayOf q.at == dayOf p.at)
                            && (Time.posixToMillis q.at > Time.posixToMillis p.at || (Time.posixToMillis q.at == Time.posixToMillis p.at && j > i))
                    )
                |> not

        votes =
            indexed |> List.filter isLatestForTraderDay |> List.map (Tuple.second >> .price >> toFloat)

        isOutlier =
            case outlierBounds votes of
                Just ( lo, hi ) ->
                    \price -> toFloat price < lo || toFloat price > hi

                Nothing ->
                    always False
    in
    indexed
        |> List.map
            (\( i, p ) ->
                if not (isLatestForTraderDay ( i, p )) then
                    ( p, Repeat )

                else if isOutlier p.price then
                    ( p, Outlier )

                else
                    ( p, Counted )
            )


outlierBounds : List Float -> Maybe ( Float, Float )
outlierBounds votes =
    let
        sorted =
            List.sort votes
    in
    Maybe.map3
        (\m q1 q3 ->
            let
                -- With very few or identical prices the spread can be zero;
                -- fall back to 10% of the median so normal haggling still counts.
                spread =
                    max (q3 - q1) (m * 0.1)
            in
            ( m - outlierFactor * spread, m + outlierFactor * spread )
        )
        (quantile 0.5 sorted)
        (quantile 0.25 sorted)
        (quantile 0.75 sorted)


estimate : List Point -> Maybe Estimate
estimate points =
    let
        classified =
            classify points

        countedPoints =
            classified |> List.filter (\( _, s ) -> s == Counted) |> List.map Tuple.first

        sorted =
            countedPoints |> List.map (.price >> toFloat) |> List.sort

        traders =
            countedPoints |> List.map .trader |> Set.fromList |> Set.size
    in
    Maybe.map3
        (\m q1 q3 ->
            { median = round m
            , low = round q1
            , high = round q3
            , counted = List.length countedPoints
            , excluded = List.length points - List.length countedPoints
            , traders = traders
            }
        )
        (quantile 0.5 sorted)
        (quantile 0.25 sorted)
        (quantile 0.75 sorted)


{-| Linearly interpolated quantile of an already-sorted list.
-}
quantile : Float -> List Float -> Maybe Float
quantile q sorted =
    let
        n =
            List.length sorted

        pos =
            q * toFloat (n - 1)

        lowerIndex =
            floor pos

        frac =
            pos - toFloat lowerIndex

        at i =
            sorted |> List.drop i |> List.head
    in
    case ( at lowerIndex, at (lowerIndex + 1) ) of
        ( Just a, Just b ) ->
            Just (a + (b - a) * frac)

        ( Just a, Nothing ) ->
            Just a

        _ ->
            Nothing


{-| How far `price` is from `median`, as a whole percentage (rounded).
-}
deviationPercent : Int -> Int -> Int
deviationPercent median price =
    if median <= 0 then
        0

    else
        round ((toFloat price / toFloat median - 1) * 100)


isWarning : Int -> Bool
isWarning pct =
    abs pct > warnPercent
