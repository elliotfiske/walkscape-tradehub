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
import Types exposing (Payment(..), Side(..))
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
                    List.map (Name.validate >> Result.toMaybe) [ "  Wanderling ", "ab", "bad name!", "Juno_Trek" ]
                        |> Expect.equal [ Just "Wanderling", Nothing, Nothing, Just "Juno_Trek" ]
            , test "flags names one edit or an underscore away from an established name" <|
                \_ ->
                    List.map (\n -> Name.lookalikeOf n [ "Mossbeard", "Tallowmere" ]) [ "Mosbeard_", "Mossbeard_", "Mossbeerd", "Mossbeard", "Pikewalker" ]
                        |> Expect.equal [ Just "Mossbeard", Just "Mossbeard", Just "Mossbeard", Nothing, Nothing ]
            , test "short names aren't flagged for a single different letter" <|
                \_ -> Name.lookalikeOf "Abc" [ "Abd" ] |> Expect.equal Nothing
            ]
        , describe "Route"
            [ test "round-trips every route" <|
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
                            , Route.NewListing
                            , Route.MyTrades
                            , Route.Profile "Juno_Trek"
                            , Route.Report "Mosbeard_"
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
        ]


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
