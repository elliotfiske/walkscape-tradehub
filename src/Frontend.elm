module Frontend exposing (app, app_)

import AuthProviders
import Auth.Common
import Auth.Flow
import Browser
import Derived
import Dict
import Duration
import Effect.Browser
import Effect.Browser.Navigation
import Effect.Command as Command exposing (Command, FrontendOnly)
import Effect.Lamdera
import Effect.Task
import Effect.Time
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Item
import Lamdera as L
import Market
import OAuth.AuthorizationCode as OAuth
import Page.Admin
import Page.Home
import Page.Listing
import Page.Market
import Page.NewListing
import Page.Prices
import Page.Profile
import Page.Report
import Page.SignIn
import Page.Trades
import Route exposing (Route)
import Time
import Types
    exposing
        ( AdminAction(..)
        , AdminTab(..)
        , FrontendModel
        , FrontendMsg(..)
        , ListingForm
        , MarketSort(..)
        , MarketTab(..)
        , OfferForm
        , ReportForm
        , Side(..)
        , ToBackend(..)
        , ToFrontend(..)
        , TradesTab(..)
        )
import Ui
import Url exposing (Url)


type alias Model =
    FrontendModel


type alias Cmd_ =
    Command FrontendOnly ToBackend FrontendMsg


app =
    Effect.Lamdera.frontend
        L.sendToBackend
        app_


app_ =
    { init = init
    , onUrlRequest = UrlClicked
    , onUrlChange = UrlChanged
    , update = update
    , updateFromBackend = updateFromBackend
    , subscriptions = \_ -> Effect.Time.every (Duration.seconds 10) Tick
    , view = view
    }


emptyListingForm : ListingForm
emptyListingForm =
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


{-| `/new?item=dolphin_egg&rare=1` (the "Post a listing" button on a price
page) starts the form on that item and variant. Unknown items are ignored.
-}
prefillListingForm : Route -> ListingForm -> ListingForm
prefillListingForm route form =
    case route of
        Route.NewListing (Just ( itemId, variant )) ->
            case Item.byId itemId of
                Just item ->
                    let
                        normalized =
                            Item.normalizeVariant item variant
                    in
                    { form
                        | itemId = Just item.id
                        , itemQuery = ""
                        , fine = normalized.fine
                        , rare = normalized.rare
                        , quality = normalized.quality |> Maybe.withDefault Item.Normal
                        , error = Nothing
                    }

                Nothing ->
                    form

        _ ->
            form


emptyOfferForm : OfferForm
emptyOfferForm =
    { counter = False, price = "", message = "", error = Nothing }


{-| Start the offer form from my open offer on this listing, so "Update offer"
doesn't silently turn a counter-offer back into "at their price".
-}
offerFormFor : Model -> Int -> OfferForm
offerFormFor model listingId =
    case Derived.myOpenOffer model listingId of
        Just offer ->
            { emptyOfferForm
                | counter = offer.price /= Nothing
                , price = offer.price |> Maybe.map String.fromInt |> Maybe.withDefault ""
                , message = offer.message
            }

        Nothing ->
            emptyOfferForm


emptyReportForm : ReportForm
emptyReportForm =
    { about = "", reasons = [], details = "", sent = False }


init : Url -> Effect.Browser.Navigation.Key -> ( Model, Cmd_ )
init url key =
    let
        baseUrl =
            { url | query = Nothing, fragment = Nothing, path = "/" }

        model =
            { key = key
            , route = Route.fromUrl url
            , now = Time.millisToPosix 0
            , authFlow = Auth.Common.Idle
            , authRedirectBaseUrl = baseUrl
            , me = Nothing
            , loaded = False
            , listings = Dict.empty
            , offers = Dict.empty
            , traders = Dict.empty
            , filters =
                { tab = AllListings
                , rarities = []
                , qualities = []
                , sort = Newest
                , fineOnly = False
                , hideOutliers = False
                , search = ""
                }
            , filtersOpen = False
            , claimName = ""
            , claimError = Nothing
            , listingForm = prefillListingForm (Route.fromUrl url) emptyListingForm
            , offerForm = emptyOfferForm
            , reportForm =
                case Route.fromUrl url of
                    Route.Report name ->
                        { emptyReportForm | about = name }

                    _ ->
                        emptyReportForm
            , previewSignInFor = Nothing
            , toast = Nothing
            , tradesTab = ReceivedTab
            , admin = Nothing
            , adminPage = { tab = AdminReports, search = "", confirming = Nothing, banReason = "" }
            }

        getTime =
            Effect.Time.now |> Effect.Task.perform Tick
    in
    case parseOAuthCallback url of
        Just callbackMethodId ->
            handleAuthCallback { model | route = Route.Onboarding } callbackMethodId url
                |> Tuple.mapSecond (\cmd -> Command.batch [ cmd, getTime ])

        Nothing ->
            ( model, getTime )


parseOAuthCallback : Url -> Maybe String
parseOAuthCallback url =
    case String.split "/" url.path |> List.filter (not << String.isEmpty) of
        [ "login", method, "callback" ] ->
            Just method

        _ ->
            Nothing


handleAuthCallback : Model -> String -> Url -> ( Model, Cmd_ )
handleAuthCallback model callbackMethodId url =
    let
        toWelcome =
            Effect.Browser.Navigation.replaceUrl model.key (Route.toString Route.Onboarding)
    in
    case OAuth.parseCode url of
        OAuth.Success { code, state } ->
            let
                stateStr =
                    state |> Maybe.withDefault ""

                -- The redirect_uri sent during /authorize is built by the
                -- library as `<base>/login/<method>/callback`. The token
                -- exchange needs the same URL — so send the actual callback
                -- URL (query/fragment stripped) here, NOT authRedirectBaseUrl.
                callbackUrl =
                    { url | query = Nothing, fragment = Nothing }
            in
            ( { model | authFlow = Auth.Common.Authorized code stateStr }
            , Command.batch
                [ Effect.Lamdera.sendToBackend (AuthToBackend (Auth.Common.AuthCallbackReceived callbackMethodId callbackUrl code stateStr))
                , toWelcome
                ]
            )

        OAuth.Empty ->
            ( { model | authFlow = Auth.Common.Idle }, Command.none )

        OAuth.Error err ->
            ( { model | authFlow = Auth.Common.Errored (Auth.Common.ErrAuthorization err), route = Route.SignIn }
            , Effect.Browser.Navigation.replaceUrl model.key (Route.toString Route.SignIn)
            )


isAuthorized : Auth.Common.Flow -> Bool
isAuthorized flow =
    case flow of
        Auth.Common.Authorized _ _ ->
            True

        _ ->
            False


navigate : Model -> Route -> Cmd_
navigate model route =
    Effect.Browser.Navigation.pushUrl model.key (Route.toString route)


updateFilters : (Types.MarketFilters -> Types.MarketFilters) -> Model -> ( Model, Cmd_ )
updateFilters f model =
    ( { model | filters = f model.filters }, Command.none )


updateListingForm : (ListingForm -> ListingForm) -> Model -> ( Model, Cmd_ )
updateListingForm f model =
    ( { model | listingForm = f model.listingForm }, Command.none )


updateOfferForm : (OfferForm -> OfferForm) -> Model -> ( Model, Cmd_ )
updateOfferForm f model =
    ( { model | offerForm = f model.offerForm }, Command.none )


updateAdminPage : (Types.AdminPage -> Types.AdminPage) -> Model -> ( Model, Cmd_ )
updateAdminPage f model =
    ( { model | adminPage = f model.adminPage }, Command.none )


loadAdmin : Model -> Cmd_
loadAdmin model =
    if Maybe.map .isAdmin model.me == Just True then
        Effect.Lamdera.sendToBackend AdminLoad

    else
        Command.none


toggle : a -> List a -> List a
toggle x list =
    if List.member x list then
        List.filter ((/=) x) list

    else
        x :: list


update : FrontendMsg -> Model -> ( Model, Cmd_ )
update msg model =
    case msg of
        UrlClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model
                    , Effect.Browser.Navigation.pushUrl model.key
                        (url.path ++ (url.query |> Maybe.map ((++) "?") |> Maybe.withDefault ""))
                    )

                Browser.External url ->
                    ( model, Effect.Browser.Navigation.load url )

        UrlChanged url ->
            let
                route =
                    Route.fromUrl url

                reportForm =
                    case route of
                        Route.Report name ->
                            if name /= model.reportForm.about then
                                { emptyReportForm | about = name }

                            else
                                model.reportForm

                        _ ->
                            model.reportForm

                offerForm =
                    case route of
                        Route.ListingPage listingId ->
                            if route /= model.route then
                                offerFormFor model listingId

                            else
                                model.offerForm

                        _ ->
                            emptyOfferForm
            in
            ( { model
                | route = route
                , reportForm = reportForm
                , offerForm = offerForm
                , listingForm = prefillListingForm route model.listingForm
                , filtersOpen = False
              }
            , if route == Route.Admin && route /= model.route then
                loadAdmin model

              else
                Command.none
            )

        Tick now ->
            ( { model | now = now }, Command.none )

        ProviderClicked provider ->
            case ( AuthProviders.isConfigured provider, AuthProviders.methodIdFor provider ) of
                ( True, Just methodId ) ->
                    Auth.Flow.signInRequested methodId model Nothing
                        |> Tuple.mapSecond (AuthToBackend >> Effect.Lamdera.sendToBackend)

                _ ->
                    ( { model | previewSignInFor = Just provider }, Command.none )

        PreviewSignInConfirmed provider ->
            ( { model | previewSignInFor = Nothing }, Effect.Lamdera.sendToBackend (PreviewSignIn provider) )

        PreviewAdminSignInClicked ->
            ( model, Effect.Lamdera.sendToBackend PreviewAdminSignIn )

        PreviewSignInCancelled ->
            ( { model | previewSignInFor = Nothing }, Command.none )

        SignOutClicked ->
            ( model, Command.batch [ Effect.Lamdera.sendToBackend SignOut, navigate model Route.Home ] )

        ClaimNameChanged name ->
            ( { model | claimName = name, claimError = Nothing }, Command.none )

        ClaimNameSubmitted ->
            ( model, Effect.Lamdera.sendToBackend (ClaimName model.claimName) )

        SearchChanged search ->
            let
                ( newModel, _ ) =
                    updateFilters (\f -> { f | search = search }) model
            in
            ( newModel
            , if model.route /= Route.Market then
                navigate model Route.Market

              else
                Command.none
            )

        TabSelected tab ->
            updateFilters (\f -> { f | tab = tab }) model

        SortSelected sort ->
            updateFilters (\f -> { f | sort = sort }) model

        RarityToggled rarity ->
            updateFilters (\f -> { f | rarities = toggle rarity f.rarities }) model

        QualityToggled quality ->
            updateFilters (\f -> { f | qualities = toggle quality f.qualities }) model

        HideOutliersToggled ->
            updateFilters (\f -> { f | hideOutliers = not f.hideOutliers }) model

        FineOnlyToggled ->
            updateFilters (\f -> { f | fineOnly = not f.fineOnly }) model

        FiltersToggled ->
            ( { model | filtersOpen = not model.filtersOpen }, Command.none )

        NoticeDismissed ->
            ( { model | me = Maybe.map (\me -> { me | timersNoticeDismissed = True }) model.me }
            , Effect.Lamdera.sendToBackend DismissTimersNotice
            )

        ListingItemQueryChanged query ->
            updateListingForm (\f -> { f | itemQuery = query }) model

        ListingItemPicked itemId ->
            -- Searching "fine iron bar" and picking Iron bar means the fine one
            -- (and "rare camel egg" the rare egg).
            updateListingForm
                (\f ->
                    { f
                        | itemId = Just itemId
                        , itemQuery = ""
                        , fine = String.startsWith "fine " (String.toLower (String.trim f.itemQuery))
                        , rare = String.startsWith "rare " (String.toLower (String.trim f.itemQuery))
                        , error = Nothing
                    }
                )
                model

        ListingItemCleared ->
            updateListingForm (\f -> { f | itemId = Nothing }) model

        ListingQualityPicked quality ->
            updateListingForm (\f -> { f | quality = quality }) model

        ListingFineToggled fine ->
            updateListingForm (\f -> { f | fine = fine }) model

        ListingRareToggled rare ->
            updateListingForm (\f -> { f | rare = rare }) model

        ListingSidePicked side ->
            updateListingForm (\f -> { f | side = side }) model

        ListingQuantityChanged quantity ->
            updateListingForm (\f -> { f | quantity = quantity }) model

        ListingPriceChanged price ->
            updateListingForm (\f -> { f | price = price }) model

        ListingNoteChanged note ->
            updateListingForm (\f -> { f | note = note }) model

        ListingSubmitted ->
            case Page.NewListing.toDraft model.listingForm of
                Ok draft ->
                    let
                        form =
                            model.listingForm
                    in
                    ( { model | listingForm = { form | submitting = True, error = Nothing } }
                    , Effect.Lamdera.sendToBackend (CreateListing draft)
                    )

                Err err ->
                    updateListingForm (\f -> { f | error = Just err }) model

        CloseListingClicked listingId ->
            ( model, Effect.Lamdera.sendToBackend (CloseListing listingId) )

        OfferCounterToggled counter ->
            updateOfferForm (\f -> { f | counter = counter, error = Nothing }) model

        OfferPriceChanged price ->
            updateOfferForm (\f -> { f | price = price, error = Nothing }) model

        OfferMessageChanged message ->
            updateOfferForm (\f -> { f | message = message }) model

        OfferSubmitted listingId ->
            let
                form =
                    model.offerForm

                price =
                    if form.counter then
                        Market.parsePrice form.price |> Result.map Just

                    else
                        Ok Nothing
            in
            case price |> Result.andThen (\p -> Market.validateOffer p form.message) of
                Ok offer ->
                    ( { model | offerForm = emptyOfferForm }
                    , Effect.Lamdera.sendToBackend (MakeOffer listingId offer.price offer.message)
                    )

                Err err ->
                    updateOfferForm (\f -> { f | error = Just err }) model

        WithdrawOfferClicked offerId ->
            ( model, Effect.Lamdera.sendToBackend (WithdrawOffer offerId) )

        RespondToOfferClicked offerId accept ->
            ( model, Effect.Lamdera.sendToBackend (RespondToOffer offerId accept) )

        ReportReasonToggled reason ->
            let
                form =
                    model.reportForm
            in
            ( { model | reportForm = { form | reasons = toggle reason form.reasons } }, Command.none )

        ReportDetailsChanged details ->
            let
                form =
                    model.reportForm
            in
            ( { model | reportForm = { form | details = details } }, Command.none )

        ReportSubmitted ->
            let
                form =
                    model.reportForm
            in
            ( model, Effect.Lamdera.sendToBackend (SubmitReport form.about (List.reverse form.reasons) form.details) )

        ToastDismissed ->
            ( { model | toast = Nothing }, Command.none )

        TradesTabSelected tab ->
            ( { model | tradesTab = tab }, Command.none )

        AdminTabSelected tab ->
            updateAdminPage (\p -> { p | tab = tab, confirming = Nothing }) model

        AdminSearchChanged search ->
            updateAdminPage (\p -> { p | search = search }) model

        AdminActionClicked action ->
            case action of
                SetReportResolved _ _ ->
                    ( model, Effect.Lamdera.sendToBackend (AdminRequest action) )

                UnbanPlayer _ ->
                    ( model, Effect.Lamdera.sendToBackend (AdminRequest action) )

                _ ->
                    updateAdminPage (\p -> { p | confirming = Just action, banReason = "" }) model

        AdminBanReasonChanged reason ->
            updateAdminPage (\p -> { p | banReason = reason }) model

        AdminConfirmed ->
            let
                page =
                    model.adminPage

                send action =
                    ( { model | adminPage = { page | confirming = Nothing } }
                    , Effect.Lamdera.sendToBackend (AdminRequest action)
                    )
            in
            case page.confirming of
                Just (BanPlayer name _) ->
                    -- The button is disabled until there's a reason.
                    if String.trim page.banReason == "" then
                        ( model, Command.none )

                    else
                        send (BanPlayer name page.banReason)

                Just action ->
                    send action

                Nothing ->
                    ( model, Command.none )

        AdminCancelled ->
            updateAdminPage (\p -> { p | confirming = Nothing }) model

        AdminRefreshClicked ->
            ( model, loadAdmin model )

        NoOpFrontendMsg ->
            ( model, Command.none )


updateFromBackend : ToFrontend -> Model -> ( Model, Cmd_ )
updateFromBackend msg model =
    case msg of
        AuthToFrontend authMsg ->
            case authMsg of
                Auth.Common.AuthInitiateSignin signinUrl ->
                    ( model, Effect.Browser.Navigation.load (Url.toString signinUrl) )

                Auth.Common.AuthError err ->
                    ( { model | authFlow = Auth.Common.Errored err }, Command.none )

                Auth.Common.AuthSessionChallenge _ ->
                    ( model, Command.none )

        InitialDataSent data ->
            ( { model
                | loaded = True
                , listings = data.listings |> List.map (\l -> ( l.id, l )) |> Dict.fromList
                , offers = data.offers |> List.map (\o -> ( o.id, o )) |> Dict.fromList
                , traders = data.traders |> List.map (\t -> ( t.name, t )) |> Dict.fromList
              }
            , Command.none
            )

        YouAre me ->
            let
                -- On the OAuth redirect the connect-time `YouAre Nothing` lands
                -- before the callback is processed; keep showing "logging you
                -- in" instead of flashing "signed out".
                stillSigningIn =
                    me == Nothing && isAuthorized model.authFlow

                newModel =
                    { model
                        | me = me
                        , authFlow =
                            if stillSigningIn then
                                model.authFlow

                            else
                                Auth.Common.Idle
                    }

                onboarding =
                    case me of
                        Just _ ->
                            not (Derived.isReady newModel)

                        Nothing ->
                            False
            in
            ( if Maybe.map .isAdmin me == Just True then
                newModel

              else
                { newModel | admin = Nothing }
            , if model.route == Route.SignIn && me /= Nothing then
                navigate model Route.Onboarding

              else if onboarding && model.route == Route.Home then
                navigate model Route.Onboarding

              else if model.route == Route.Admin && model.admin == Nothing then
                loadAdmin newModel

              else
                Command.none
            )

        ListingUpserted listing ->
            ( { model | listings = Dict.insert listing.id listing model.listings }, Command.none )

        ListingRemoved listingId ->
            ( { model
                | listings = Dict.remove listingId model.listings
                , offers = Dict.filter (\_ o -> o.listingId /= listingId) model.offers
              }
            , Command.none
            )

        OfferRemoved offerId ->
            ( { model | offers = Dict.remove offerId model.offers }, Command.none )

        TraderRemoved name ->
            ( { model | traders = Dict.remove name model.traders }, Command.none )

        AdminDataSent data ->
            ( { model | admin = Just data }, Command.none )

        OfferUpserted offer ->
            let
                newModel =
                    { model | offers = Dict.insert offer.id offer model.offers }
            in
            ( if Derived.myName model == Just offer.from && model.route == Route.ListingPage offer.listingId then
                { newModel | offerForm = offerFormFor newModel offer.listingId }

              else
                newModel
            , Command.none
            )

        TraderUpserted trader ->
            ( { model | traders = Dict.insert trader.name trader model.traders }, Command.none )

        ClaimRejected err ->
            ( { model | claimError = Just err }, Command.none )

        ListingCreated listingId ->
            ( { model | listingForm = emptyListingForm }, navigate model (Route.ListingPage listingId) )

        ReportReceived ->
            let
                form =
                    model.reportForm
            in
            ( { model | reportForm = { form | sent = True } }, Command.none )

        ActionFailed err ->
            let
                form =
                    model.listingForm
            in
            ( { model | toast = Just err, listingForm = { form | submitting = False } }, Command.none )



-- VIEW


view : Model -> Effect.Browser.Document FrontendMsg
view model =
    { title = pageTitle model.route
    , body =
        [ -- Tailwind stylesheet. Lamdera serves public/ statically at the site
          -- root, so public/output.css is reachable at /output.css. A plain
          -- <link> in <head> does nothing under Lamdera, so we inject it here.
          -- ?dev is a content-hash cache-buster stamped by scripts/cachebust.js
          -- (dev watcher + pre-commit) from the hash of output.css, so the URL
          -- changes only when the CSS actually changes.
          Html.node "link" [ Attr.rel "stylesheet", Attr.href "/output.css?dev=5ad3b3c2" ] []
        , Html.node "link"
            [ Attr.rel "stylesheet"
            , Attr.href "https://fonts.googleapis.com/css2?family=Alegreya:wght@700;800&family=Barlow:wght@400;500;600;700&family=Barlow+Condensed:wght@400;600&display=swap"
            ]
            []
        , Html.node "meta" [ Attr.name "viewport", Attr.attribute "content" "width=device-width, initial-scale=1" ] []
        , case model.route of
            Route.SignIn ->
                focusedShell (Page.SignIn.viewSignIn model)

            Route.Onboarding ->
                focusedShell (Page.SignIn.viewOnboarding model)

            _ ->
                appShell model (viewPage model)
        , viewToast model
        ]
    }


pageTitle : Route -> String
pageTitle route =
    let
        suffix t =
            t ++ " · Trailpost"
    in
    case route of
        Route.Home ->
            "Trailpost · a fan-made market for WalkScape"

        Route.Market ->
            suffix "Market"

        Route.Prices ->
            suffix "Prices"

        Route.ItemPrice id _ ->
            suffix (Item.byId id |> Maybe.map .name |> Maybe.withDefault "Prices")

        Route.ListingPage _ ->
            suffix "Listing"

        Route.NewListing _ ->
            suffix "New listing"

        Route.MyTrades ->
            suffix "My trades"

        Route.Profile name ->
            suffix name

        Route.Report name ->
            suffix ("Report " ++ name)

        Route.SignIn ->
            suffix "Sign in"

        Route.Onboarding ->
            suffix "Welcome"

        Route.Admin ->
            suffix "Admin"

        Route.NotFound ->
            suffix "Not found"


viewPage : Model -> Html FrontendMsg
viewPage model =
    case model.route of
        Route.Home ->
            Page.Home.view model

        Route.Market ->
            Page.Market.view model

        Route.Prices ->
            Page.Prices.viewIndex model

        Route.ItemPrice id quality ->
            Page.Prices.viewItem model id quality

        Route.ListingPage id ->
            Page.Listing.view model id

        Route.NewListing _ ->
            Page.NewListing.view model

        Route.MyTrades ->
            Page.Trades.view model

        Route.Profile name ->
            Page.Profile.view model name

        Route.Report name ->
            Page.Report.view model name

        Route.Admin ->
            Page.Admin.view model

        Route.SignIn ->
            Ui.empty

        Route.Onboarding ->
            Ui.empty

        Route.NotFound ->
            Ui.pageMessage []
                [ Html.h1 [ Attr.class "font-display text-3xl text-ink mb-3" ] [ Html.text "Nothing here" ]
                , Html.a [ Attr.href "/market" ] [ Html.text "Back to the market" ]
                ]


focusedShell : Html FrontendMsg -> Html FrontendMsg
focusedShell content =
    Html.div [ Attr.class "min-h-screen bg-gradient-to-b from-bar to-shell" ]
        [ Html.div [ Attr.class "max-w-md mx-auto px-4 pt-5 pb-10 min-h-screen flex flex-col" ]
            [ Html.a [ Attr.href "/", Attr.class "font-display font-extrabold text-[28px] text-gold no-underline" ] [ Html.text "Trailpost" ]
            , content
            ]
        ]


appShell : Model -> Html FrontendMsg -> Html FrontendMsg
appShell model content =
    Html.div [ Attr.class "min-h-screen bg-shell flex flex-col" ]
        [ viewHeader model
        , previewBanner
        , viewBanNotice model
        , Html.main_ [ Attr.class "flex-1 flex flex-col pb-20 md:pb-0" ] [ content ]
        , viewTabBar model
        ]


previewBanner : Html msg
previewBanner =
    Html.div [ Attr.class "border-b border-[#6b5520] bg-[#1a1608] text-[13px] text-[#e9d9a6] px-4 md:px-7 py-2 flex gap-2 items-baseline", Ui.testId "preview-banner" ]
        [ Html.span [ Attr.class "font-bold tracking-widest text-[11px] text-gold flex-none" ] [ Html.text "PREVIEW" ]
        , Html.span [ Attr.class "hidden sm:inline" ]
            [ Html.text "Trading isn't live in WalkScape yet. Listings and offers here just build up price estimates, and nothing changes hands. "
            , feedbackLink
            ]
        , Html.span [ Attr.class "sm:hidden" ]
            [ Html.text "Trading isn't live in WalkScape yet. Listings and offers just build price estimates. "
            , feedbackLink
            ]
        ]


viewBanNotice : Model -> Html msg
viewBanNotice model =
    case model.me |> Maybe.andThen .ban of
        Just ban ->
            Ui.callout Ui.Bad
                [ Attr.class "rounded-none border-x-0 border-t-0 px-4 md:px-7 py-2.5 text-sm", Ui.testId "ban-notice" ]
                [ Html.b [] [ Html.text "Your account is banned. " ]
                , Html.text ("Reason: " ++ ban.reason ++ ". You can browse, but you can't post listings, make offers or send reports.")
                ]

        Nothing ->
            Ui.empty


feedbackLink : Html msg
feedbackLink =
    Html.a [ Attr.href Ui.feedbackThreadUrl, Attr.target "_blank", Attr.rel "noopener", Attr.class "text-gold whitespace-nowrap" ] [ Html.text "Feedback?" ]


navItems : Model -> List ( Route, String )
navItems model =
    ( Route.Market, "MARKET" )
        :: ( Route.Prices, "PRICES" )
        :: (if model.me /= Nothing then
                [ ( Route.MyTrades, "TRADES" ), ( profileRoute model, "PROFILE" ) ]

            else
                []
           )
        ++ (if Maybe.map .isAdmin model.me == Just True then
                [ ( Route.Admin, "ADMIN" ) ]

            else
                []
           )


profileRoute : Model -> Route
profileRoute model =
    case Derived.myName model of
        Just name ->
            Route.Profile name

        Nothing ->
            Route.Onboarding


isActive : Route -> Route -> Bool
isActive current target =
    case ( current, target ) of
        ( Route.ItemPrice _ _, Route.Prices ) ->
            True

        ( Route.ListingPage _, Route.Market ) ->
            True

        ( Route.NewListing _, Route.Market ) ->
            True

        _ ->
            current == target


viewHeader : Model -> Html FrontendMsg
viewHeader model =
    let
        badge =
            Derived.pendingResponses model

        navLink ( route, text ) =
            Html.a
                [ Attr.href (Route.toString route)
                , Attr.class
                    ("flex items-center px-[18px] no-underline font-semibold text-[13px] tracking-[0.05em] "
                        ++ (if isActive model.route route then
                                "text-gold shadow-[inset_0_-2px_0_#e3b54c]"

                            else
                                "text-muted hover:text-soft"
                           )
                    )
                ]
                [ Html.text text
                , if route == Route.MyTrades && badge > 0 then
                    Html.span [ Attr.class "ml-1.5 bg-danger text-white rounded-lg px-1.5 text-[10px]" ] [ Html.text (String.fromInt badge) ]

                  else
                    Ui.empty
                ]
    in
    Html.header [ Attr.class "flex items-stretch gap-4 md:gap-9 px-4 md:px-7 h-16 flex-none bg-bar border-b border-line" ]
        [ Html.a [ Attr.href "/", Attr.class "flex items-center font-display font-extrabold text-[28px] leading-none text-gold no-underline" ] [ Html.text "Trailpost" ]
        , Html.nav [ Attr.class "hidden md:flex" ] (List.map navLink (navItems model))
        , Html.div [ Attr.class "flex-1" ] []
        , Html.div [ Attr.class "hidden md:flex items-center" ]
            [ Html.input
                [ Attr.id "header-search"
                , Attr.class "w-[280px] h-[38px] rounded-[9px] border border-rule bg-field px-3 text-sm text-ink placeholder:text-faint outline-none focus:border-gold"
                , Attr.placeholder "Search items or traders…"
                , Attr.value model.filters.search
                , Events.onInput SearchChanged
                ]
                []
            ]
        , Html.div [ Attr.class "flex items-center" ]
            [ case model.me of
                Just _ ->
                    Html.a
                        [ Attr.href (Route.toString (profileRoute model))
                        , Attr.class "flex items-center gap-2 pl-1 pr-2.5 py-1 rounded-[10px] bg-raised border border-edge no-underline text-ink"
                        , Ui.testId "user-chip"
                        ]
                        [ Ui.portrait "w-[26px] h-[26px] rounded-md"
                        , Html.span [ Attr.class "font-semibold text-[13px]" ]
                            [ Html.text (Derived.myName model |> Maybe.withDefault "Finish sign-up") ]
                        ]

                Nothing ->
                    Html.a [ Attr.href "/signin", Attr.id "header-signin", Ui.buttonStyle Ui.Primary Ui.Small ]
                        [ Html.text "Sign in" ]
            ]
        ]


viewTabBar : Model -> Html FrontendMsg
viewTabBar model =
    Html.nav [ Attr.class "md:hidden fixed bottom-0 inset-x-0 h-14 bg-bar border-t border-line flex z-20" ]
        (navItems model
            |> List.map
                (\( route, text ) ->
                    Html.a
                        [ Attr.href (Route.toString route)
                        , Attr.class
                            ("flex-1 flex items-center justify-center no-underline font-semibold text-xs tracking-[0.05em] "
                                ++ (if isActive model.route route then
                                        "text-gold shadow-[inset_0_2px_0_#e3b54c]"

                                    else
                                        "text-muted"
                                   )
                            )
                        ]
                        [ Html.text text
                        , if route == Route.MyTrades && Derived.pendingResponses model > 0 then
                            Html.span [ Attr.class "ml-1.5 bg-danger text-white rounded-lg px-1.5 text-[10px]" ]
                                [ Html.text (String.fromInt (Derived.pendingResponses model)) ]

                          else
                            Ui.empty
                        ]
                )
        )


viewToast : Model -> Html FrontendMsg
viewToast model =
    case model.toast of
        Just text ->
            Ui.callout Ui.Bad
                [ Attr.class "fixed bottom-20 md:bottom-6 inset-x-4 md:inset-x-auto md:right-6 md:max-w-sm z-30 px-4 py-3 flex gap-3 items-start shadow-xl", Ui.testId "toast" ]
                [ Html.div [ Attr.class "flex-1 text-sm" ] [ Html.text text ]
                , Html.button [ Attr.id "toast-dismiss", Events.onClick ToastDismissed, Attr.class "text-muted text-lg leading-none" ] [ Html.text "×" ]
                ]

        Nothing ->
            Ui.empty
