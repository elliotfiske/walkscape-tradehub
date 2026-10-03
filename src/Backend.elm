module Backend exposing (app, app_)

import Auth
import Auth.Flow
import Dict
import Duration
import Effect.Command as Command exposing (BackendOnly, Command)
import Effect.Lamdera exposing (ClientId, SessionId)
import Effect.Subscription as Subscription exposing (Subscription)
import Effect.Task
import Effect.Time
import Item
import Lamdera as L
import Market
import Name
import Time
import Types
    exposing
        ( BackendModel
        , BackendMsg(..)
        , ClaimStatus(..)
        , Listing
        , ListingDraft
        , Offer
        , OfferStatus(..)
        , Payment(..)
        , ToBackend(..)
        , ToFrontend(..)
        , User
        )
import Users


type alias Model =
    BackendModel


type alias Cmd_ =
    Command BackendOnly ToFrontend BackendMsg


app =
    Effect.Lamdera.backend
        L.broadcast
        L.sendToFrontend
        app_


app_ =
    { init = init
    , update = update
    , updateFromFrontend = updateFromFrontend
    , subscriptions = subscriptions
    }


{-| New listings wait this long before anyone else can see them.
-}
goLiveDelayMs : Int
goLiveDelayMs =
    15 * 60 * 1000


subscriptions : Model -> Subscription BackendOnly BackendMsg
subscriptions _ =
    Subscription.batch
        [ Effect.Lamdera.onConnect ClientConnected
        , Effect.Lamdera.onDisconnect ClientDisconnected
        , Effect.Time.every (Duration.seconds 15) BackendTick
        ]


init : ( Model, Command restriction toMsg BackendMsg )
init =
    ( { now = Time.millisToPosix 0
      , users = Dict.empty
      , sessions = Dict.empty
      , listings = Dict.empty
      , offers = Dict.empty
      , reports = []
      , nextId = 1
      , pendingAuths = Dict.empty
      }
    , Effect.Time.now |> Effect.Task.perform GotTime
    )


update : BackendMsg -> Model -> ( Model, Cmd_ )
update msg model =
    case msg of
        ClientConnected sessionId clientId ->
            let
                user =
                    userForSession sessionId model
            in
            ( model
            , Command.batch
                [ Effect.Lamdera.sendToFrontend clientId (InitialDataSent (initialData user model))
                , Effect.Lamdera.sendToFrontend clientId (YouAre (Maybe.map Users.toMe user))
                ]
            )

        ClientDisconnected _ _ ->
            ( model, Command.none )

        AuthBackendMsg authMsg ->
            Auth.Flow.backendUpdate (Auth.backendConfig model) authMsg
                |> Tuple.mapSecond (Command.fromCmd "auth")

        GotTime now ->
            ( { model | now = now }, Command.none )

        BackendTick now ->
            let
                wentLive l =
                    Time.posixToMillis l.liveAt > Time.posixToMillis model.now && Market.isLive now l
            in
            ( { model | now = now }
            , model.listings
                |> Dict.values
                |> List.filter wentLive
                |> List.map (ListingUpserted >> Effect.Lamdera.broadcast)
                |> Command.batch
            )

        FromFrontendAt sessionId clientId toBackend now ->
            handleRequest sessionId clientId now toBackend model


updateFromFrontend : SessionId -> ClientId -> ToBackend -> Model -> ( Model, Cmd_ )
updateFromFrontend sessionId clientId msg model =
    case msg of
        AuthToBackend authMsg ->
            Auth.Flow.updateFromFrontend
                { asBackendMsg = AuthBackendMsg }
                (Effect.Lamdera.clientIdToString clientId)
                (Effect.Lamdera.sessionIdToString sessionId)
                authMsg
                model
                |> Tuple.mapSecond (Command.fromCmd "auth")

        _ ->
            -- Everything else needs an accurate timestamp, so grab one first.
            ( model, Effect.Time.now |> Effect.Task.perform (FromFrontendAt sessionId clientId msg) )


userForSession : SessionId -> Model -> Maybe User
userForSession sessionId model =
    Dict.get (Effect.Lamdera.sessionIdToString sessionId) model.sessions
        |> Maybe.andThen (\userId -> Dict.get userId model.users)


initialData : Maybe User -> Model -> Types.InitialData
initialData user model =
    let
        myName =
            user |> Maybe.andThen .claim |> Maybe.map .name

        visible l =
            Market.isLive model.now l || Just l.trader == myName

        listings =
            model.listings |> Dict.values |> List.filter visible

        listingIds =
            List.map .id listings
    in
    { listings = listings
    , offers = model.offers |> Dict.values |> List.filter (\o -> List.member o.listingId listingIds)
    , traders = Users.traders model
    }


{-| Send to every open tab of the user who owns this trader name.
-}
sendToTrader : String -> ToFrontend -> Model -> Cmd_
sendToTrader name toFrontend model =
    let
        ownerIds =
            model.users
                |> Dict.values
                |> List.filter (\u -> Maybe.map .name u.claim == Just name)
                |> List.map .id
    in
    model.sessions
        |> Dict.toList
        |> List.filter (\( _, userId ) -> List.member userId ownerIds)
        |> List.map (\( sessionId, _ ) -> Effect.Lamdera.sendToFrontends (Effect.Lamdera.sessionIdFromString sessionId) toFrontend)
        |> Command.batch


{-| Live listings go to everyone; pending ones only to their owner.
-}
publishListing : Listing -> Model -> Cmd_
publishListing listing model =
    if Market.isLive model.now listing then
        Effect.Lamdera.broadcast (ListingUpserted listing)

    else
        sendToTrader listing.trader (ListingUpserted listing) model


saveUser : User -> Model -> Model
saveUser user model =
    { model | users = Dict.insert user.id user model.users }


coinAmount : Time.Posix -> Int -> Int
coinAmount now salt =
    5 + modBy 96 (Time.posixToMillis now // 7 + salt * 31)


handleRequest : SessionId -> ClientId -> Time.Posix -> ToBackend -> Model -> ( Model, Cmd_ )
handleRequest sessionId clientId now msg model =
    let
        fail text =
            ( model, Effect.Lamdera.sendToFrontend clientId (ActionFailed text) )

        replyMe user =
            Effect.Lamdera.sendToFrontends sessionId (YouAre (Just (Users.toMe user)))

        withUser f =
            case userForSession sessionId model of
                Just user ->
                    f user

                Nothing ->
                    fail "Sign in first."

        withReadyUser f =
            withUser
                (\user ->
                    case ( Users.isReady user, user.claim ) of
                        ( True, Just claim ) ->
                            f user claim.name

                        _ ->
                            fail "Finish linking your WalkScape name first."
                )
    in
    case msg of
        AuthToBackend _ ->
            ( model, Command.none )

        PreviewSignIn provider ->
            let
                ( newModel, user ) =
                    Users.signIn
                        { userId = "preview:" ++ Effect.Lamdera.sessionIdToString sessionId
                        , provider = provider
                        , isPreviewLogin = True
                        , oauthUsername = Nothing
                        }
                        (Effect.Lamdera.sessionIdToString sessionId)
                        now
                        model
            in
            ( newModel, replyMe user )

        SignOut ->
            ( { model | sessions = Dict.remove (Effect.Lamdera.sessionIdToString sessionId) model.sessions }
            , Effect.Lamdera.sendToFrontends sessionId (YouAre Nothing)
            )

        ClaimName raw ->
            withUser
                (\user ->
                    case ( Name.validate raw, user.claim ) of
                        ( _, Just { status } ) ->
                            if status == PreviewUnverified then
                                fail "Your account already has a WalkScape name."

                            else
                                claimName user raw now model clientId sessionId

                        ( Err err, Nothing ) ->
                            ( model, Effect.Lamdera.sendToFrontend clientId (ClaimRejected err) )

                        ( Ok _, Nothing ) ->
                            claimName user raw now model clientId sessionId
                )

        NewCoinAmount ->
            withUser
                (\user ->
                    case user.claim of
                        Just claim ->
                            let
                                next =
                                    coinAmount now (claim.coins + 1)

                                coins =
                                    if next == claim.coins then
                                        5 + modBy 96 (next - 4)

                                    else
                                        next

                                newUser =
                                    { user | claim = Just { claim | coins = coins } }
                            in
                            ( saveUser newUser model, replyMe newUser )

                        Nothing ->
                            fail "Claim a WalkScape name first."
                )

        SkipVerification ->
            withUser
                (\user ->
                    case user.claim of
                        Just claim ->
                            let
                                newUser =
                                    { user | claim = Just { claim | status = PreviewUnverified } }

                                newModel =
                                    saveUser newUser model
                            in
                            ( newModel
                            , Command.batch
                                [ replyMe newUser
                                , Users.toTrader newModel newUser
                                    |> Maybe.map (TraderUpserted >> Effect.Lamdera.broadcast)
                                    |> Maybe.withDefault Command.none
                                ]
                            )

                        Nothing ->
                            fail "Claim a WalkScape name first."
                )

        CreateListing draft ->
            withReadyUser
                (\_ name ->
                    case validateDraft draft of
                        Err err ->
                            fail err

                        Ok valid ->
                            if Market.activeListingCount name (Dict.values model.listings) >= Market.maxActiveListings then
                                fail ("You can have up to " ++ String.fromInt Market.maxActiveListings ++ " active listings. Close one first.")

                            else
                                let
                                    listing =
                                        { id = model.nextId
                                        , trader = name
                                        , itemId = valid.itemId
                                        , variant = valid.variant
                                        , side = valid.side
                                        , payment = valid.payment
                                        , quantity = valid.quantity
                                        , note = valid.note
                                        , createdAt = now
                                        , liveAt = Time.millisToPosix (Time.posixToMillis now + goLiveDelayMs)
                                        , closed = False
                                        }

                                    newModel =
                                        { model | listings = Dict.insert listing.id listing model.listings, nextId = model.nextId + 1 }
                                in
                                ( newModel
                                , Command.batch
                                    [ sendToTrader name (ListingUpserted listing) newModel
                                    , Effect.Lamdera.sendToFrontend clientId (ListingCreated listing.id)
                                    ]
                                )
                )

        CloseListing listingId ->
            withReadyUser
                (\_ name ->
                    case Dict.get listingId model.listings of
                        Just listing ->
                            if listing.trader /= name then
                                fail "That isn't your listing."

                            else
                                let
                                    closed =
                                        { listing | closed = True }

                                    newModel =
                                        { model | listings = Dict.insert listingId closed model.listings }
                                in
                                ( newModel, publishListing closed newModel )

                        Nothing ->
                            fail "That listing doesn't exist."
                )

        MakeOffer listingId price message ->
            withReadyUser
                (\_ name ->
                    case Dict.get listingId model.listings of
                        Just listing ->
                            if listing.trader == name then
                                fail "You can't make an offer on your own listing."

                            else if listing.closed || not (Market.isLive now listing) then
                                fail "This listing isn't open for offers."

                            else if Maybe.withDefault 1 price <= 0 then
                                fail "Offer a price above zero."

                            else if String.length message > 280 then
                                fail "Keep your message under 280 characters."

                            else
                                let
                                    existing =
                                        model.offers
                                            |> Dict.values
                                            |> List.filter (\o -> o.listingId == listingId && o.from == name && o.status == OfferOpen)
                                            |> List.head

                                    ( offer, nextId ) =
                                        case existing of
                                            Just o ->
                                                ( { o | price = price, message = String.trim message, at = now }, model.nextId )

                                            Nothing ->
                                                ( { id = model.nextId
                                                  , listingId = listingId
                                                  , from = name
                                                  , price = price
                                                  , message = String.trim message
                                                  , at = now
                                                  , status = OfferOpen
                                                  }
                                                , model.nextId + 1
                                                )
                                in
                                ( { model | offers = Dict.insert offer.id offer model.offers, nextId = nextId }
                                , Effect.Lamdera.broadcast (OfferUpserted offer)
                                )

                        Nothing ->
                            fail "That listing doesn't exist."
                )

        WithdrawOffer offerId ->
            withReadyUser
                (\_ name ->
                    case Dict.get offerId model.offers of
                        Just offer ->
                            if offer.from /= name || offer.status /= OfferOpen then
                                fail "You can't withdraw that offer."

                            else
                                updateOffer { offer | status = OfferWithdrawn } model

                        Nothing ->
                            fail "That offer doesn't exist."
                )

        RespondToOffer offerId accept ->
            withReadyUser
                (\_ name ->
                    case Dict.get offerId model.offers |> Maybe.andThen (\o -> Dict.get o.listingId model.listings |> Maybe.map (Tuple.pair o)) of
                        Just ( offer, listing ) ->
                            if listing.trader /= name || offer.status /= OfferOpen then
                                fail "You can't respond to that offer."

                            else
                                updateOffer
                                    { offer
                                        | status =
                                            if accept then
                                                OfferAccepted

                                            else
                                                OfferDeclined
                                    }
                                    model

                        Nothing ->
                            fail "That offer doesn't exist."
                )

        SubmitReport about reasons details ->
            withReadyUser
                (\_ name ->
                    if not (List.any (\t -> t.name == about) (Users.traders model)) then
                        fail "There's no trader with that name."

                    else if about == name then
                        fail "You can't report yourself."

                    else if List.isEmpty reasons then
                        fail "Pick at least one thing that happened."

                    else
                        ( { model
                            | reports =
                                { reporter = name
                                , about = about
                                , reasons = reasons
                                , details = String.left 2000 details
                                , at = now
                                }
                                    :: model.reports
                          }
                        , Effect.Lamdera.sendToFrontend clientId ReportReceived
                        )
                )


updateOffer : Offer -> Model -> ( Model, Cmd_ )
updateOffer offer model =
    ( { model | offers = Dict.insert offer.id offer model.offers }
    , Effect.Lamdera.broadcast (OfferUpserted offer)
    )


claimName : User -> String -> Time.Posix -> Model -> ClientId -> SessionId -> ( Model, Cmd_ )
claimName user raw now model clientId sessionId =
    case Name.validate raw of
        Err err ->
            ( model, Effect.Lamdera.sendToFrontend clientId (ClaimRejected err) )

        Ok name ->
            let
                takenBySomeoneElse =
                    model.users
                        |> Dict.values
                        |> List.any
                            (\u ->
                                (u.id /= user.id)
                                    && (u.claim |> Maybe.map (\c -> Name.normalize c.name == Name.normalize name) |> Maybe.withDefault False)
                            )
            in
            if takenBySomeoneElse then
                ( model
                , Effect.Lamdera.sendToFrontend clientId
                    (ClaimRejected "Someone already claimed that name here. Once trading opens, the real owner can verify it and take it back.")
                )

            else
                let
                    newUser =
                        { user | claim = Just { name = name, coins = coinAmount now 0, status = AwaitingCoinOffer } }
                in
                ( saveUser newUser model
                , Effect.Lamdera.sendToFrontends sessionId (YouAre (Just (Users.toMe newUser)))
                )


validateDraft : ListingDraft -> Result String ListingDraft
validateDraft draft =
    case Item.byId draft.itemId of
        Nothing ->
            Err "Pick an item from the list."

        Just item ->
            let
                qualityOk =
                    case ( item.kind, draft.variant.quality ) of
                        ( Item.Crafted, Just _ ) ->
                            True

                        ( Item.Crafted, Nothing ) ->
                            False

                        ( _, Nothing ) ->
                            True

                        _ ->
                            False

                paymentOk =
                    case draft.payment of
                        Coins price ->
                            if price > 0 && price <= 1000000000 then
                                Ok ()

                            else
                                Err "Enter a price above zero."
            in
            if not qualityOk then
                Err "Pick a quality for crafted items."

            else if draft.variant.fine && not item.canBeFine then
                Err "This item doesn't come in a fine version."

            else if draft.quantity <= 0 || draft.quantity > 1000000 then
                Err "Enter a quantity above zero."

            else if String.length draft.note > 280 then
                Err "Keep your note under 280 characters."

            else
                paymentOk |> Result.map (\_ -> { draft | note = String.trim draft.note })
