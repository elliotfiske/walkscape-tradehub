module AuthProviders exposing (isConfigured, methodIdFor, providerFromMethodId)

{-| Which sign-in providers have real OAuth set up. Kept apart from `Auth` so
the frontend never imports the module that references OAuth client secrets.
-}

import Env
import Types exposing (Provider(..))


{-| Apple sign-in needs a POST callback (an RPC endpoint) and a signed client
secret; until that's built it always uses the placeholder preview sign-in.
-}
methodIdFor : Provider -> Maybe String
methodIdFor provider =
    case provider of
        Apple ->
            Nothing

        Google ->
            Just "OAuthGoogle"

        Discord ->
            Just "OAuthDiscord"


providerFromMethodId : String -> Maybe Provider
providerFromMethodId id =
    case id of
        "OAuthGoogle" ->
            Just Google

        "OAuthDiscord" ->
            Just Discord

        _ ->
            Nothing


{-| Whether real OAuth is set up for this provider. Only client ids are read
here, because this runs on the frontend too.
-}
isConfigured : Provider -> Bool
isConfigured provider =
    case provider of
        Apple ->
            False

        Google ->
            Env.googleClientId /= ""

        Discord ->
            Env.discordClientId /= ""
