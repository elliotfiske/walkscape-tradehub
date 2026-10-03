module Derived exposing
    ( TraderStats
    , activeSeries
    , estimateFor
    , isReady
    , listingEstimate
    , marketListings
    , myName
    , offersFor
    , pendingResponses
    , traderStats
    )

{-| Values the frontend computes from the listings, offers and traders it holds.
-}

import Dict
import Item
import Market
import Pricing
import Time
import Types exposing (ClaimStatus(..), FrontendModel, Listing, MarketSort(..), MarketTab(..), Offer, OfferStatus(..), Payment(..), Side(..))


myName : FrontendModel -> Maybe String
myName model =
    model.me |> Maybe.andThen .claim |> Maybe.map .name


isReady : FrontendModel -> Bool
isReady model =
    case model.me |> Maybe.andThen .claim of
        Just claim ->
            claim.status == PreviewUnverified

        Nothing ->
            False


estimateFor : FrontendModel -> String -> Maybe Pricing.Estimate
estimateFor model key =
    Market.pricePoints model.now model.listings model.offers key |> Pricing.estimate


{-| Price series (item + quality) that have at least one live listing.
-}
activeSeries : FrontendModel -> List ( Item.Item, Maybe Item.Quality )
activeSeries model =
    model.listings
        |> Dict.values
        |> List.filter (Market.isLive model.now)
        |> List.map (\l -> ( Item.priceKey l.itemId l.quality, ( l.itemId, l.quality ) ))
        |> Dict.fromList
        |> Dict.values
        |> List.filterMap (\( itemId, quality ) -> Item.byId itemId |> Maybe.map (\item -> ( item, quality )))


{-| The estimate a listing's price is compared against, and how far off it is.
-}
listingEstimate : FrontendModel -> Listing -> Maybe ( Pricing.Estimate, Int )
listingEstimate model listing =
    case ( estimateFor model (Item.priceKey listing.itemId listing.quality), Market.unitPrice listing ) of
        ( Just est, Just price ) ->
            Just ( est, Pricing.deviationPercent est.median price )

        _ ->
            Nothing


offersFor : FrontendModel -> Int -> List Offer
offersFor model listingId =
    model.offers
        |> Dict.values
        |> List.filter (\o -> o.listingId == listingId)
        |> List.sortBy (.at >> Time.posixToMillis >> negate)


{-| Open offers on my listings that I haven't answered yet.
-}
pendingResponses : FrontendModel -> Int
pendingResponses model =
    case myName model of
        Just name ->
            model.offers
                |> Dict.values
                |> List.filter
                    (\o ->
                        o.status
                            == OfferOpen
                            && (Dict.get o.listingId model.listings |> Maybe.map (\l -> l.trader == name && not l.closed) |> Maybe.withDefault False)
                    )
                |> List.length

        Nothing ->
            0


type alias TraderStats =
    { activeListings : Int
    , offersMade : Int
    , offersAccepted : Int
    , partners : Int
    , days : Int
    }


traderStats : FrontendModel -> String -> TraderStats
traderStats model name =
    let
        listings =
            Dict.values model.listings

        offers =
            Dict.values model.offers

        mine =
            List.filter (\l -> l.trader == name) listings

        myListingIds =
            List.map .id mine

        made =
            List.filter (\o -> o.from == name && o.status /= OfferWithdrawn) offers

        partnerNames =
            (made |> List.filterMap (\o -> Dict.get o.listingId model.listings |> Maybe.map .trader))
                ++ (offers |> List.filter (\o -> List.member o.listingId myListingIds && o.status /= OfferWithdrawn) |> List.map .from)
                |> List.foldl
                    (\x acc ->
                        if List.member x acc then
                            acc

                        else
                            x :: acc
                    )
                    []

        joined =
            Dict.get name model.traders |> Maybe.map .joinedAt |> Maybe.withDefault model.now
    in
    { activeListings = mine |> List.filter (not << .closed) |> List.length
    , offersMade = List.length made
    , offersAccepted = made |> List.filter (\o -> o.status == OfferAccepted) |> List.length
    , partners = List.length partnerNames
    , days = (Time.posixToMillis model.now - Time.posixToMillis joined) // 86400000
    }


{-| Open listings after the market tab, filters, search and sort are applied.
-}
marketListings : FrontendModel -> List Listing
marketListings model =
    let
        f =
            model.filters

        query =
            String.toLower (String.trim f.search)

        tabOk l =
            case ( f.tab, l.payment ) of
                ( AllListings, _ ) ->
                    True

                ( SwapsTab, Swap _ _ ) ->
                    True

                ( SwapsTab, Coins _ ) ->
                    False

                ( SellingTab, Coins _ ) ->
                    l.side == Selling

                ( BuyingTab, Coins _ ) ->
                    l.side == Buying

                _ ->
                    False

        gradeOk l =
            case Market.item l of
                Just item ->
                    let
                        rarityOk =
                            case item.kind of
                                Item.Loot r ->
                                    List.isEmpty f.rarities || List.member r f.rarities

                                _ ->
                                    List.isEmpty f.rarities

                        qualityOk =
                            case l.quality of
                                Just q ->
                                    List.isEmpty f.qualities || List.member q f.qualities

                                Nothing ->
                                    List.isEmpty f.qualities
                    in
                    rarityOk && qualityOk

                Nothing ->
                    False

        searchOk l =
            query
                == ""
                || String.contains query (String.toLower l.trader)
                || (Market.item l |> Maybe.map (\i -> String.contains query (String.toLower i.name)) |> Maybe.withDefault False)

        outlierOk l =
            not f.hideOutliers
                || (case listingEstimate model l of
                        Just ( _, pct ) ->
                            not (Pricing.isWarning pct)

                        Nothing ->
                            True
                   )

        sorter =
            case f.sort of
                Newest ->
                    List.sortBy (.createdAt >> Time.posixToMillis >> negate)

                PriceLow ->
                    List.sortBy (Market.unitPrice >> Maybe.withDefault 999999999999)

                PriceHigh ->
                    List.sortBy (Market.unitPrice >> Maybe.withDefault -1 >> negate)
    in
    model.listings
        |> Dict.values
        |> List.filter (\l -> not l.closed && tabOk l && gradeOk l && searchOk l && outlierOk l)
        |> sorter
