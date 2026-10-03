module Market exposing
    ( activeListingCount
    , isLive
    , item
    , maxActiveListings
    , pricePoints
    , unitPrice
    )

{-| Shared rules about listings and offers, used by both backend and frontend.
-}

import Dict exposing (Dict)
import Item exposing (Item)
import Pricing
import Time
import Types exposing (Listing, Offer, OfferStatus(..), Payment(..), Side(..))


maxActiveListings : Int
maxActiveListings =
    10


isLive : Time.Posix -> Listing -> Bool
isLive now listing =
    Time.posixToMillis listing.liveAt <= Time.posixToMillis now


activeListingCount : String -> List Listing -> Int
activeListingCount trader listings =
    listings |> List.filter (\l -> l.trader == trader && not l.closed) |> List.length


item : Listing -> Maybe Item
item listing =
    Item.byId listing.itemId


unitPrice : Listing -> Maybe Int
unitPrice listing =
    case listing.payment of
        Coins price ->
            Just price


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
