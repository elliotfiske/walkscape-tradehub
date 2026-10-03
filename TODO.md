# Trailpost — To-Do

Things the preview leaves for later. The original starter checklist is done
(see git history).

## Needs input from Elliot

- **OAuth credentials.** Google and Discord are wired through `Auth.elm`; set
  the client id/secret pairs in Lamdera's env vars (and locally in `src/Env.elm`,
  never committed). Until then those buttons use preview accounts.
- **Apple sign-in.** Needs an RPC endpoint for Apple's POST callback and a
  signed JWT client secret. `Auth.methodIdFor Apple` returns `Nothing` today.
- **Item catalog.** Scraped from walkscapedb.com (`scripts/import-items.py` →
  `src/ItemData.elm`). Switch the script to the official API once the key
  arrives; keep the same output shape. Item icons are still placeholders.

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
