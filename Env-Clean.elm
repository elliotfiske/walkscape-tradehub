module Env exposing
    ( discordClientId
    , discordClientSecret
    , googleClientId
    , googleClientSecret
    )

-- The Env.elm file is for per-environment configuration.
-- See https://dashboard.lamdera.app/docs/environment for more info.
--
-- Leave a provider's client id empty to fall back to a placeholder "preview"
-- sign-in for that button. Client ids are read by the frontend; secrets must
-- only ever be referenced from backend code.


googleClientId : String
googleClientId =
    ""


googleClientSecret : String
googleClientSecret =
    ""


discordClientId : String
discordClientId =
    ""


discordClientSecret : String
discordClientSecret =
    ""
