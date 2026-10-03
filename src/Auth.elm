module Auth exposing (backendConfig)

import Auth.Common
import Auth.Flow
import Auth.Method.OAuthDiscord
import AuthProviders
import Env
import Lamdera
import Time
import Types
    exposing
        ( BackendModel
        , BackendMsg(..)
        , FrontendModel
        , FrontendMsg
        , ToBackend(..)
        , ToFrontend(..)
        )
import Users


config : Auth.Common.Config FrontendMsg ToBackend BackendMsg ToFrontend FrontendModel BackendModel
config =
    { toBackend = AuthToBackend
    , toFrontend = AuthToFrontend
    , backendMsg = AuthBackendMsg
    , sendToFrontend = Lamdera.sendToFrontend
    , sendToBackend = Lamdera.sendToBackend
    , methods =
        [ Auth.Method.OAuthDiscord.configuration Env.discordClientId Env.discordClientSecret
        ]
    , renewSession = \_ _ model -> ( model, Cmd.none )
    }


backendConfig : BackendModel -> Auth.Flow.BackendUpdateConfig FrontendMsg BackendMsg ToFrontend FrontendModel BackendModel
backendConfig model =
    { asToFrontend = AuthToFrontend
    , asBackendMsg = AuthBackendMsg
    , sendToFrontend = Lamdera.sendToFrontend
    , backendModel = model
    , loadMethod =
        \id ->
            config.methods
                |> List.filter (\m -> methodId m == id)
                |> List.head
    , handleAuthSuccess = handleAuthSuccess model
    , renewSession = config.renewSession
    , logout = \_ _ m -> ( m, Cmd.none )
    , isDev = False
    }


handleAuthSuccess :
    BackendModel
    -> Auth.Common.SessionId
    -> Auth.Common.ClientId
    -> Auth.Common.UserInfo
    -> Auth.Common.MethodId
    -> Maybe Auth.Common.Token
    -> Time.Posix
    -> ( BackendModel, Cmd BackendMsg )
handleAuthSuccess model sessionId clientId userInfo methodId_ _ now =
    case AuthProviders.providerFromMethodId methodId_ of
        Just provider ->
            let
                -- The Discord user id (see OAuthDiscord).
                subject =
                    userInfo.email

                ( newModel, user ) =
                    Users.signIn
                        { userId = methodId_ ++ ":" ++ subject
                        , provider = provider
                        , isPreviewLogin = False
                        , oauthUsername = userInfo.username
                        }
                        sessionId
                        now
                        model
            in
            ( newModel
            , Lamdera.sendToFrontend clientId (YouAre (Just (Users.toMe user)))
            )

        Nothing ->
            ( model, Cmd.none )


methodId : Auth.Common.Method frontendMsg backendMsg frontendModel backendModel -> String
methodId method =
    case method of
        Auth.Common.ProtocolOAuth cfg ->
            cfg.id

        Auth.Common.ProtocolEmailMagicLink cfg ->
            cfg.id
