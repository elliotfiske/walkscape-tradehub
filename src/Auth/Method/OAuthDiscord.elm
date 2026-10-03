module Auth.Method.OAuthDiscord exposing (configuration)

{-| Discord OAuth, modelled on the vendored `Auth.Method.OAuthGithub`.

Only asks for the `identify` scope: we want the Discord handle to show on a
trader's profile, nothing else.

-}

import Auth.Common exposing (Flow, LogoutEndpointConfig(..), Method(..), UserInfo, defaultHttpsUrl)
import Auth.HttpHelpers as HttpHelpers
import Auth.Protocol.OAuth
import Http
import Json.Decode as Json
import OAuth
import OAuth.AuthorizationCode as OAuth
import Task exposing (Task)
import Url exposing (Url)


configuration :
    String
    -> String
    -> Method frontendMsg backendMsg { frontendModel | authFlow : Flow, authRedirectBaseUrl : Url } backendModel
configuration clientId clientSecret =
    ProtocolOAuth
        { id = "OAuthDiscord"
        , authorizationEndpoint = { defaultHttpsUrl | host = "discord.com", path = "/oauth2/authorize" }
        , tokenEndpoint = { defaultHttpsUrl | host = "discord.com", path = "/api/oauth2/token" }
        , logoutEndpoint = Home { returnPath = "/logout/OAuthDiscord/callback" }
        , allowLoginQueryParameters = False
        , clientId = clientId
        , clientSecret = clientSecret
        , scope = [ "identify" ]
        , getUserInfo = getUserInfo
        , onFrontendCallbackInit = Auth.Protocol.OAuth.onFrontendCallbackInit
        , placeholder = \_ -> ()
        }


getUserInfo : OAuth.AuthenticationSuccess -> Task Auth.Common.Error UserInfo
getUserInfo authenticationSuccess =
    Http.task
        { method = "GET"
        , headers = OAuth.useToken authenticationSuccess.token []
        , url = Url.toString { defaultHttpsUrl | host = "discord.com", path = "/api/users/@me" }
        , body = Http.emptyBody
        , resolver =
            HttpHelpers.jsonResolver
                (Json.map2 (\username globalName -> { email = "", name = globalName, username = Just username })
                    (Json.field "username" Json.string)
                    (Json.maybe (Json.field "global_name" Json.string))
                )
        , timeout = Nothing
        }
        |> Task.mapError (HttpHelpers.httpErrorToString >> Auth.Common.ErrAuthString)
