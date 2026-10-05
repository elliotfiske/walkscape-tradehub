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


{-| Sign in with a placeholder preview account and claim a WalkScape name.
-}
signInAndClaim : Actions -> String -> List Action
signInAndClaim actions name =
    [ actions.clickLink 100 "/signin"
    , actions.click 100 (Dom.id "signin-preview")
    , actions.input 300 (Dom.id "claim-name") name
    , actions.click 100 (Dom.id "claim-submit")
    ]


{-| The whole onboarding: sign in, claim a name.
-}
onboard : Actions -> String -> List Action
onboard actions name =
    signInAndClaim actions name
        ++ [ actions.checkView 300 (byTestId "done-heading" >> seesText (name ++ " is linked"))
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


{-| Sign in with a development-only preview admin account and open the admin
screen. Admins don't need a WalkScape name.
-}
signInAsAdmin : Actions -> List Action
signInAsAdmin actions =
    [ actions.clickLink 100 "/signin"
    , actions.click 100 (Dom.id "signin-preview-admin")
    , actions.clickLink 300 "/"
    , actions.clickLink 100 "/admin"
    , actions.checkView 300 (hasTestId "admin-stats")
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
    , start "Signing up: preview sign-in, claim a name, finish"
        [ connect "s1" "/" <|
            \user ->
                [ user.clickLink 100 "/signin"
                , user.click 100 (Dom.id "signin-preview")
                , user.checkView 300 (byTestId "signed-in-with" >> seesText "Signed in with a preview account")
                , user.input 100 (Dom.id "claim-name") "Wanderling"
                , user.click 100 (Dom.id "claim-submit")
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
                                       , second.checkView 300 (byTestId "done-heading" >> seesText "Juno_Trek is linked")
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
    , start "Rare pet eggs are listed and priced separately from common ones"
        [ connect "seller" "/" <|
            \seller ->
                onboard seller "Juno_Trek"
                    ++ postListing seller { item = "camel_egg", price = "100", quantity = "1" }
                    ++ [ seller.clickLink 100 "/market"
                       , seller.clickLink 100 "/new"
                       , seller.input 100 (Dom.id "item-search") "camel egg"
                       , seller.click 100 (Dom.id "item-pick-camel_egg")
                       , seller.checkView 100 (Query.hasNot [ Selector.id "variant-fine" ])
                       , seller.click 100 (Dom.id "variant-rare")
                       , seller.checkView 100 (byTestId "picked-item" >> seesText "Rare")
                       , seller.input 100 (Dom.id "price") "5000"
                       , seller.click 100 (Dom.id "post-listing")
                       , seller.checkView 300 (byTestId "listing-status" >> seesText "WAITING TO GO LIVE")
                       , connect "buyer" "/" <|
                            \buyer ->
                                [ buyer.clickLink (minutes 16) "/market"
                                , buyer.checkView 100 (byTestId "listing-2" >> seesText "Rare")
                                , buyer.clickLink 100 "/prices"
                                , buyer.checkView 100 (byTestId "price-row-camel_egg" >> seesText "100")
                                , buyer.checkView 100 (byTestId "price-row-camel_egg/rare" >> seesText "5,000")
                                , buyer.clickLink 100 "/prices/camel_egg?rare=1"
                                , buyer.checkView 100 (byTestId "price-stats" >> seesText "5,000")
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
    , start "A report link opened directly knows who it's about"
        [ connect "other" "/" <|
            \other ->
                onboard other "Hollowfen"
                    ++ [ connect "victim" "/" <|
                            \victim ->
                                onboard victim "Wanderling"
                                    ++ [ connect "victim" "/report/Hollowfen" <|
                                            \tab ->
                                                [ tab.click 300 (Dom.id "reason-0")
                                                , tab.click 100 (Dom.id "send-report")
                                                , tab.checkView 300 (byTestId "report-sent" >> seesText "Report sent")
                                                ]
                                       ]
                       ]
        ]
    , start "An admin resolves a report and bans the player, which takes down their listings"
        [ connect "seller" "/" <|
            \seller ->
                onboard seller "Hollowfen"
                    ++ postListing seller { item = "copper_ore", price = "5", quantity = "100" }
                    ++ [ connect "buyer" "/" <|
                            \buyer ->
                                onboard buyer "Wanderling"
                                    ++ [ buyer.clickLink (minutes 16) "/market"
                                       , buyer.clickLink 100 "/listing/1"
                                       , buyer.click 100 (Dom.id "send-offer")
                                       , buyer.checkView 300 (hasTestId "offer-2")
                                       , buyer.clickLink 100 "/report/Hollowfen"
                                       , buyer.click 100 (Dom.id "reason-4")
                                       , buyer.click 100 (Dom.id "send-report")
                                       , buyer.checkView 300 (hasTestId "report-sent")
                                       , connect "mod" "/" <|
                                            \mod ->
                                                signInAsAdmin mod
                                                    ++ [ mod.checkView 100 (byTestId "admin-report-3" >> seesText "Price manipulation")
                                                       , mod.click 100 (Dom.id "admin-resolve-3")
                                                       , mod.checkView 300 (byTestId "admin-report-3" >> seesText "Reopen")
                                                       , mod.click 100 (Dom.id "admin-report-ban-3")
                                                       , mod.click 100 (Dom.id "admin-confirm")
                                                       , mod.checkView 100 (hasTestId "admin-confirm-box")
                                                       , mod.input 100 (Dom.id "ban-reason") "Fake prices"
                                                       , mod.click 100 (Dom.id "admin-confirm")
                                                       , seller.checkView 300 (byTestId "ban-notice" >> seesText "Fake prices")
                                                       , buyer.clickLink 100 "/u/Hollowfen"
                                                       , buyer.checkView 100 (hasTestId "banned-tag")
                                                       , buyer.checkView 100 (lacksTestId "report-player")
                                                       , buyer.clickLink 100 "/market"
                                                       , buyer.checkView 100 (lacksTestId "listing-1")
                                                       , buyer.checkModel 100
                                                            (\model ->
                                                                if Dict.isEmpty model.offers then
                                                                    Ok ()

                                                                else
                                                                    Err "the buyer's offer on the deleted listing should be gone"
                                                            )
                                                       , Effect.Test.checkBackend 100
                                                            (\backend ->
                                                                if Dict.isEmpty backend.listings && Dict.isEmpty backend.offers then
                                                                    Ok ()

                                                                else
                                                                    Err "the banned player's listing and its offer should be gone"
                                                            )
                                                       , seller.clickLink 100 "/market"
                                                       , seller.clickLink 100 "/new"
                                                       , seller.input 100 (Dom.id "item-search") "copper ore"
                                                       , seller.click 100 (Dom.id "item-pick-copper_ore")
                                                       , seller.input 100 (Dom.id "price") "5"
                                                       , seller.click 100 (Dom.id "post-listing")
                                                       , seller.checkView 300 (byTestId "toast" >> seesText "Your account is banned.")
                                                       , mod.click 100 (Dom.id "admin-tab-log")
                                                       , mod.checkView 100 (seesText "Banned Hollowfen: Fake prices")
                                                       , mod.click 100 (Dom.id "admin-tab-players")
                                                       , mod.click 100 (Dom.id "admin-unban-Hollowfen")
                                                       , seller.checkView 300 (lacksTestId "ban-notice")
                                                       ]
                                       ]
                       ]
        ]
    , start "An admin deletes an offer, a listing that isn't live yet, and releases a name"
        [ connect "seller" "/" <|
            \seller ->
                onboard seller "Juno_Trek"
                    ++ postListing seller { item = "shovel_axe", price = "9000", quantity = "1" }
                    ++ [ connect "buyer" "/" <|
                            \buyer ->
                                onboard buyer "Pikewalker"
                                    ++ [ buyer.clickLink (minutes 16) "/market"
                                       , buyer.clickLink 100 "/listing/1"
                                       , buyer.click 100 (Dom.id "send-offer")
                                       ]
                                    ++ postListing seller { item = "iron_bar", price = "100", quantity = "10" }
                                    ++ [ connect "mod" "/" <|
                                            \mod ->
                                                signInAsAdmin mod
                                                    ++ [ mod.click 100 (Dom.id "admin-tab-listings")
                                                       , mod.checkView 100 (byTestId "admin-listing-3" >> seesText "Waiting to go live")
                                                       , mod.click 100 (Dom.id "admin-delete-offer-2")
                                                       , mod.click 100 (Dom.id "admin-confirm")
                                                       , mod.checkView 300 (lacksTestId "admin-offer-2")
                                                       , buyer.checkView 100 (lacksTestId "offer-2")
                                                       , mod.click 100 (Dom.id "admin-delete-listing-3")
                                                       , mod.click 100 (Dom.id "admin-cancel")
                                                       , mod.checkView 100 (hasTestId "admin-listing-3")
                                                       , mod.click 100 (Dom.id "admin-delete-listing-3")
                                                       , mod.click 100 (Dom.id "admin-confirm")
                                                       , mod.checkView 300 (lacksTestId "admin-listing-3")
                                                       , seller.checkView 100 (seesText "This listing doesn't exist")
                                                       , mod.click 100 (Dom.id "admin-tab-players")
                                                       , mod.click 100 (Dom.id "admin-release-Pikewalker")
                                                       , mod.click 100 (Dom.id "admin-confirm")
                                                       , mod.checkView 300 (lacksTestId "admin-player-Pikewalker")
                                                       , buyer.checkView 100 (byTestId "user-chip" >> seesText "Finish sign-up")
                                                       , Effect.Test.checkBackend 100
                                                            (\backend ->
                                                                if List.any (\u -> Maybe.map .name u.claim == Just "Pikewalker") (Dict.values backend.users) then
                                                                    Err "Pikewalker should be free to claim again"

                                                                else
                                                                    Ok ()
                                                            )
                                                       ]
                                       ]
                       ]
        ]
    , start "Only admins can open the admin screen"
        [ connect "s1" "/" <|
            \user ->
                onboard user "Ferncastle"
                    ++ [ user.clickLink 100 "/market"
                       , user.checkView 100 (Query.hasNot [ Selector.attribute (Html.Attributes.href "/admin") ])
                       ]
        , connect "s3" "/admin" <|
            \guest ->
                [ guest.checkView 300 (byTestId "admin-only" >> seesText "only for admins")
                , guest.checkModel 100
                    (\model ->
                        if model.admin == Nothing then
                            Ok ()

                        else
                            Err "a guest shouldn't get admin data"
                    )
                ]
        ]
    , start "A trader can have at most 20 active listings at once"
        [ connect "seller" "/" <|
            \seller ->
                onboard seller "Juno_Trek"
                    ++ List.concatMap (\_ -> postListing seller { item = "coal", price = "10", quantity = "1" }) (List.range 1 20)
                    ++ [ seller.clickLink 100 "/market"
                       , seller.clickLink 100 "/new"
                       , seller.checkView 100 (seesText "20 of 20 active")
                       , seller.input 100 (Dom.id "item-search") "coal"
                       , seller.click 100 (Dom.id "item-pick-coal")
                       , seller.input 100 (Dom.id "quantity") "1"
                       , seller.input 100 (Dom.id "price") "10"
                       , seller.click 100 (Dom.id "post-listing")
                       , seller.checkView 300 (byTestId "toast" >> seesText "You can have up to 20 active listings")
                       , Effect.Test.checkBackend 100
                            (\backend ->
                                if Dict.size backend.listings == 20 then
                                    Ok ()

                                else
                                    Err ("expected 20 listings, got " ++ String.fromInt (Dict.size backend.listings))
                            )
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
    , start "The \"no timers\" notice stays dismissed across sign-ins"
        [ connect "d1" "/" <|
            \user ->
                onboard user "Pikewalker"
                    ++ [ user.clickLink 100 "/market"
                       , user.checkView 100 (hasTestId "timers-notice")
                       , user.click 100 (Dom.id "dismiss-notice")
                       , user.checkView 300 (lacksTestId "timers-notice")
                       , user.clickLink 100 "/u/Pikewalker"
                       , user.click 100 (Dom.id "sign-out")
                       , user.clickLink 100 "/signin"
                       , user.click 100 (Dom.id "signin-preview")
                       , user.clickLink 300 "/market"
                       , user.checkView 300 (lacksTestId "timers-notice")
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
