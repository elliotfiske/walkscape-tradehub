# Trailpost — To-Do

The backlog. The original starter checklist is done (see git history).

## Needs input from Elliot

- **Discord sign-in on PR previews.** Each PR deploys to
  `trailpost-pr-<N>.lamdera.app` (`.github/workflows/preview.yml`), and Discord
  only allows redirect URIs registered in the Developer Portal, so OAuth fails
  on every preview domain (the "preview account" sign-in still works there).
  Ideas: register a wildcard-ish set of URIs, route all previews' callbacks
  through one fixed callback domain that bounces back, or just rely on the
  preview account. Also check that preview apps get accepted at all without
  per-app `discordClientId`/`discordClientSecret` values in the Lamdera
  dashboard ("MISSING PRODUCTION CONFIG" is what killed the starter's previews).

## Live trading

Trading went live in WalkScape on 2026-10-07. How it works in the game:
Social → Find (or Leaderboards) → a character → **Invite to trade**. Once the
other person accepts the invite, each side puts in coins and items, presses
**Update** to send their changes (Accept is greyed out while you have unsent
edits), and then both press **Accept**. The swap happens all at once and shows
up under "Previous trades" as Completed or Rejected. There's no in-game market
or price history. The official Discord has a "Grand Emporium" forum where the
Helpful Herbert bot posts listings and people use `/offer`. Lots of those trades
are item-for-item.

Because the game swaps both sides at once, nobody can just take coins and run.
The scams that are left all come down to accepting the wrong window:

- **Last-minute swap:** the other side changes their offer just before you accept.
  An Update resets Accept, so this only catches people who accept again
  without re-reading.
- **Fine vs. normal:** the only difference in the trade window is the text
  color. Fine items are teal, normal items are white.
- **Coin digits:** the other side's coins aren't formatted (`37500`), so `3750`
  is easy to misread.
- **Look-alike names** when inviting (Bel / Bell / Belkanis). Character names
  are unique and case-insensitive.

### Phase 1: wording and the trade checklist (done)
Preview wording is gone, and accepted offers show both traders a checklist on
the listing page.

### Phase 2: real trades (done)
- Offers are all-or-nothing: always for the listing's full quantity.
- Accepting an offer reserves the listing ("trade pending", worked out from the
  offers): it leaves the market list, takes no new offers, can't accept a
  second offer or be closed. Other open offers stay open as a fallback.
- Both sides confirm "It went through" (`OfferCompleted`, which closes the
  listing), or either side marks it "Fell through" with a reason
  (`OfferFellThrough`, final), which puts the listing back up straight away.
- No listing expiry yet. Maybe later: listings expire after N days, with a
  "Still available?" bump.

### Phase 3: trust (no verification yet)
- Done: "12 trades · 0 fell through" on profiles and trader cards; the Discord
  account's age next to the handle (from the user id); "Report a problem with
  this trade" on the checklist and on fallen-through trades, with a "Didn't
  match what we agreed" reason, a copy of the trade on the report, and up to 3
  screenshots (shrunk in the browser, kept in the BackendModel, admins only).
- Screenshots live in `BackendModel.screenshots` (up to ~1.2MB per report). If
  reports pile up, move them out or delete them when a report is resolved.
- Name verification is less urgent now that trades swap both sides at once.
  Ideas: the coin-to-bot flow from #15 (recover from `885e9d5`), checked by hand
  in `/admin` instead of by a bot; or Helpful Herbert already knows each
  Discord user's game name (its listings show "Seller: Noggg" for @Nogisto), so
  ask the WalkScape devs whether that link is exposed anywhere.

### Phase 4: data and notifications
- Done: estimates from completed trades. With 3+ confirmed trades in the last
  30 days, the estimate is their median; otherwise asks, bids and offers.
  Every place an estimate shows says which it used.
- Notifications when an offer gets a response (Discord DM from a bot, or browser
  push). People are out walking, not watching the site.
- Item-for-item payment (`Payment` already has room for it). Coin-only
  estimates would ignore these.

### Later
- Chat on an accepted trade, escrow (design 1m), Discord linking for
  non-Discord sign-ins.

## Preview polish

- Admins are matched by Discord *username*, which people can change and
  reuse. Switch `adminDiscordUsernames` to Discord user ids if that matters.
- Bans only stick for Discord accounts. A banned preview account can sign out
  and make a new one.
- Editing a listing (should restart the 5-minute wait).
