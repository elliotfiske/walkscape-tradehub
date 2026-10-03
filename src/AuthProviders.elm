module AuthProviders exposing (isConfigured, methodIdFor, providerFromMethodId)

{-| Which sign-in providers have real OAuth set up. Kept apart from `Auth` so
the frontend never imports the module that references OAuth client secrets.
-}

import Env
import Types exposing (Provider(..))


methodIdFor : Provider -> Maybe String
methodIdFor provider =
    case provider of
        Discord ->
            Just "OAuthDiscord"


providerFromMethodId : String -> Maybe Provider
providerFromMethodId id =
    case id of
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
        Discord ->
            Env.discordClientId /= ""
