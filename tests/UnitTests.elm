module UnitTests exposing (suite)

import Expect
import Item
import Market
import Name
import Page.NewListing
import Pricing exposing (Basis(..), Source(..), Status(..))
import Route
import Screenshot
import Test exposing (Test, describe, test)
import Time
import Dict
import Types exposing (OfferStatus(..), Payment(..), Side(..))
import Ui
import Url
import Users


day : Int
day =
    86400000


point : String -> Int -> Int -> Pricing.Point
point trader price at =
    { price = price, trader = trader, at = Time.millisToPosix at, source = Ask }


trade : String -> Int -> Int -> Pricing.Point
trade trader price at =
    { price = price, trader = trader, at = Time.millisToPosix at, source = Trade }


{-| "Now" for the pricing tests: day 40, so trades can be inside or outside the
30-day window.
-}
now : Time.Posix
now =
    Time.millisToPosix (40 * day)


suite : Test
suite =
    describe "Unit tests"
        [ describe "Pricing.estimate"
            [ test "no points means no estimate" <|
                \_ -> Pricing.estimate now [] |> Expect.equal Nothing
            , test "median, not average" <|
                \_ ->
                    [ point "a" 100 0, point "b" 110 0, point "c" 120 0, point "d" 130 0, point "e" 900 0 ]
                        |> Pricing.estimate now
                        |> Maybe.map .median
                        |> Expect.equal (Just 115)
            , test "a wild price is excluded as an outlier" <|
                \_ ->
                    [ point "a" 8800 0, point "b" 9000 0, point "c" 9100 0, point "d" 8900 0, point "e" 30000 0 ]
                        |> Pricing.classify now
                        |> List.map Tuple.second
                        |> Expect.equal [ Counted, Counted, Counted, Counted, Outlier ]
            , test "only a trader's latest price per day counts" <|
                \_ ->
                    [ point "a" 100 1000, point "a" 120 2000, point "b" 110 3000, point "a" 130 (day + 10) ]
                        |> Pricing.classify now
                        |> List.map Tuple.second
                        |> Expect.equal [ Repeat, Counted, Counted, Counted ]
            , test "counts traders and exclusions" <|
                \_ ->
                    [ point "a" 100 0, point "a" 100 5, point "b" 100 0 ]
                        |> Pricing.estimate now
                        |> Maybe.map (\e -> ( e.counted, e.excluded, e.traders ))
                        |> Expect.equal (Just ( 2, 1, 2 ))
            , test "identical prices still form a normal range" <|
                \_ ->
                    [ point "a" 500 0, point "b" 500 0, point "c" 540 0 ]
                        |> Pricing.classify now
                        |> List.map Tuple.second
                        |> Expect.equal [ Counted, Counted, Counted ]
            , test "two recent trades aren't enough, so asks and offers still decide" <|
                \_ ->
                    [ point "a" 100 (39 * day), point "b" 100 (39 * day), point "c" 100 (39 * day), trade "d" 200 (38 * day), trade "e" 200 (38 * day) ]
                        |> Pricing.estimate now
                        |> Maybe.map (\e -> ( e.median, e.basis ))
                        |> Expect.equal (Just ( 100, FromPrices ))
            , test "three trades in the last 30 days replace asks and offers" <|
                \_ ->
                    [ point "a" 100 (39 * day), point "b" 100 (39 * day), trade "c" 200 (38 * day), trade "d" 210 (20 * day), trade "e" 220 (11 * day) ]
                        |> Pricing.estimate now
                        |> Maybe.map (\e -> ( e.median, e.basis, e.counted ))
                        |> Expect.equal (Just ( 210, FromTrades, 3 ))
            , test "trades older than 30 days don't count" <|
                \_ ->
                    [ point "a" 100 (39 * day), trade "b" 200 (38 * day), trade "c" 210 (20 * day), trade "d" 220 (9 * day) ]
                        |> Pricing.estimate now
                        |> Maybe.map (\e -> ( e.median, e.basis ))
                        |> Expect.equal (Just ( 100, FromPrices ))
            , test "with enough trades, asks and offers are shown but not used" <|
                \_ ->
                    [ point "a" 100 (39 * day), trade "b" 200 (38 * day), trade "c" 210 (20 * day), trade "d" 220 (11 * day), trade "e" 900 (39 * day) ]
                        |> Pricing.classify now
                        |> List.map Tuple.second
                        |> Expect.equal [ NotUsed, Counted, Counted, Counted, Counted ]
            , test "without enough trades, the trades are shown but not used" <|
                \_ ->
                    [ point "a" 100 (39 * day), trade "b" 200 (38 * day) ]
                        |> Pricing.classify now
                        |> List.map Tuple.second
                        |> Expect.equal [ Counted, NotUsed ]
            , test "says what the estimate is made from" <|
                \_ ->
                    ( [ trade "a" 1 (39 * day), trade "b" 1 (39 * day), trade "c" 1 (39 * day), trade "d" 1 (39 * day), trade "e" 1 (39 * day) ]
                        |> Pricing.estimate now
                        |> Maybe.map Pricing.basisText
                    , [ point "a" 1 0 ] |> Pricing.estimate now |> Maybe.map Pricing.basisText
                    )
                        |> Expect.equal ( Just "from 5 trades", Just "from asks and offers" )
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
        , describe "Discord account age"
            [ test "reads the creation time from a Discord user id" <|
                \_ ->
                    -- The example snowflake from Discord's API docs: 2016-04-30T11:18:25.796Z.
                    Users.discordSince "OAuthDiscord:175928847299117063"
                        |> Expect.equal (Just (Time.millisToPosix 1462015105796))
            , test "preview accounts have none" <|
                \_ ->
                    ( Users.discordSince "preview:abc", Users.discordSince "preview-admin:abc", Users.discordSince "OAuthDiscord:nope" )
                        |> Expect.equal ( Nothing, Nothing, Nothing )
            , test "says how old an account is in days, months or years" <|
                \_ ->
                    [ 0, 1, 45, 59, 60, 400, 729, 730, 2000 ]
                        |> List.map (\days -> Ui.accountAge (Time.millisToPosix (2000 * day)) (Time.millisToPosix ((2000 - days) * day)))
                        |> Expect.equal
                            [ "account made today"
                            , "account 1 day old"
                            , "account 45 days old"
                            , "account 59 days old"
                            , "account 2 months old"
                            , "account 13 months old"
                            , "account 24 months old"
                            , "account 2 years old"
                            , "account 5 years old"
                            ]
            ]
        , describe "Screenshot.check"
            [ test "allows up to three JPEGs under the cap" <|
                \_ ->
                    Screenshot.check (List.repeat 3 (Screenshot.jpegPrefix ++ String.repeat (Screenshot.maxLength - 30) "A"))
                        |> Expect.equal (Ok ())
            , test "refuses a fourth" <|
                \_ ->
                    Screenshot.check (List.repeat 4 (Screenshot.jpegPrefix ++ "AAAA"))
                        |> Expect.equal (Err "You can add up to 3 screenshots.")
            , test "refuses one over the cap" <|
                \_ ->
                    Screenshot.check [ Screenshot.jpegPrefix ++ String.repeat Screenshot.maxLength "A" ]
                        |> Expect.equal (Err "One of the screenshots is too big. Try a smaller one.")
            , test "refuses anything that isn't a JPEG data URL" <|
                \_ ->
                    Screenshot.check [ "data:image/png;base64,AAAA" ]
                        |> Expect.equal (Err "Screenshots have to be JPEG images.")
            ]
        , describe "Route"
            [ test "percent-encodes spaces in names" <|
                \_ ->
                    ( Route.toString (Route.Profile "Slyth Inaru"), Route.toString (Route.Report "Rabyte Black" Nothing) )
                        |> Expect.equal ( "/u/Slyth%20Inaru", "/report/Rabyte%20Black" )
            , test "a trade report carries the offer id" <|
                \_ ->
                    Route.toString (Route.Report "Juno Trek" (Just 12))
                        |> Expect.equal "/report/Juno%20Trek?trade=12"
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
                            , Route.Report "Mosbeard_" Nothing
                            , Route.Report "Rabyte Black" Nothing
                            , Route.Report "Juno Trek" (Just 12)
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
                        , wants = []
                        , quantity = 1
                        , note = ""
                        }
                        |> Expect.equal (Err "This item doesn't come in that version.")
            ]
        , describe "Market.validateOffer"
            [ test "checks the price and trims the message" <|
                \_ ->
                    [ Market.validateOffer selling { coinOffer | price = Just 0 }
                    , Market.validateOffer selling { coinOffer | message = "  hi  " }
                    ]
                        |> Expect.equal
                            [ Err "Enter a price above zero."
                            , Ok { coinOffer | message = "hi" }
                            ]
            , test "a coin listing only takes coins" <|
                \_ ->
                    Market.validateOffer selling { coinOffer | items = [ line "coal" 2 ] }
                        |> Expect.equal (Err "This listing only takes coins.")
            , test "an items-only listing takes item lines and no coins" <|
                \_ ->
                    [ Market.validateOffer itemsOnly { coinOffer | items = [ line "coal" 2 ] }
                    , Market.validateOffer itemsOnly { coinOffer | price = Just 500, items = [ line "coal" 2 ] }
                    , Market.validateOffer itemsOnly coinOffer
                    ]
                        |> Expect.equal
                            [ Ok { coinOffer | items = [ line "coal" 2 ] }
                            , Err "This listing only takes items."
                            , Err "Add at least one item."
                            ]
            , test "a coins-or-items listing with no price needs coins, items or both" <|
                \_ ->
                    [ Market.validateOffer either coinOffer
                    , Market.validateOffer either { coinOffer | price = Just 500 }
                    , Market.validateOffer either { coinOffer | price = Just 500, items = [ line "coal" 2 ] }
                    ]
                        |> Expect.equal
                            [ Err "Add coins, items or both."
                            , Ok { coinOffer | price = Just 500 }
                            , Ok { coinOffer | price = Just 500, items = [ line "coal" 2 ] }
                            ]
            , test "checks each item line like a listing, and allows at most 5" <|
                \_ ->
                    [ [ line "not_an_item" 1 ]
                    , [ { itemId = "shovel_axe", variant = { fine = False, rare = False, quality = Just Item.Good }, quantity = 1 } ]
                    , [ line "coal" 0 ]
                    , List.repeat 6 (line "coal" 1)
                    ]
                        |> List.map (\items -> Market.validateOffer itemsOnly { coinOffer | items = items })
                        |> Expect.equal
                            [ Err "Pick an item from the list."
                            , Err "Shovel axe doesn't come in that version."
                            , Err "Enter a quantity above zero for Coal."
                            , Err "Offer at most 5 items."
                            ]
            ]
        , describe "Market.validateDraft payment"
            [ test "items only and coins or items need no price, but a price given must be valid" <|
                \_ ->
                    [ ItemsOnly, CoinsOrItems Nothing, CoinsOrItems (Just 0), CoinsOrItems (Just 900) ]
                        |> List.map (\payment -> Market.validateDraft { draft | payment = payment } |> Result.map .payment)
                        |> Expect.equal [ Ok ItemsOnly, Ok (CoinsOrItems Nothing), Err "Enter a price above zero.", Ok (CoinsOrItems (Just 900)) ]
            , test "the listing form maps the payment choice and only reads the price when it's needed" <|
                \_ ->
                    [ { form | itemId = Just "coal", paymentChoice = Types.PayItems, price = "junk" }
                    , { form | itemId = Just "coal", paymentChoice = Types.PayEither, price = "" }
                    , { form | itemId = Just "coal", paymentChoice = Types.PayEither, price = "1.5k" }
                    , { form | itemId = Just "coal", paymentChoice = Types.PayEither, price = "junk" }
                    ]
                        |> List.map (Page.NewListing.toDraft >> Result.map .payment)
                        |> Expect.equal
                            [ Ok ItemsOnly
                            , Ok (CoinsOrItems Nothing)
                            , Ok (CoinsOrItems (Just 1500))
                            , Err "Enter a price in coins, like 1200 or 1.2k."
                            ]
            ]
        , describe "Wanted items on a listing"
            [ test "only a listing that takes items can list wanted items, checked like offer lines" <|
                \_ ->
                    [ { draft | payment = ItemsOnly, wants = [ line "coal" 2 ] }
                    , { draft | payment = CoinsOrItems (Just 900), wants = [ line "coal" 2 ] }
                    , { draft | wants = [ line "coal" 2 ] }
                    , { draft | payment = ItemsOnly, wants = List.repeat 6 (line "coal" 1) }
                    , { draft | payment = ItemsOnly, wants = [ line "coal" 0 ] }
                    ]
                        |> List.map (Market.validateDraft >> Result.map .wants)
                        |> Expect.equal
                            [ Ok [ line "coal" 2 ]
                            , Ok [ line "coal" 2 ]
                            , Err "A listing that only takes coins can't ask for items."
                            , Err "List at most 5 items."
                            , Err "Enter a quantity above zero for Coal."
                            ]
            , test "the listing form reads wanted quantities, and drops them for a coins listing" <|
                \_ ->
                    let
                        wants q =
                            [ { itemId = "coal", variant = Item.plain, quantity = q } ]
                    in
                    [ { form | itemId = Just "coal", paymentChoice = Types.PayItems, wants = wants "3" }
                    , { form | itemId = Just "coal", paymentChoice = Types.PayItems, wants = wants "lots" }
                    , { form | itemId = Just "coal", paymentChoice = Types.PayCoins, price = "10", wants = wants "3" }
                    ]
                        |> List.map (Page.NewListing.toDraft >> Result.map .wants)
                        |> Expect.equal
                            [ Ok [ line "coal" 3 ]
                            , Err "Enter a quantity for Coal, like 1 or 50."
                            , Ok []
                            ]
            ]
        , describe "Market.sortByPrice"
            [ test "listings with no coin price sort last both ways" <|
                \_ ->
                    let
                        listings =
                            [ { selling | id = 1, payment = ItemsOnly }
                            , { selling | id = 2, payment = Coins 300 }
                            , { selling | id = 3, payment = CoinsOrItems Nothing }
                            , { selling | id = 4, payment = CoinsOrItems (Just 100) }
                            ]
                    in
                    [ Market.sortByPrice False listings, Market.sortByPrice True listings ]
                        |> List.map (List.map .id)
                        |> Expect.equal [ [ 4, 2, 1, 3 ], [ 2, 4, 1, 3 ] ]
            ]
        , describe "Market.tradeTerms"
            [ test "an offer on a sell listing: the lister hands over the items, the offerer pays its price for all of them" <|
                \_ ->
                    Market.tradeTerms (listing Selling) (offer (Just 7500))
                        |> Expect.equal { seller = "Vimes", buyer = "Belkarama", coins = 37500, items = [] }
            , test "an offer at the listed price on a buy listing: the offerer hands over the items" <|
                \_ ->
                    Market.tradeTerms (listing Buying) (offer Nothing)
                        |> Expect.equal { seller = "Belkarama", buyer = "Vimes", coins = 40000, items = [] }
            , test "an item offer pays its items, plus its coins each if it has any" <|
                \_ ->
                    [ Market.tradeTerms { selling | payment = CoinsOrItems (Just 8000) } { accepted | items = [ line "coal" 2 ] }
                    , Market.tradeTerms { selling | payment = CoinsOrItems Nothing } { accepted | price = Just 100, items = [ line "coal" 2 ] }
                    ]
                        |> Expect.equal
                            [ { seller = "Vimes", buyer = "Belkarama", coins = 0, items = [ line "coal" 2 ] }
                            , { seller = "Vimes", buyer = "Belkarama", coins = 500, items = [ line "coal" 2 ] }
                            ]
            , test "describes an item trade line by line" <|
                \_ ->
                    [ Market.describeTrade selling { accepted | items = [ line "coal" 2, { itemId = "iron_bar", variant = { fine = True, rare = False, quality = Nothing }, quantity = 1 } ] }
                    , Market.describeTrade selling { accepted | price = Just 100, items = [ line "coal" 2 ] }
                    ]
                        |> Expect.equal
                            [ "Vimes sells 5x fine Salty hops to Belkarama for 2x Coal and 1x fine Iron bar"
                            , "Vimes sells 5x fine Salty hops to Belkarama for 500 coins and 2x Coal"
                            ]
            ]
        , describe "Market.pricePoints"
            [ test "only coins feed estimates: item offers and item trades don't, nor do listings with no coin price" <|
                \_ ->
                    let
                        itemTrade =
                            { accepted | items = [ line "coal" 2 ], status = OfferCompleted (Time.millisToPosix (3 * day)) }

                        coinOffer_ =
                            { openOffer | id = 4, price = Just 7000 }
                    in
                    [ Market.pricePoints now (Dict.singleton 1 { selling | payment = CoinsOrItems (Just 8000) }) (Dict.fromList [ ( 2, itemTrade ), ( 4, coinOffer_ ) ]) "salty_hops/fine"
                    , Market.pricePoints now (Dict.singleton 1 { selling | payment = CoinsOrItems Nothing }) (Dict.fromList [ ( 2, itemTrade ), ( 4, coinOffer_ ) ]) "salty_hops/fine"
                    , Market.pricePoints now (Dict.singleton 1 itemsOnly) (Dict.singleton 2 itemTrade) "salty_hops/fine"
                    ]
                        |> List.map (List.map (\p -> ( p.source, p.price )))
                        |> Expect.equal [ [ ( Ask, 8000 ), ( Offer, 7000 ) ], [ ( Offer, 7000 ) ], [] ]
            , test "a completed trade is a Trade point at its price, dated when it went through, even on a closed listing" <|
                \_ ->
                    let
                        sold =
                            { accepted | price = Just 7500, status = OfferCompleted (Time.millisToPosix (3 * day)) }
                    in
                    Market.pricePoints now (Dict.singleton 1 { selling | closed = True }) (Dict.singleton 2 sold) "salty_hops/fine"
                        |> List.filter (\p -> p.source == Trade)
                        |> List.map (\p -> ( p.price, Time.posixToMillis p.at ))
                        |> Expect.equal [ ( 7500, 3 * day ) ]
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
    , wants = []
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
    , items = []
    , message = ""
    , at = Time.millisToPosix 0
    , status = OfferAccepted
    , listerConfirmed = False
    , offererConfirmed = False
    }


accepted : Types.Offer
accepted =
    offer Nothing


selling : Types.Listing
selling =
    listing Selling


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
    , paymentChoice = Types.PayCoins
    , price = ""
    , wants = []
    , wantQuery = ""
    , note = ""
    , error = Nothing
    , submitting = False
    }


itemsOnly : Types.Listing
itemsOnly =
    { selling | payment = ItemsOnly }


either : Types.Listing
either =
    { selling | payment = CoinsOrItems Nothing }


coinOffer : Types.OfferDraft
coinOffer =
    { price = Nothing, items = [], message = "" }


line : String -> Int -> Types.ItemLine
line itemId quantity =
    { itemId = itemId, variant = Item.plain, quantity = quantity }


draft : Types.ListingDraft
draft =
    { itemId = "coal", variant = Item.plain, side = Selling, payment = Coins 10, wants = [], quantity = 1, note = "" }
