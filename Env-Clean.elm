module Env exposing
    ( discordClientId
    , discordClientSecret
    )

-- The Env.elm file is for per-environment configuration.
-- See https://dashboard.lamdera.app/docs/environment for more info.
--
-- Leave discordClientId empty to fall back to a placeholder "preview" sign-in. Client ids are read by the frontend; secrets must
-- only ever be referenced from backend code.


discordClientId : String
discordClientId =
    ""


discordClientSecret : String
discordClientSecret =
    ""
