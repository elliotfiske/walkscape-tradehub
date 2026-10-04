# Trailpost — To-Do

Things the preview leaves for later. The original starter checklist is done
(see git history).

## Needs input from Elliot

- **Discord credentials in production.** Set `discordClientId` /
  `discordClientSecret` in Lamdera's env vars and add the production callback
  URL in the Discord Developer Portal.

- **Discord sign-in on PR previews.** Each PR deploys to
  `trailpost-pr-<N>.lamdera.app` (`.github/workflows/preview.yml`), and Discord
  only allows redirect URIs registered in the Developer Portal, so OAuth fails
  on every preview domain (the "preview account" sign-in still works there).
  Ideas: register a wildcard-ish set of URIs, route all previews' callbacks
  through one fixed callback domain that bounces back, or just rely on the
  preview account. Also check that preview apps get accepted at all without
  per-app `discordClientId`/`discordClientSecret` values in the Lamdera
  dashboard ("MISSING PRODUCTION CONFIG" is what killed the starter's previews).

## When trading goes live

- TrailpostBot verification: bring back a claim step where the player offers a
  random coin amount to the bot, add a verified `ClaimStatus`, and let a
  verified owner take a name over from a squatter.
- WalkScape API lookups on the claim step and profiles.
- Trade rooms (design 1d/1e): locked terms, in-game checklist, both-confirm,
  chat. Accepted offers are the natural entry point.
- Estimates from confirmed trades instead of asks/offers; half weight for new names.
- Escrow (design 1m), screenshot uploads on reports, Discord linking for
  non-Discord sign-ins.

## Preview polish

- Admins are matched by Discord *username*, which people can change and
  reuse. Switch `adminDiscordUsernames` to Discord user ids if that matters.
- Bans only stick for Discord accounts. A banned preview account can sign out
  and make a new one.
- Editing a listing (should restart the 15-minute wait).
