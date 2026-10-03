# Trailpost — To-Do

Things the preview leaves for later. The original starter checklist is done
(see git history).

## Needs input from Elliot

- **Discord credentials in production.** Set `discordClientId` /
  `discordClientSecret` in Lamdera's env vars and add the production callback
  URL in the Discord Developer Portal.

## When trading goes live

- TrailpostBot verification: check the coin amount, flip `ClaimStatus` to a
  verified state, let a verified owner take a name over from a squatter.
- WalkScape API lookups on the claim step and profiles.
- Trade rooms (design 1d/1e): locked terms, in-game checklist, both-confirm,
  chat. Accepted offers are the natural entry point.
- Estimates from confirmed trades instead of asks/offers; half weight for new names.
- Escrow (design 1m), screenshot uploads on reports, Discord linking for
  non-Discord sign-ins.

## Preview polish

- Moderation view for `BackendModel.reports` (currently only readable via
  `lamdera backend`).
- Editing a listing (should restart the 15-minute wait).
