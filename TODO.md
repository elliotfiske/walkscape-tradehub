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

### Phase 2: real trades
- Add `quantity` to `Offer`, defaulting to the full listing quantity.
- Accepting an offer takes its quantity off what's left on the listing, and the
  listing closes when nothing is left. Flag open offers that ask for more than
  what's left.
- Both sides confirm "It went through" (new `OfferCompleted`), or mark it as
  "Fell through" with a reason.
- Listings expire after N days, with a "Still available?" bump.
- Evergreen migration for all of the above.

### Phase 3: trust (no verification yet)
- Completed-trade count on profiles ("12 trades · 0 fell through").
- Show the Discord account's age next to the handle.
- A "Didn't match what we agreed" report reason tied to a trade, with
  screenshot uploads (the in-game "Previous trades" screen is good evidence).
- Name verification is less urgent now that trades swap both sides at once.
  Ideas: the coin-to-bot flow from #15 (recover from `885e9d5`), checked by hand
  in `/admin` instead of by a bot; or Helpful Herbert already knows each
  Discord user's game name (its listings show "Seller: Noggg" for @Nogisto), so
  ask the WalkScape devs whether that link is exposed anywhere.

### Phase 4: data and notifications
- Estimates from completed trades first, then asks and bids.
- Notifications when an offer gets a response (Discord DM from a bot, or browser
  push). People are out walking, not watching the site.
- Item-for-item payment (`Payment` already has room for it). Coin-only
  estimates would ignore these.
- Analytics: `offer_accepted`, `trade_completed`, `trade_fell_through`.

### Later
- Chat on an accepted trade, escrow (design 1m), Discord linking for
  non-Discord sign-ins.

## Preview polish

- Admins are matched by Discord *username*, which people can change and
  reuse. Switch `adminDiscordUsernames` to Discord user ids if that matters.
- Bans only stick for Discord accounts. A banned preview account can sign out
  and make a new one.
- Editing a listing (should restart the 5-minute wait).
