module UnitTests exposing (suite)

import Expect
import Item
import Market
import Name
import Page.NewListing
import Pricing exposing (Source(..), Status(..))
import Route
import Test exposing (Test, describe, test)
import Time
import Types exposing (OfferStatus(..), Payment(..), Side(..))
import Url


day : Int
day =
    86400000


point : String -> Int -> Int -> Pricing.Point
point trader price at =
    { price = price, trader = trader, at = Time.millisToPosix at, source = Ask }


suite : Test
suite =
    describe "Unit tests"
        [ describe "Pricing.estimate"
            [ test "no points means no estimate" <|
                \_ -> Pricing.estimate [] |> Expect.equal Nothing
            , test "median, not average" <|
                \_ ->
                    [ point "a" 100 0, point "b" 110 0, point "c" 120 0, point "d" 130 0, point "e" 900 0 ]
                        |> Pricing.estimate
                        |> Maybe.map .median
                        |> Expect.equal (Just 115)
            , test "a wild price is excluded as an outlier" <|
                \_ ->
                    [ point "a" 8800 0, point "b" 9000 0, point "c" 9100 0, point "d" 8900 0, point "e" 30000 0 ]
                        |> Pricing.classify
                        |> List.map Tuple.second
                        |> Expect.equal [ Counted, Counted, Counted, Counted, Outlier ]
            , test "only a trader's latest price per day counts" <|
                \_ ->
                    [ point "a" 100 1000, point "a" 120 2000, point "b" 110 3000, point "a" 130 (day + 10) ]
                        |> Pricing.classify
                        |> List.map Tuple.second
                        |> Expect.equal [ Repeat, Counted, Counted, Counted ]
            , test "counts traders and exclusions" <|
                \_ ->
                    [ point "a" 100 0, point "a" 100 5, point "b" 100 0 ]
                        |> Pricing.estimate
                        |> Maybe.map (\e -> ( e.counted, e.excluded, e.traders ))
                        |> Expect.equal (Just ( 2, 1, 2 ))
            , test "identical prices still form a normal range" <|
                \_ ->
                    [ point "a" 500 0, point "b" 500 0, point "c" 540 0 ]
                        |> Pricing.classify
                        |> List.map Tuple.second
                        |> Expect.equal [ Counted, Counted, Counted ]
            , test "deviation and warnings" <|
                \_ ->
                    ( Pricing.deviationPercent 8900 11480, Pricing.isWarning 29, Pricing.isWarning -25 )
                        |> Expect.equal ( 29, True, False )
            ]
        , describe "Name"
            [ test "validates length and characters" <|
                \_ ->
                    List.map (Name.validate >> Result.toMaybe) [ "  Wanderling ", "ab", "bad name!", "Juno_Trek", "Juno-Trek", "Émile", "Ñandú" ]
                        |> Expect.equal [ Just "Wanderling", Nothing, Nothing, Nothing, Nothing, Nothing, Nothing ]
            , test "allows single spaces between words, like real WalkScape characters" <|
                \_ ->
                    List.map (Name.validate >> Result.toMaybe)
                        [ "Slyth Inaru", "  Mietosalsa the Mild ", "2nd beta patch", "Leviathan Von Weltzien", "Abcdefghij Abcdefghij Abcdefgh", "Isaac X" ]
                        |> Expect.equal
                            [ Just "Slyth Inaru", Just "Mietosalsa the Mild", Just "2nd beta patch", Just "Leviathan Von Weltzien", Just "Abcdefghij Abcdefghij Abcdefgh", Just "Isaac X" ]
            , test "rejects doubled spaces, whitespace other than a space, and names over 30 characters" <|
                \_ ->
                    List.map (Name.validate >> Result.toMaybe)
                        [ "Slyth  Inaru", "Slyth\tInaru", "Slyth\nInaru", "Abcdefghij Abcdefghij Abcdefghi", "   " ]
                        |> Expect.equal [ Nothing, Nothing, Nothing, Nothing, Nothing ]
            , test "needs at least 3 letters or numbers, not counting spaces" <|
                \_ ->
                    List.map (Name.validate >> Result.toMaybe) [ "A B", "A  B", "Ab", "Abc", "A B C", "Joe", "5cm" ]
                        |> Expect.equal [ Nothing, Nothing, Nothing, Just "Abc", Just "A B C", Just "Joe", Just "5cm" ]
            , test "flags names one edit, an underscore or a space away from an established name" <|
                \_ ->
                    List.map (\n -> Name.lookalikeOf n [ "Mossbeard", "Tallowmere" ]) [ "Mosbeard_", "Mossbeard_", "Mossbeerd", "Mossbeard", "Pikewalker" ]
                        |> Expect.equal [ Just "Mossbeard", Just "Mossbeard", Just "Mossbeard", Nothing, Nothing ]
            , test "a space, an underscore or neither all look alike" <|
                \_ ->
                    List.map (\n -> Name.lookalikeOf n [ "Slyth Inaru" ]) [ "SlythInaru", "Slyth_Inaru", "Slyth Inaru", "slyth inaru", "Slyth Inara" ]
                        |> Expect.equal [ Just "Slyth Inaru", Just "Slyth Inaru", Nothing, Nothing, Just "Slyth Inaru" ]
            , test "short names aren't flagged for a single different letter" <|
                \_ -> Name.lookalikeOf "Abc" [ "Abd" ] |> Expect.equal Nothing
            ]
        , describe "Route"
            [ test "percent-encodes spaces in names" <|
                \_ ->
                    ( Route.toString (Route.Profile "Slyth Inaru"), Route.toString (Route.Report "Rabyte Black") )
                        |> Expect.equal ( "/u/Slyth%20Inaru", "/report/Rabyte%20Black" )
            , test "round-trips every route" <|
                \_ ->
                    let
                        routes =
                            [ Route.Home
                            , Route.Market
                            , Route.Prices
                            , Route.ItemPrice "iron_pickaxe" { fine = False, rare = False, quality = Just Item.Eternal }
                            , Route.ItemPrice "iron_bar" { fine = True, rare = False, quality = Nothing }
                            , Route.ItemPrice "camel_egg" { fine = False, rare = True, quality = Nothing }
                            , Route.ItemPrice "shovel_axe" Item.plain
                            , Route.ListingPage 42
                            , Route.NewListing Nothing
                            , Route.NewListing (Just ( "dolphin_egg", { fine = False, rare = True, quality = Nothing } ))
                            , Route.NewListing (Just ( "iron_pickaxe", { fine = False, rare = False, quality = Just Item.Perfect } ))
                            , Route.MyTrades
                            , Route.Profile "Juno_Trek"
                            , Route.Profile "Slyth Inaru"
                            , Route.Report "Mosbeard_"
                            , Route.Report "Rabyte Black"
                            , Route.SignIn
                            , Route.Onboarding
                            ]

                        parse r =
                            Url.fromString ("https://trailpost.lamdera.app" ++ Route.toString r) |> Maybe.map Route.fromUrl
                    in
                    List.map parse routes |> Expect.equal (List.map Just routes)
            ]
        , describe "Item catalog"
            [ test "is imported from the WalkScape API with kinds mapped" <|
                \_ ->
                    ( List.length Item.all > 700
                    , Item.byId "shovel_axe" |> Maybe.map (\i -> Item.gradeLabel i Item.plain)
                    , [ "gold_ring", "copper_ore" ] |> List.filterMap Item.byId |> List.map (\i -> Item.gradeLabel i Item.plain)
                    )
                        |> Expect.equal ( True, Just "Legendary", [ "Crafted item", "Material" ] )
            , test "search puts names that start with the query first, ignoring a leading \"fine\" or \"rare\"" <|
                \_ ->
                    [ "iron pick", "Fine iron pick", "rare camel" ]
                        |> List.map (Item.search >> List.map .id >> List.head)
                        |> Expect.equal [ Just "iron_pickaxe", Just "iron_pickaxe", Just "camel_egg" ]
            ]
        , describe "Fine items"
            [ test "are a separate price series from regular ones, and from each crafted quality" <|
                \_ ->
                    [ Item.priceKey "iron_bar" Item.plain
                    , Item.priceKey "iron_bar" { fine = True, rare = False, quality = Nothing }
                    , Item.priceKey "iron_pickaxe" { fine = False, rare = False, quality = Just Item.Perfect }
                    ]
                        |> Expect.equal [ "iron_bar", "iron_bar/fine", "iron_pickaxe/perfect" ]
            , test "keep the plain item name and are labelled as fine" <|
                \_ ->
                    Item.byId "iron_bar"
                        |> Maybe.map (\i -> Item.gradeLabel i { fine = True, rare = False, quality = Nothing })
                        |> Expect.equal (Just "Fine · Material")
            , test "only materials and consumables can be fine" <|
                \_ ->
                    [ "iron_bar", "cooked_shrimp", "iron_pickaxe", "shovel_axe", "camel_egg", "agility_chip" ]
                        |> List.map (\id -> Page.NewListing.toDraft { form | itemId = Just id, fine = True, price = "50" } |> Result.map (.variant >> .fine))
                        |> Expect.equal [ Ok True, Ok True, Ok False, Ok False, Ok False, Ok False ]
            ]
        , describe "Rare pet eggs"
            [ test "only pet eggs can be rare" <|
                \_ ->
                    [ "camel_egg", "egg", "iron_bar", "shovel_axe" ]
                        |> List.map (\id -> Page.NewListing.toDraft { form | itemId = Just id, rare = True, price = "50" } |> Result.map (.variant >> .rare))
                        |> Expect.equal [ Ok True, Ok False, Ok False, Ok False ]
            , test "are their own price series and are labelled as rare" <|
                \_ ->
                    ( Item.priceKey "camel_egg" { fine = False, rare = True, quality = Nothing }
                    , Item.byId "camel_egg" |> Maybe.map (\i -> ( Item.gradeLabel i Item.plain, Item.gradeLabel i { fine = False, rare = True, quality = Nothing } ))
                    )
                        |> Expect.equal ( "camel_egg/rare", Just ( "Egg", "Rare · Egg" ) )
            ]
        , describe "Page.NewListing.toDraft"
            [ test "accepts 1.2k style prices and sets quality for crafted items" <|
                \_ ->
                    Page.NewListing.toDraft { form | itemId = Just "iron_pickaxe", quality = Item.Perfect, price = "1.2k", quantity = "3" }
                        |> Result.map (\d -> ( d.variant.quality, d.payment, d.quantity ))
                        |> Expect.equal (Ok ( Just Item.Perfect, Coins 1200, 3 ))
            , test "loot items have no quality" <|
                \_ ->
                    Page.NewListing.toDraft { form | itemId = Just "shovel_axe", price = "4" }
                        |> Result.map (\d -> ( d.variant.quality, d.payment ))
                        |> Expect.equal (Ok ( Nothing, Coins 4 ))
            , test "rejects a zero quantity" <|
                \_ ->
                    Page.NewListing.toDraft { form | itemId = Just "coal", price = "10", quantity = "0" }
                        |> Expect.equal (Err "Enter a quantity above zero.")
            , test "rejects prices over a billion with a message that says so" <|
                \_ ->
                    Page.NewListing.toDraft { form | itemId = Just "coal", price = "2000000000" }
                        |> Expect.equal (Err "Keep the price under a billion coins.")
            , test "rejects a note over 280 characters" <|
                \_ ->
                    Page.NewListing.toDraft { form | itemId = Just "coal", price = "10", note = String.repeat 281 "a" }
                        |> Expect.equal (Err "Keep your note under 280 characters.")
            ]
        , describe "Item.normalizeVariant"
            [ test "drops fine, rare and quality where the item can't have them, and defaults crafted quality to Normal" <|
                \_ ->
                    [ ( "agility_chip", { fine = True, rare = True, quality = Just Item.Perfect } )
                    , ( "iron_pickaxe", { fine = True, rare = False, quality = Nothing } )
                    ]
                        |> List.filterMap (\( id, v ) -> Item.byId id |> Maybe.map (\i -> Item.normalizeVariant i v))
                        |> Expect.equal
                            [ { fine = False, rare = False, quality = Nothing }
                            , { fine = False, rare = False, quality = Just Item.Normal }
                            ]
            ]
        , describe "Market.validateDraft"
            [ test "rejects a variant the item doesn't come in" <|
                \_ ->
                    Market.validateDraft
                        { itemId = "shovel_axe"
                        , variant = { fine = False, rare = False, quality = Just Item.Good }
                        , side = Selling
                        , payment = Coins 10
                        , quantity = 1
                        , note = ""
                        }
                        |> Expect.equal (Err "This item doesn't come in that version.")
            ]
        , describe "Market.validateOffer"
            [ test "checks the price and trims the message" <|
                \_ ->
                    [ Market.validateOffer (Just 0) "hi"
                    , Market.validateOffer Nothing "  hi  "
                    ]
                        |> Expect.equal
                            [ Err "Enter a price above zero."
                            , Ok { price = Nothing, message = "hi" }
                            ]
            ]
        , describe "Market.tradeTerms"
            [ test "an offer on a sell listing: the lister hands over the items, the offerer pays its price for all of them" <|
                \_ ->
                    Market.tradeTerms (listing Selling) (offer (Just 7500))
                        |> Expect.equal { seller = "Vimes", buyer = "Belkarama", coins = 37500 }
            , test "an offer at the listed price on a buy listing: the offerer hands over the items" <|
                \_ ->
                    Market.tradeTerms (listing Buying) (offer Nothing)
                        |> Expect.equal { seller = "Belkarama", buyer = "Vimes", coins = 40000 }
            ]
        , describe "Market trade rules"
            [ test "a listing with an accepted offer has a trade pending until it's resolved" <|
                \_ ->
                    [ Market.tradePending 1 [ offer Nothing ]
                    , Market.tradePending 1 [ { openOffer | id = 3 } ]
                    , Market.tradePending 1 [ { accepted | status = OfferCompleted (Time.millisToPosix 5) } ]
                    , Market.tradePending 1 [ { accepted | status = OfferFellThrough { by = "Vimes", at = Time.millisToPosix 5, reason = "Offline" } } ]
                    ]
                        |> Expect.equal [ True, False, False, False ]
            , test "can't accept, make an offer or close while a trade is pending" <|
                \_ ->
                    [ Market.checkAccept (listing Selling) [ offer Nothing, openOffer ]
                    , Market.checkNewOffer (listing Selling) [ offer Nothing ]
                    , Market.checkClose (listing Selling) [ offer Nothing ]
                    ]
                        |> Expect.equal
                            [ Err "Finish the pending trade on this listing before you accept another offer."
                            , Err "A trade is pending on this listing, so it isn't taking offers right now."
                            , Err "You can't close this listing while a trade is pending. Mark the trade as gone through or fallen through first."
                            ]
            , test "with no trade pending, accepting, offering and closing are fine" <|
                \_ ->
                    [ Market.checkAccept (listing Selling) [ openOffer ]
                    , Market.checkNewOffer (listing Selling) [ openOffer ]
                    , Market.checkClose (listing Selling) [ { accepted | status = OfferCompleted (Time.millisToPosix 5) } ]
                    ]
                        |> Expect.equal [ Ok (), Ok (), Ok () ]
            , test "each side confirms separately, and the second confirmation completes the trade" <|
                \_ ->
                    Market.confirmTrade "Vimes" (Time.millisToPosix 10) (listing Selling) (offer Nothing)
                        |> Result.andThen (Market.confirmTrade "Belkarama" (Time.millisToPosix 20) (listing Selling))
                        |> Result.map (\o -> ( o.status, o.listerConfirmed, o.offererConfirmed ))
                        |> Expect.equal (Ok ( OfferCompleted (Time.millisToPosix 20), True, True ))
            , test "one confirmation leaves the trade pending" <|
                \_ ->
                    Market.confirmTrade "Belkarama" (Time.millisToPosix 10) (listing Selling) (offer Nothing)
                        |> Result.map (\o -> ( o.status, o.listerConfirmed, o.offererConfirmed ))
                        |> Expect.equal (Ok ( OfferAccepted, False, True ))
            , test "only the two traders can confirm or mark a trade as fallen through" <|
                \_ ->
                    [ Market.confirmTrade "Mallory" (Time.millisToPosix 10) (listing Selling) (offer Nothing) |> Result.map .status
                    , Market.markFellThrough "Mallory" "nope" (Time.millisToPosix 10) (listing Selling) (offer Nothing) |> Result.map .status
                    ]
                        |> Expect.equal [ Err "Only the two traders can do that.", Err "Only the two traders can do that." ]
            , test "falling through stores who, when and why, and is final" <|
                \_ ->
                    let
                        fell =
                            OfferFellThrough { by = "Vimes", at = Time.millisToPosix 10, reason = "They went offline" }
                    in
                    [ Market.markFellThrough "Vimes" "  They went offline " (Time.millisToPosix 10) (listing Selling) (offer Nothing) |> Result.map .status
                    , Market.markFellThrough "Vimes" "  " (Time.millisToPosix 10) (listing Selling) (offer Nothing) |> Result.map .status
                    , Market.confirmTrade "Belkarama" (Time.millisToPosix 20) (listing Selling) { accepted | status = fell } |> Result.map .status
                    , Market.markFellThrough "Belkarama" "again" (Time.millisToPosix 20) (listing Selling) { accepted | status = fell } |> Result.map .status
                    ]
                        |> Expect.equal
                            [ Ok fell
                            , Err "Say what happened, in a few words."
                            , Err "That trade isn't pending."
                            , Err "That trade isn't pending."
                            ]
            ]
        ]


listing : Side -> Types.Listing
listing side =
    { id = 1
    , trader = "Vimes"
    , itemId = "salty_hops"
    , variant = { fine = True, rare = False, quality = Nothing }
    , side = side
    , payment = Coins 8000
    , quantity = 5
    , note = ""
    , createdAt = Time.millisToPosix 0
    , liveAt = Time.millisToPosix 0
    , closed = False
    }


offer : Maybe Int -> Types.Offer
offer price =
    { id = 2
    , listingId = 1
    , from = "Belkarama"
    , price = price
    , message = ""
    , at = Time.millisToPosix 0
    , status = OfferAccepted
    , listerConfirmed = False
    , offererConfirmed = False
    }


accepted : Types.Offer
accepted =
    offer Nothing


openOffer : Types.Offer
openOffer =
    { accepted | id = 3, from = "Mallory", status = OfferOpen }


form : Types.ListingForm
form =
    { itemQuery = ""
    , itemId = Nothing
    , quality = Item.Normal
    , fine = False
    , rare = False
    , side = Selling
    , quantity = "1"
    , price = ""
    , note = ""
    , error = Nothing
    , submitting = False
    }
