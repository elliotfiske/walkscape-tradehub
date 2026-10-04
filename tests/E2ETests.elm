module E2ETests exposing (appTests, main)

import Backend
import Derived
import Dict
import Effect.Browser.Dom as Dom
import Effect.Lamdera
import Effect.Test exposing (HttpResponse(..))
import Effect.Time
import Expect
import Frontend
import Html.Attributes
import Test exposing (describe)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Types exposing (BackendModel, BackendMsg, FrontendModel, FrontendMsg, OfferStatus(..), ToBackend, ToFrontend)
import Url exposing (Url)


type alias Actions =
    Effect.Test.FrontendActions ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel


type alias Action =
    Effect.Test.Action ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel


type alias EndToEndTest =
    Effect.Test.EndToEndTest ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel


main : Program () (Effect.Test.Model ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel) (Effect.Test.Msg ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel)
main =
    Effect.Test.viewer tests


startTime : Effect.Time.Posix
startTime =
    Effect.Time.millisToPosix 1790000000000


minutes : Float -> Effect.Test.DelayInMs
minutes n =
    n * 60 * 1000


desktop : { width : Int, height : Int }
desktop =
    { width = 1280, height = 900 }


connect : String -> String -> (Actions -> List Action) -> Action
connect session path =
    Effect.Test.connectFrontend 100 (Effect.Lamdera.sessionIdFromString session) path desktop


start : String -> List Action -> EndToEndTest
start name =
    Effect.Test.start name startTime config


byTestId : String -> Query.Single msg -> Query.Single msg
byTestId testId =
    Query.find [ Selector.attribute (Html.Attributes.attribute "data-testid" testId) ]


seesText : String -> Query.Single msg -> Expect.Expectation
seesText text =
    Query.has [ Selector.text text ]


hasTestId : String -> Query.Single msg -> Expect.Expectation
hasTestId testId =
    Query.has [ Selector.attribute (Html.Attributes.attribute "data-testid" testId) ]


lacksTestId : String -> Query.Single msg -> Expect.Expectation
lacksTestId testId =
    Query.hasNot [ Selector.attribute (Html.Attributes.attribute "data-testid" testId) ]


{-| Sign in with a placeholder preview account and claim a WalkScape name,
stopping at the verification step.
-}
signInAndClaim : Actions -> String -> List Action
signInAndClaim actions name =
    [ actions.clickLink 100 "/signin"
    , actions.click 100 (Dom.id "signin-preview")
    , actions.input 300 (Dom.id "claim-name") name
    , actions.click 100 (Dom.id "claim-submit")
    ]


{-| The whole onboarding: sign in, claim a name, skip the (not yet live) verification.
-}
onboard : Actions -> String -> List Action
onboard actions name =
    signInAndClaim actions name
        ++ [ actions.click 300 (Dom.id "skip-verify")
           , actions.checkView 300 (byTestId "done-heading" >> seesText (name ++ " is linked"))
           ]


{-| Post a coin listing for a loot item. Assumes the user is onboarded.
-}
postListing : Actions -> { item : String, price : String, quantity : String } -> List Action
postListing actions { item, price, quantity } =
    [ actions.clickLink 100 "/market"
    , actions.clickLink 100 "/new"
    , actions.input 100 (Dom.id "item-search") (String.replace "_" " " item)
    , actions.click 100 (Dom.id ("item-pick-" ++ item))
    , actions.input 100 (Dom.id "quantity") quantity
    , actions.input 100 (Dom.id "price") price
    , actions.click 100 (Dom.id "post-listing")
    , actions.checkView 300 (byTestId "listing-status" >> seesText "WAITING TO GO LIVE")
    ]


tests : List EndToEndTest
tests =
    [ start "A guest can browse the homepage and an empty market"
        [ connect "guest" "/" <|
            \guest ->
                [ guest.checkView 100 (byTestId "preview-banner" >> seesText "Trading isn't live in WalkScape yet")
                , guest.checkView 100 (byTestId "featured-price" >> seesText "No prices yet")
                , guest.clickLink 100 "/market"
                , guest.checkView 100 (byTestId "guest-notice" >> seesText "You're browsing as a guest.")
                , guest.checkView 100 (byTestId "empty-market" >> seesText "No listings yet")
                ]
        ]
    , start "Signing up: preview sign-in, claim a name, see where verification would go, finish"
        [ connect "s1" "/" <|
            \user ->
                [ user.clickLink 100 "/signin"
                , user.click 100 (Dom.id "signin-preview")
                , user.checkView 300 (byTestId "signed-in-with" >> seesText "Signed in with a preview account")
                , user.input 100 (Dom.id "claim-name") "Wanderling"
                , user.click 100 (Dom.id "claim-submit")
                , user.checkView 300 (byTestId "claimed-name" >> seesText "Wanderling")
                , user.checkView 100 (seesText "This is where you'd verify your account.")
                , user.checkView 100 (hasTestId "coin-amount")
                , user.click 100 (Dom.id "skip-verify")
                , user.checkView 300 (byTestId "done-heading" >> seesText "Wanderling is linked")
                , user.clickLink 100 "/market"
                , user.checkView 100 (byTestId "user-chip" >> seesText "Wanderling")
                , Effect.Test.checkBackend 100
                    (\backend ->
                        case Dict.values backend.users |> List.filterMap .claim of
                            [ claim ] ->
                                if claim.name == "Wanderling" && claim.status == Types.PreviewUnverified then
                                    Ok ()

                                else
                                    Err "claim should be Wanderling, unverified"

                            _ ->
                                Err "expected exactly one claim"
                    )
                ]
        ]
    , start "Claiming a name that's invalid or already taken shows an error"
        [ connect "s1" "/" <|
            \first ->
                onboard first "Mossbeard"
                    ++ [ connect "s2" "/" <|
                            \second ->
                                signInAndClaim second "Moss beard"
                                    ++ [ second.checkView 300 (byTestId "claim-error" >> seesText "Names can only use letters")
                                       , second.input 100 (Dom.id "claim-name") "mossbeard"
                                       , second.click 100 (Dom.id "claim-submit")
                                       , second.checkView 300 (byTestId "claim-error" >> seesText "already claimed")
                                       , second.input 100 (Dom.id "claim-name") "Juno_Trek"
                                       , second.click 100 (Dom.id "claim-submit")
                                       , second.checkView 300 (byTestId "claimed-name" >> seesText "Juno_Trek")
                                       ]
                       ]
        ]
    , start "A new listing waits 15 minutes before other people can see it"
        [ connect "seller" "/" <|
            \seller ->
                onboard seller "Tallowmere"
                    ++ postListing seller { item = "steel_toe_boots", price = "1,150", quantity = "2" }
                    ++ [ seller.checkView 100 (byTestId "listing-title" >> seesText "Selling 2x Steel-toe boots")
                       , seller.checkView 100 (hasTestId "pending-note")
                       , connect "buyer" "/market" <|
                            \buyer ->
                                [ buyer.checkView 300 (hasTestId "empty-market")
                                , buyer.checkView (minutes 10) (lacksTestId "listing-1")
                                , buyer.checkView (minutes 6) (byTestId "listing-1" >> seesText "Steel-toe boots")
                                , buyer.checkView 100 (byTestId "listing-1" >> seesText "Tallowmere")
                                , seller.checkView 100 (byTestId "listing-status" >> seesText "LIVE")
                                ]
                       ]
        ]
    , start "Making an offer, getting a badge, and accepting it"
        [ connect "seller" "/" <|
            \seller ->
                onboard seller "Juno_Trek"
                    ++ postListing seller { item = "shovel_axe", price = "9800", quantity = "1" }
                    ++ [ connect "buyer" "/" <|
                            \buyer ->
                                onboard buyer "Wanderling"
                                    ++ [ buyer.clickLink (minutes 16) "/market"
                                       , buyer.clickLink 100 "/listing/1"
                                       , buyer.checkView 100 (byTestId "no-offers" >> seesText "No offers yet.")
                                       , buyer.checkView 100 (byTestId "fair-value" >> seesText "Right at the estimate")
                                       , buyer.click 100 (Dom.id "offer-counter")
                                       , buyer.input 100 (Dom.id "offer-price") "nine thousand"
                                       , buyer.click 100 (Dom.id "send-offer")
                                       , buyer.checkView 100 (byTestId "offer-error" >> seesText "Enter a price in coins")
                                       , buyer.input 100 (Dom.id "offer-price") "9.4k"
                                       , buyer.checkView 100 (byTestId "offer-check" >> seesText "4% below the preview estimate of 9,800")
                                       , buyer.input 100 (Dom.id "offer-message") "Can pick up at the Kallaheim mailbox"
                                       , buyer.click 100 (Dom.id "send-offer")
                                       , buyer.checkView 300 (byTestId "offer-2" >> seesText "9,400")
                                       , buyer.checkView 100 (seesText "Update your offer")
                                       , buyer.checkView 100
                                            (Query.find [ Selector.id "offer-price" ]
                                                >> Query.has [ Selector.attribute (Html.Attributes.value "9400") ]
                                            )
                                       , seller.checkView 100 (byTestId "offer-2" >> seesText "Can pick up at the Kallaheim mailbox")
                                       , seller.checkModel 100
                                            (\model ->
                                                if Derived.pendingResponses model == 1 then
                                                    Ok ()

                                                else
                                                    Err "seller should have one offer to respond to"
                                            )
                                       , seller.clickLink 100 "/trades"
                                       , seller.checkView 100 (byTestId "trade-offer-2" >> seesText "Your turn: accept or decline this offer")
                                       , seller.clickLink 100 "/listing/1"
                                       , seller.click 100 (Dom.id "accept-2")
                                       , buyer.checkView 300 (byTestId "offer-2" >> seesText "When trading goes live, this opens a trade room")
                                       , buyer.clickLink 100 "/trades"
                                       , buyer.click 100 (Dom.id "trades-sent")
                                       , buyer.checkView 100 (byTestId "trade-offer-2" >> seesText "Accepted")
                                       , Effect.Test.checkBackend 100
                                            (\backend ->
                                                if Dict.get 2 backend.offers |> Maybe.map (\o -> o.status == OfferAccepted && o.price == Just 9400) |> Maybe.withDefault False then
                                                    Ok ()

                                                else
                                                    Err "offer 2 should be accepted at 9400"
                                            )
                                       ]
                       ]
        ]
    , start "Offers feed the price estimate on the item page"
        [ connect "seller" "/" <|
            \seller ->
                onboard seller "Juno_Trek"
                    ++ postListing seller { item = "shovel_axe", price = "9000", quantity = "1" }
                    ++ [ connect "b1" "/" <|
                            \b1 ->
                                onboard b1 "Pikewalker"
                                    ++ [ b1.clickLink (minutes 16) "/market"
                                       , b1.clickLink 100 "/listing/1"
                                       , b1.click 100 (Dom.id "offer-counter")
                                       , b1.input 100 (Dom.id "offer-price") "8800"
                                       , b1.click 100 (Dom.id "send-offer")
                                       , connect "b2" "/" <|
                                            \b2 ->
                                                onboard b2 "Hollowfen"
                                                    ++ [ b2.clickLink 100 "/market"
                                                       , b2.clickLink 100 "/listing/1"
                                                       , b2.click 100 (Dom.id "send-offer")
                                                       , b2.clickLink 300 "/prices/shovel_axe"
                                                       , b2.checkView 100 (byTestId "price-stats" >> seesText "9,000")
                                                       , b2.checkView 100 (byTestId "price-stats" >> seesText "from 3 unique traders")
                                                       , b2.checkView 100 (byTestId "price-points" >> seesText "Hollowfen")
                                                       , b2.clickLink 100 "/prices"
                                                       , b2.checkView 100 (byTestId "price-row-shovel_axe" >> seesText "9,000")
                                                       ]
                                       ]
                       ]
        ]
    , start "Fine items are listed, filtered and priced separately from regular ones"
        [ connect "seller" "/" <|
            \seller ->
                onboard seller "Juno_Trek"
                    ++ postListing seller { item = "iron_bar", price = "100", quantity = "10" }
                    ++ [ seller.clickLink 100 "/market"
                       , seller.clickLink 100 "/new"

                       -- Searching "fine …" picks the fine version.
                       , seller.input 100 (Dom.id "item-search") "fine iron bar"
                       , seller.click 100 (Dom.id "item-pick-iron_bar")
                       , seller.checkView 100 (byTestId "picked-item" >> seesText "Iron bar")
                       , seller.checkView 100 (byTestId "picked-item" >> seesText "Fine")
                       , seller.input 100 (Dom.id "quantity") "2"
                       , seller.input 100 (Dom.id "price") "400"
                       , seller.click 100 (Dom.id "post-listing")
                       , seller.checkView 300 (byTestId "listing-status" >> seesText "WAITING TO GO LIVE")
                       , connect "buyer" "/" <|
                            \buyer ->
                                [ buyer.clickLink (minutes 16) "/market"
                                , buyer.checkView 100 (byTestId "listing-1" >> seesText "Iron bar")
                                , buyer.checkView 100 (byTestId "listing-2" >> seesText "Iron bar")
                                , buyer.checkView 100 (byTestId "listing-2" >> seesText "Fine")
                                , buyer.click 100 (Dom.id "fine-only")
                                , buyer.checkView 100 (lacksTestId "listing-1")
                                , buyer.checkView 100 (hasTestId "listing-2")
                                , buyer.clickLink 100 "/prices"
                                , buyer.checkView 100 (byTestId "price-row-iron_bar" >> seesText "100")
                                , buyer.checkView 100 (byTestId "price-row-iron_bar/fine" >> seesText "400")
                                , buyer.clickLink 100 "/prices/iron_bar?fine=1"
                                , buyer.checkView 100 (byTestId "item-name" >> seesText "Iron bar")
                                , buyer.checkView 100 (byTestId "price-stats" >> seesText "400")
                                , buyer.clickLink 100 "/prices/iron_bar"
                                , buyer.checkView 100 (byTestId "price-stats" >> seesText "100")
                                ]
                       ]
        ]
    , start "Look-alike names are flagged on their listings"
        [ connect "real" "/" <|
            \real ->
                onboard real "Mossbeard"
                    ++ [ connect "fake" "/" <|
                            \fake ->
                                onboard fake "Mosbeard_"
                                    ++ postListing fake { item = "copper_ore", price = "5", quantity = "100" }
                                    ++ [ real.clickLink (minutes 16) "/market"
                                       , real.checkView 100 (byTestId "listing-1" >> byTestId "lookalike-warning" >> seesText "very close to Mossbeard")
                                       , real.clickLink 100 "/listing/1"
                                       , real.clickLink 100 "/u/Mosbeard_"
                                       , real.checkView 100 (byTestId "profile-name" >> seesText "Mosbeard_")
                                       , real.checkView 100 (seesText "This name is very close to Mossbeard")
                                       ]
                       ]
        ]
    , start "Posting a listing needs a price, and guests are sent to sign in"
        [ connect "s1" "/new" <|
            \user ->
                [ user.checkView 100 (seesText "Link your WalkScape name first.")
                , user.clickLink 100 "/"
                ]
                    ++ onboard user "Ferncastle"
                    ++ [ user.clickLink 100 "/market"
                       , user.clickLink 100 "/new"
                       , user.click 100 (Dom.id "post-listing")
                       , user.checkView 100 (byTestId "listing-error" >> seesText "Pick an item first.")
                       , user.input 100 (Dom.id "item-search") "iron pick"
                       , user.click 100 (Dom.id "item-pick-iron_pickaxe")
                       , user.click 100 (Dom.id "pick-quality-eternal")
                       , user.click 100 (Dom.id "post-listing")
                       , user.checkView 100 (byTestId "listing-error" >> seesText "Enter a price in coins")
                       , user.input 100 (Dom.id "price") "48000"
                       , user.click 100 (Dom.id "post-listing")
                       , user.checkView 300 (byTestId "listing-title" >> seesText "Selling 1x Iron pickaxe")
                       , user.checkView 100 (seesText "Eternal")
                       ]
        ]
    , start "Reporting a player"
        [ connect "victim" "/" <|
            \victim ->
                onboard victim "Wanderling"
                    ++ [ connect "other" "/" <|
                            \other ->
                                onboard other "Hollowfen"
                                    ++ postListing other { item = "cooked_largemouth_bass", price = "38", quantity = "50" }
                                    ++ [ victim.clickLink (minutes 16) "/market"
                                       , victim.clickLink 100 "/listing/1"
                                       , victim.clickLink 100 "/report/Hollowfen"
                                       , victim.click 100 (Dom.id "reason-0")
                                       , victim.click 100 (Dom.id "reason-2")
                                       , victim.input 100 (Dom.id "report-details") "Swapped raw bass in the trade window."
                                       , victim.click 100 (Dom.id "send-report")
                                       , victim.checkView 300 (byTestId "report-sent" >> seesText "Report sent")
                                       , Effect.Test.checkBackend 100
                                            (\backend ->
                                                case backend.reports of
                                                    [ report ] ->
                                                        if report.about == "Hollowfen" && report.reporter == "Wanderling" && report.reasons == [ "Item or quality swapped", "Fake deadline / pressure" ] then
                                                            Ok ()

                                                        else
                                                            Err "report contents are wrong"

                                                    _ ->
                                                        Err "expected one report"
                                            )
                                       ]
                       ]
        ]
    , start "A trader can have at most 20 open offers at once"
        [ connect "s1" "/" <|
            \s1 ->
                onboard s1 "Juno_Trek"
                    ++ List.concatMap (\_ -> postListing s1 { item = "coal", price = "10", quantity = "1" }) (List.range 1 7)
                    ++ [ connect "s2" "/" <|
                            \s2 ->
                                onboard s2 "Mossbeard"
                                    ++ List.concatMap (\_ -> postListing s2 { item = "coal", price = "10", quantity = "1" }) (List.range 1 7)
                                    ++ [ connect "s3" "/" <|
                                            \s3 ->
                                                onboard s3 "Tallowmere"
                                                    ++ List.concatMap (\_ -> postListing s3 { item = "coal", price = "10", quantity = "1" }) (List.range 1 7)
                                                    ++ [ connect "buyer" "/" <|
                                                            \buyer ->
                                                                onboard buyer "Wanderling"
                                                                    ++ [ buyer.clickLink (minutes 16) "/market" ]
                                                                    ++ List.concatMap
                                                                        (\id ->
                                                                            [ buyer.clickLink 100 "/market"
                                                                            , buyer.clickLink 100 ("/listing/" ++ String.fromInt id)
                                                                            , buyer.click 100 (Dom.id "send-offer")
                                                                            ]
                                                                        )
                                                                        (List.range 1 20)
                                                                    ++ [ buyer.checkView 300 (byTestId "open-offer-count" >> seesText "20 of 20 open offers")
                                                                       , buyer.clickLink 100 "/market"
                                                                       , buyer.clickLink 100 "/listing/21"
                                                                       , buyer.click 100 (Dom.id "send-offer")
                                                                       , buyer.checkView 300 (byTestId "offer-error" >> seesText "You can have up to 20 open offers")
                                                                       , Effect.Test.checkBackend 100
                                                                            (\backend ->
                                                                                if Dict.size backend.offers == 20 then
                                                                                    Ok ()

                                                                                else
                                                                                    Err ("expected 20 offers, got " ++ String.fromInt (Dict.size backend.offers))
                                                                            )
                                                                       ]
                                                       ]
                                       ]
                       ]
        ]
    , start "Signing out returns to the guest view and keeps the account"
        [ connect "s1" "/" <|
            \user ->
                onboard user "Pikewalker"
                    ++ [ user.clickLink 100 "/market"
                       , user.clickLink 100 "/u/Pikewalker"
                       , user.click 100 (Dom.id "sign-out")
                       , user.checkView 300 (hasTestId "featured-price")
                       , user.checkView 100 (lacksTestId "user-chip")
                       , user.clickLink 100 "/signin"
                       , user.click 100 (Dom.id "signin-preview")
                       , user.checkView 300 (byTestId "done-heading" >> seesText "Pikewalker is linked")
                       ]
        ]
    ]


appTests : Test.Test
appTests =
    describe "User journeys" (List.map Effect.Test.toTest tests)


safeUrl : Url
safeUrl =
    { protocol = Url.Https
    , host = "trailpost.lamdera.app"
    , port_ = Nothing
    , path = "/"
    , query = Nothing
    , fragment = Nothing
    }


config : Effect.Test.Config ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel
config =
    { frontendApp = Frontend.app_
    , backendApp = Backend.app_
    , handleHttpRequest = always NetworkErrorResponse
    , handlePortToJs = always Nothing
    , handleFileUpload = always Effect.Test.UnhandledFileUpload
    , handleMultipleFilesUpload = always Effect.Test.UnhandledMultiFileUpload
    , domain = safeUrl
    }
