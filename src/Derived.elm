module Derived exposing
    ( Series
    , TraderStats
    , activeSeries
    , awaitsResponse
    , estimateFor
    , isReady
    , listingEstimate
    , marketListings
    , myName
    , myOpenOffer
    , offersFor
    , offersReceived
    , offersSent
    , onboardingRoute
    , pendingResponses
    , traderStats
    , tradePending
    , traded
    )

{-| Values the frontend computes from the listings, offers and traders it holds.
-}

import Account
import Dict
import Item
import Market
import Pricing
import Route exposing (Route)
import Set
import Time
import Types exposing (FrontendModel, Listing, MarketSort(..), MarketTab(..), Offer, OfferStatus(..), Side(..))


myName : FrontendModel -> Maybe String
myName model =
    model.me |> Maybe.andThen Account.claimedName


{-| Signed in and named.
-}
isReady : FrontendModel -> Bool
isReady model =
    (model.me |> Maybe.andThen Account.claimedName) /= Nothing


{-| Where to send someone who isn't `isReady` yet to link their name.
-}
onboardingRoute : FrontendModel -> Route
onboardingRoute model =
    if model.me == Nothing then
        Route.SignIn

    else
        Route.Onboarding


estimateFor : FrontendModel -> String -> Maybe Pricing.Estimate
estimateFor model key =
    Market.pricePoints model.now model.listings model.offers key |> Pricing.estimate


type alias Series =
    { item : Item.Item
    , variant : Item.Variant
    , points : List Pricing.Point
    , estimate : Pricing.Estimate
    }


{-| Price series (item + fine + quality) that have a live listing, the ones
with the most prices first.
-}
activeSeries : FrontendModel -> List Series
activeSeries model =
    model.listings
        |> Dict.values
        |> List.filter (Market.isLive model.now)
        |> List.map (\l -> ( Item.priceKey l.itemId l.variant, ( l.itemId, l.variant ) ))
        |> Dict.fromList
        |> Dict.toList
        |> List.filterMap
            (\( key, ( itemId, variant ) ) ->
                let
                    points =
                        Market.pricePoints model.now model.listings model.offers key
                in
                Maybe.map2 (\item estimate -> { item = item, variant = variant, points = points, estimate = estimate })
                    (Item.byId itemId)
                    (Pricing.estimate points)
            )
        |> List.sortBy (.points >> List.length >> negate)


{-| The estimate a listing's price is compared against, and how far off it is.
-}
listingEstimate : FrontendModel -> Listing -> Maybe ( Pricing.Estimate, Int )
listingEstimate model listing =
    case ( estimateFor model (Item.priceKey listing.itemId listing.variant), Market.unitPrice listing ) of
        ( Just est, Just price ) ->
            Just ( est, Pricing.deviationPercent est.median price )

        _ ->
            Nothing


newestFirst : List Offer -> List Offer
newestFirst =
    List.sortBy (.at >> Time.posixToMillis >> negate)


offersFor : FrontendModel -> Int -> List Offer
offersFor model listingId =
    model.offers
        |> Dict.values
        |> List.filter (\o -> o.listingId == listingId)
        |> newestFirst


myOpenOffer : FrontendModel -> Int -> Maybe Offer
myOpenOffer model listingId =
    myName model |> Maybe.andThen (\name -> Market.openOfferFrom name listingId (Dict.values model.offers))


{-| Offers on `name`'s listings, newest first. Withdrawn ones are left out.
-}
offersReceived : FrontendModel -> String -> List Offer
offersReceived model name =
    model.offers
        |> Dict.values
        |> List.filter (\o -> o.status /= OfferWithdrawn && (Dict.get o.listingId model.listings |> Maybe.map .trader) == Just name)
        |> newestFirst


{-| Offers `name` has made, newest first, including withdrawn ones.
-}
offersSent : FrontendModel -> String -> List Offer
offersSent model name =
    model.offers
        |> Dict.values
        |> List.filter (\o -> o.from == name)
        |> newestFirst


{-| An accepted offer on the listing hasn't been resolved yet (see
`Market.tradePending`).
-}
tradePending : FrontendModel -> Int -> Bool
tradePending model listingId =
    Market.tradePending listingId (Dict.values model.offers)


{-| Both sides confirmed a trade on the listing.
-}
traded : FrontendModel -> Int -> Bool
traded model listingId =
    offersFor model listingId
        |> List.any
            (\o ->
                case o.status of
                    OfferCompleted _ ->
                        True

                    _ ->
                        False
            )


{-| An open offer on a listing that's still open and has no trade pending, so
its owner can accept it.
-}
awaitsResponse : FrontendModel -> Offer -> Bool
awaitsResponse model offer =
    offer.status
        == OfferOpen
        && (Dict.get offer.listingId model.listings |> Maybe.map (not << .closed) |> Maybe.withDefault False)
        && not (tradePending model offer.listingId)


{-| Offers on my listings that I haven't answered yet.
-}
pendingResponses : FrontendModel -> Int
pendingResponses model =
    case myName model of
        Just name ->
            offersReceived model name |> List.filter (awaitsResponse model) |> List.length

        Nothing ->
            0


type alias TraderStats =
    { activeListings : Int
    , offersMade : Int
    , trades : Int
    , fellThrough : Int
    , partners : Int
    , days : Int
    }


traderStats : FrontendModel -> String -> TraderStats
traderStats model name =
    let
        made =
            offersSent model name |> List.filter (\o -> o.status /= OfferWithdrawn)

        partners =
            (made |> List.filterMap (\o -> Dict.get o.listingId model.listings |> Maybe.map .trader))
                ++ (offersReceived model name |> List.map .from)
                |> Set.fromList

        joined =
            Dict.get name model.traders |> Maybe.map .joinedAt |> Maybe.withDefault model.now

        resolved =
            made ++ offersReceived model name |> List.map .status

        count isIt =
            resolved |> List.filter isIt |> List.length
    in
    { activeListings = Market.activeListingCount name (Dict.values model.listings)
    , offersMade = List.length made
    , trades =
        count
            (\s ->
                case s of
                    OfferCompleted _ ->
                        True

                    _ ->
                        False
            )
    , fellThrough =
        count
            (\s ->
                case s of
                    OfferFellThrough _ ->
                        True

                    _ ->
                        False
            )
    , partners = Set.size partners
    , days = (Time.posixToMillis model.now - Time.posixToMillis joined) // 86400000
    }


{-| Open listings after the market tab, filters, search and sort are applied.
Listings with a trade pending are left out.
-}
marketListings : FrontendModel -> List Listing
marketListings model =
    let
        f =
            model.filters

        query =
            String.toLower (String.trim f.search)

        tabOk l =
            case f.tab of
                AllListings ->
                    True

                SellingTab ->
                    l.side == Selling

                BuyingTab ->
                    l.side == Buying

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
                            case l.variant.quality of
                                Just q ->
                                    List.isEmpty f.qualities || List.member q f.qualities

                                Nothing ->
                                    List.isEmpty f.qualities
                    in
                    rarityOk && qualityOk && (l.variant.fine || not f.fineOnly)

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
        |> List.filter (\l -> not l.closed && not (tradePending model l.id) && tabOk l && gradeOk l && searchOk l && outlierOk l)
        |> sorter
