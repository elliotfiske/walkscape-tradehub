module Market exposing
    ( activeListingCount
    , checkAccept
    , checkClose
    , checkNewOffer
    , confirmTrade
    , describe
    , describeLine
    , describeTrade
    , isLive
    , item
    , markFellThrough
    , maxActiveListings
    , maxOfferItems
    , openOfferFrom
    , parseCoins
    , parsePrice
    , pricePoints
    , sortByPrice
    , tradePending
    , tradeTerms
    , wasAccepted
    , unitPrice
    , validateDraft
    , validateOffer
    )

{-| Shared rules about listings and offers, used by both backend and frontend.
-}

import Dict exposing (Dict)
import Item exposing (Item)
import Pricing
import Time
import Types exposing (ItemLine, Listing, ListingDraft, Offer, OfferDraft, OfferStatus(..), Payment(..), Side(..))


maxActiveListings : Int
maxActiveListings =
    20


maxPrice : Int
maxPrice =
    1000000000


maxQuantity : Int
maxQuantity =
    1000000


{-| Item lines in one offer.
-}
maxOfferItems : Int
maxOfferItems =
    5


{-| For listing notes and offer messages.
-}
maxTextLength : Int
maxTextLength =
    280


isLive : Time.Posix -> Listing -> Bool
isLive now listing =
    Time.posixToMillis listing.liveAt <= Time.posixToMillis now


activeListingCount : String -> List Listing -> Int
activeListingCount trader listings =
    listings |> List.filter (\l -> l.trader == trader && not l.closed) |> List.length


item : Listing -> Maybe Item
item listing =
    Item.byId listing.itemId


{-| "Selling 2x fine Iron bar" or "Buying 1x rare Camel egg", for logs and
admin lists.
-}
describe : Listing -> String
describe listing =
    (case listing.side of
        Selling ->
            "Selling "

        Buying ->
            "Buying "
    )
        ++ describeLine (listingLine listing)


{-| "Juno Trek sells 1x Shovel axe to Wanderling for 9800 coins" (or "for 2x
Coal and 1x fine Iron bar"), with the coins written the way the trade window
shows them.
-}
describeTrade : Listing -> Offer -> String
describeTrade listing offer =
    let
        terms =
            tradeTerms listing offer

        coins =
            if terms.coins > 0 then
                [ String.fromInt terms.coins ++ " coins" ]

            else
                []
    in
    terms.seller
        ++ " sells "
        ++ describeLine (listingLine listing)
        ++ " to "
        ++ terms.buyer
        ++ " for "
        ++ String.join " and " (coins ++ List.map describeLine terms.items)


{-| The listed items, as a line.
-}
listingLine : Listing -> ItemLine
listingLine listing =
    { itemId = listing.itemId, variant = listing.variant, quantity = listing.quantity }


{-| "2x fine Iron bar", "1x rare Camel egg", "1x Iron pickaxe · Perfect".
-}
describeLine : ItemLine -> String
describeLine line =
    String.fromInt line.quantity
        ++ "x "
        ++ (if line.variant.fine then
                "fine "

            else if line.variant.rare then
                "rare "

            else
                ""
           )
        ++ (Item.byId line.itemId |> Maybe.map (\i -> Item.fullName i line.variant) |> Maybe.withDefault line.itemId)


{-| The listing's coin price each, if it has one.
-}
unitPrice : Listing -> Maybe Int
unitPrice listing =
    case listing.payment of
        Coins price ->
            Just price

        ItemsOnly ->
            Nothing

        CoinsOrItems price ->
            price


{-| Cheapest first (or dearest first when `dearest`), with listings that have no
coin price last either way.
-}
sortByPrice : Bool -> List Listing -> List Listing
sortByPrice dearest =
    List.sortBy
        (\listing ->
            case unitPrice listing of
                Just price ->
                    ( 0
                    , if dearest then
                        negate price

                      else
                        price
                    )

                Nothing ->
                    ( 1, 0 )
        )


{-| The coins each an offer pays (0 for none). An offer with no price and no
items is "at your price"; one with items and no price pays only the items.
-}
offerCoinsEach : Listing -> Offer -> Int
offerCoinsEach listing offer =
    case ( offer.price, offer.items ) of
        ( Just price, _ ) ->
            price

        ( Nothing, [] ) ->
            unitPrice listing |> Maybe.withDefault 0

        ( Nothing, _ ) ->
            0


{-| What changes hands if `offer` on `listing` is traded: who hands over the
listed items, who pays, the total coins (0 for none) and the items paid on top.
-}
tradeTerms : Listing -> Offer -> { seller : String, buyer : String, coins : Int, items : List ItemLine }
tradeTerms listing offer =
    let
        coins =
            offerCoinsEach listing offer * listing.quantity
    in
    case listing.side of
        Selling ->
            { seller = listing.trader, buyer = offer.from, coins = coins, items = offer.items }

        Buying ->
            { seller = offer.from, buyer = listing.trader, coins = coins, items = offer.items }


{-| `trader`'s open offer on a listing, if they have one. A trader has at
most one; making another offer updates it.
-}
openOfferFrom : String -> Int -> List Offer -> Maybe Offer
openOfferFrom trader listingId offers =
    offers
        |> List.filter (\o -> o.listingId == listingId && o.from == trader && o.status == OfferOpen)
        |> List.head



-- TRADES


{-| Accepted at some point: pending, completed or fell through.
-}
wasAccepted : OfferStatus -> Bool
wasAccepted status =
    case status of
        OfferAccepted ->
            True

        OfferCompleted _ ->
            True

        OfferFellThrough _ ->
            True

        _ ->
            False


{-| An accepted offer on the listing that nobody has resolved yet. While there
is one, the listing is reserved for that trade.
-}
tradePending : Int -> List Offer -> Bool
tradePending listingId offers =
    List.any (\o -> o.listingId == listingId && o.status == OfferAccepted) offers


whenNoTradePending : String -> Listing -> List Offer -> Result String ()
whenNoTradePending err listing offers =
    if tradePending listing.id offers then
        Err err

    else
        Ok ()


checkAccept : Listing -> List Offer -> Result String ()
checkAccept =
    whenNoTradePending "Finish the pending trade on this listing before you accept another offer."


checkNewOffer : Listing -> List Offer -> Result String ()
checkNewOffer =
    whenNoTradePending "A trade is pending on this listing, so it isn't taking offers right now."


checkClose : Listing -> List Offer -> Result String ()
checkClose =
    whenNoTradePending "You can't close this listing while a trade is pending. Mark the trade as gone through or fallen through first."


{-| A pending trade that `trader` is one side of.
-}
pendingTradeFor : String -> Listing -> Offer -> Result String Offer
pendingTradeFor trader listing offer =
    if trader /= listing.trader && trader /= offer.from then
        Err "Only the two traders can do that."

    else if offer.status /= OfferAccepted then
        Err "That trade isn't pending."

    else
        Ok offer


{-| `trader` says the trade went through. Once both sides have, it's completed.
-}
confirmTrade : String -> Time.Posix -> Listing -> Offer -> Result String Offer
confirmTrade trader now listing offer =
    pendingTradeFor trader listing offer
        |> Result.map
            (\o ->
                let
                    confirmed =
                        if trader == listing.trader then
                            { o | listerConfirmed = True }

                        else
                            { o | offererConfirmed = True }
                in
                if confirmed.listerConfirmed && confirmed.offererConfirmed then
                    { confirmed | status = OfferCompleted now }

                else
                    confirmed
            )


{-| `trader` says the trade fell through. Either side can, and it's final.
-}
markFellThrough : String -> String -> Time.Posix -> Listing -> Offer -> Result String Offer
markFellThrough trader reason now listing offer =
    pendingTradeFor trader listing offer
        |> Result.andThen
            (\o ->
                checkText "reason" reason
                    |> Result.andThen
                        (\trimmed ->
                            if String.isEmpty trimmed then
                                Err "Say what happened, in a few words."

                            else
                                Ok { o | status = OfferFellThrough { by = trader, at = now, reason = trimmed } }
                        )
            )



-- VALIDATION


{-| Read a coin amount the way players type it: "9400", "9,400" or "9.4k".
-}
parseCoins : String -> Maybe Int
parseCoins s =
    let
        t =
            s |> String.replace "," "" |> String.replace " " "" |> String.toLower
    in
    if String.endsWith "k" t then
        String.toFloat (String.dropRight 1 t) |> Maybe.map (\f -> round (f * 1000))

    else
        String.toInt t


{-| A coin price typed into a form, checked the same way the backend checks it.
-}
parsePrice : String -> Result String Int
parsePrice s =
    parseCoins s
        |> Result.fromMaybe "Enter a price in coins, like 1200 or 1.2k."
        |> Result.andThen checkPrice


checkPrice : Int -> Result String Int
checkPrice price =
    if price <= 0 then
        Err "Enter a price above zero."

    else if price > maxPrice then
        Err "Keep the price under a billion coins."

    else
        Ok price


checkText : String -> String -> Result String String
checkText what text =
    if String.length text > maxTextLength then
        Err ("Keep your " ++ what ++ " under " ++ String.fromInt maxTextLength ++ " characters.")

    else
        Ok (String.trim text)


{-| Check a new listing. The frontend runs this before sending, and the
backend runs it again on what arrives.
-}
validateDraft : ListingDraft -> Result String ListingDraft
validateDraft draft =
    case Item.byId draft.itemId of
        Nothing ->
            Err "Pick an item from the list."

        Just listed ->
            if Item.normalizeVariant listed draft.variant /= draft.variant then
                Err "This item doesn't come in that version."

            else if draft.quantity <= 0 then
                Err "Enter a quantity above zero."

            else if draft.quantity > maxQuantity then
                Err "Keep the quantity under a million."

            else
                Result.map2 (\_ note -> { draft | note = note })
                    (case draft.payment of
                        Coins price ->
                            checkPrice price |> Result.map (always ())

                        ItemsOnly ->
                            Ok ()

                        CoinsOrItems price ->
                            price |> Maybe.map (checkPrice >> Result.map (always ())) |> Maybe.withDefault (Ok ())
                    )
                    (checkText "note" draft.note)


{-| Check an offer on `listing`: what it pays has to be something the listing
takes, and each item line is checked like a listing. The frontend runs this
before sending, and the backend runs it again on what arrives.
-}
validateOffer : Listing -> OfferDraft -> Result String OfferDraft
validateOffer listing draft =
    let
        price =
            case draft.price of
                Just p ->
                    checkPrice p |> Result.map Just

                Nothing ->
                    Ok Nothing

        takes =
            case ( listing.payment, draft.price, draft.items ) of
                ( Coins _, _, _ :: _ ) ->
                    Err "This listing only takes coins."

                ( ItemsOnly, Just _, _ ) ->
                    Err "This listing only takes items."

                ( ItemsOnly, Nothing, [] ) ->
                    Err "Add at least one item."

                ( CoinsOrItems Nothing, Nothing, [] ) ->
                    Err "Add coins, items or both."

                _ ->
                    Ok ()

        items =
            if List.length draft.items > maxOfferItems then
                Err ("Offer at most " ++ String.fromInt maxOfferItems ++ " items.")

            else
                draft.items |> List.map validateLine |> combine
    in
    Result.map4 (\p () i m -> { price = p, items = i, message = m })
        price
        takes
        items
        (checkText "message" draft.message)


validateLine : ItemLine -> Result String ItemLine
validateLine line =
    case Item.byId line.itemId of
        Nothing ->
            Err "Pick an item from the list."

        Just lineItem ->
            if Item.normalizeVariant lineItem line.variant /= line.variant then
                Err (lineItem.name ++ " doesn't come in that version.")

            else if line.quantity <= 0 then
                Err ("Enter a quantity above zero for " ++ lineItem.name ++ ".")

            else if line.quantity > maxQuantity then
                Err "Keep the quantity under a million."

            else
                Ok line


combine : List (Result e a) -> Result e (List a)
combine =
    List.foldr (Result.map2 (::)) (Ok [])



-- PRICES


{-| Price points for one listing. Only coins count: its own coin price if it
has one, each coin-only offer on it that wasn't withdrawn (an offer "at your
price" is another vote for the listed price), and each coin-only offer both
traders confirmed, as a `Pricing.Trade` dated when it went through. Item
offers say nothing about an item's price in coins.
-}
listingPoints : List Offer -> Listing -> List Pricing.Point
listingPoints offers listing =
    let
        own =
            case unitPrice listing of
                Just price ->
                    [ { price = price
                      , trader = listing.trader
                      , at = listing.createdAt
                      , source =
                            if listing.side == Selling then
                                Pricing.Ask

                            else
                                Pricing.Bid
                      }
                    ]

                Nothing ->
                    []

        coinOffers =
            offers
                |> List.filter (\o -> o.listingId == listing.id && List.isEmpty o.items && offerCoinsEach listing o > 0)

        fromOffers =
            coinOffers
                |> List.filter (\o -> o.status /= OfferWithdrawn)
                |> List.map (\o -> { price = offerCoinsEach listing o, trader = o.from, at = o.at, source = Pricing.Offer })

        trades =
            coinOffers
                |> List.filterMap
                    (\o ->
                        case o.status of
                            OfferCompleted at ->
                                Just { price = offerCoinsEach listing o, trader = o.from, at = at, source = Pricing.Trade }

                            _ ->
                                Nothing
                    )
    in
    own ++ fromOffers ++ trades


{-| All price points for a price series (see `Item.priceKey`), from listings
that have gone live (closed ones too, which is where completed trades are).
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
