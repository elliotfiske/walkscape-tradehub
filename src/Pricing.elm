module Pricing exposing
    ( Basis(..)
    , Estimate
    , Point
    , Source(..)
    , Status(..)
    , basisShort
    , basisText
    , countText
    , classify
    , deviationPercent
    , estimate
    , isWarning
    , minTrades
    , tradeWindowDays
    , warnPercent
    )

{-| Price estimates.

Trades happen in WalkScape, where Trailpost can't see them, but both traders
tell us when one went through (`OfferCompleted`). When a price series has at
least `minTrades` of those in the last `tradeWindowDays`, the estimate is the
median of those trades and nothing else (`FromTrades`).

Otherwise it comes from the coin prices people post (`FromPrices`): asking
prices on sell listings, bids on buy listings, and offers made on listings.
The rules follow the design's "How this price is made" panel:

  - **Median, not average.** One silly price can't drag the number around.
  - **One vote per trader per day.** Re-posting the same item doesn't count twice;
    a trader's latest price that day is the one that counts.
  - **Outliers cut.** Prices more than 2.5x the typical spread away from the
    median are shown but left out.

Each trade is a deal both sides confirmed, so trades get none of those cuts:
the estimate is simply their median.

-}

import Set
import Time


type Source
    = Ask
    | Bid
    | Offer
    | Trade


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
      -- Shown but not part of this estimate: asks, bids and offers when there
      -- are enough recent trades, and the trades when there aren't.
    | NotUsed


type Basis
    = FromTrades
    | FromPrices


type alias Estimate =
    { median : Int
    , low : Int
    , high : Int
    , counted : Int
    , excluded : Int
    , traders : Int
    , basis : Basis
    }


{-| How many trades in the last `tradeWindowDays` it takes for trades alone to
set the estimate.
-}
minTrades : Int
minTrades =
    3


tradeWindowDays : Int
tradeWindowDays =
    30


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


{-| Trades from the last `tradeWindowDays`, if there are enough of them to set
the estimate.
-}
recentTrades : Time.Posix -> List Point -> Maybe (List Point)
recentTrades now points =
    let
        recent =
            points
                |> List.filter
                    (\p ->
                        (p.source == Trade)
                            && (Time.posixToMillis now - Time.posixToMillis p.at <= tradeWindowDays * 86400000)
                    )
    in
    if List.length recent >= minTrades then
        Just recent

    else
        Nothing


{-| Tag every point with whether it counts toward the estimate.
The result keeps the input order.
-}
classify : Time.Posix -> List Point -> List ( Point, Status )
classify now points =
    case recentTrades now points of
        Just trades ->
            points
                |> List.map
                    (\p ->
                        if List.member p trades then
                            ( p, Counted )

                        else
                            ( p, NotUsed )
                    )

        Nothing ->
            let
                prices =
                    points |> List.filter (\p -> p.source /= Trade) |> classifyPrices
            in
            -- Put the trades back where they were, marked as not used.
            List.foldr
                (\p ( acc, rest ) ->
                    if p.source == Trade then
                        ( ( p, NotUsed ) :: acc, rest )

                    else
                        case rest of
                            classified :: others ->
                                ( classified :: acc, others )

                            [] ->
                                ( acc, [] )
                )
                ( [], List.reverse prices )
                points
                |> Tuple.first


{-| The asks/bids/offers rules: one vote per trader per day, outliers cut.
-}
classifyPrices : List Point -> List ( Point, Status )
classifyPrices points =
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


estimate : Time.Posix -> List Point -> Maybe Estimate
estimate now points =
    let
        classified =
            classify now points

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
            , basis =
                if recentTrades now points == Nothing then
                    FromPrices

                else
                    FromTrades
            }
        )
        (quantile 0.5 sorted)
        (quantile 0.25 sorted)
        (quantile 0.75 sorted)


{-| "from 5 trades" or "from asks and offers".
-}
basisText : Estimate -> String
basisText est =
    case est.basis of
        FromTrades ->
            "from " ++ String.fromInt est.counted ++ " trades"

        FromPrices ->
            "from asks and offers"


{-| "5 trades", or "12 prices · 4 traders" for an estimate from asks and offers.
-}
countText : Estimate -> String
countText est =
    let
        plural n one many =
            String.fromInt n
                ++ " "
                ++ (if n == 1 then
                        one

                    else
                        many
                   )
    in
    case est.basis of
        FromTrades ->
            plural est.counted "trade" "trades"

        FromPrices ->
            plural est.counted "price" "prices" ++ " · " ++ plural est.traders "trader" "traders"


{-| "5 trades" or "asks/offers", where there's little room.
-}
basisShort : Estimate -> String
basisShort est =
    case est.basis of
        FromTrades ->
            String.fromInt est.counted ++ " trades"

        FromPrices ->
            "asks/offers"


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
