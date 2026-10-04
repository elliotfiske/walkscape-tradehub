module Env exposing
    ( adminDiscordUsernames
    , discordClientId
    , discordClientSecret
    )

-- The Env.elm file is for per-environment configuration.
-- See https://dashboard.lamdera.app/docs/environment for more info.
--
-- Leave discordClientId empty to fall back to a placeholder "preview" sign-in. Client ids are read by the frontend; secrets must
-- only ever be referenced from backend code.
--
-- adminDiscordUsernames is a comma-separated list of Discord usernames that can
-- open the admin screen (/admin).


discordClientId : String
discordClientId =
    ""


discordClientSecret : String
discordClientSecret =
    ""


adminDiscordUsernames : String
adminDiscordUsernames =
    ""
