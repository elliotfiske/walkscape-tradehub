# Trailpost — belief note

The working notes behind the site copy rewrite (PR #9), using the "belief building" method from Tiago Forte's *Simple Marketing for Smart People*. The "NEED ANSWER" spots are resolved in the interview answers at the bottom.

## Framing: where is this reader coming from?

- **Channels:** a link in the WalkScape Discord/subreddit, or Elliot's own post
  introducing Trailpost.
- **Ring:** Consideration, leaning into Decision for readers who came from
  Elliot's post. Upstream has already told them WalkScape trading is coming, and
  (from Elliot's post) that Trailpost is a fan-made preview. The site's job is
  to convince them it's worth signing in and posting something *now*, before
  trading exists, and that it's safe to do so.
- **State of mind:** WalkScape is a mobile walking game, so many readers are
  on a phone, half-paying attention, tapping through from a chat. They're
  primed for trading scams, since every game with trading has them, and a fan
  site that asks you to sign in and send coins to a bot looks like one at first glance.

## What they already believe when they arrive

- Trading is coming to WalkScape, and they care about it.
- They don't really know what most items are worth.
- Game-trading scams are common (fake deadlines, item swaps, look-alike names).
- Signing in with Discord is a normal thing for a community tool.
- (From Elliot's post) Trailpost exists, a fan made it, and it's a preview
  where nothing actually trades.

Don't re-argue these. In particular, the current copy says "Trading isn't live
in WalkScape yet" six or so times. The banner covers it.

## Target beliefs — everything the reader must believe to sign in and post

Consideration:
1. Getting a feel for prices *before* trading launches is worth doing. The
   alternative is figuring it out in the first chaotic week of real trades.
2. Trailpost beats the alternatives they'd otherwise use (asking in a Discord
   trade channel, a community spreadsheet, guessing in-game).
3. Posting a listing or offer in a preview where nothing changes hands still
   does something useful. It feeds the estimates, and those estimates are what
   they came for.
4. Doing nothing has a cost. If you show up to trading day with no idea of
   value, you get lowballed or you overpay.

Decision:
5. Whoever made this is a real person, it isn't a scam, and it isn't
   pretending to be official.
6. Signing in with Discord is low-risk: Trailpost only sees your Discord
   identity.
7. The coin-offer verification won't cost you anything.
8. The prices are honest: one loud trader can't set them.
9. Getting started is quick.
10. Nobody can permanently squat your WalkScape name.
11. The site protects you from the usual scams.
12. Reporting someone actually does something.
13. What you do in the preview won't be wasted when trading launches. Your
    account, name and price history carry over.
14. The site will still be around when trading launches.

## False or missing beliefs, ranked by damage

1. **"Posting in a preview is worth my time" (3).** The whole site runs on
   participation. If people browse but never post, there are no estimates, so
   there's nothing to browse. The current copy says *what* the preview is
   ("Post what you'd trade and show interest") but doesn't make the trade
   explicit: your listing is a vote in the price, and the price is the thing
   you want.
2. **"This isn't a scam" (5, 6, 7).** Discord sign-in plus "send coins to our
   bot" is exactly what a scam would ask for. Current copy has the right proof
   (the bot rejects the offer, so coins never leave), but it's buried in step 3
   of the verify screen and missing from the homepage. Discord scope isn't
   mentioned anywhere.
3. **"The prices mean something" (8, 2).** Current copy is good here: median,
   one vote per trader per day, outliers cut. It's the strongest proof on the
   site. Keep it, and say plainly why it beats "ask in #trading".
4. **"Preview work carries over" (13, 14).** Not addressed anywhere. NEED
   ANSWER (see questions).
5. **"Reports do something" (12).** Current copy *overclaims*: "A moderator will
   review it. Players with repeat reports get denylisted. Anything that breaks
   game rules is forwarded to the WalkScape devs." In the code, reports are only
   stored. There's no moderation view and no denylist (TODO.md lists the
   moderation view as unbuilt). This needs to become true or honest.
6. **"My name is safe" (10).** Covered on the claim screen ("verifying it moves
   the name to you"). Fine.
7. **"Quick to start" (9).** Covered ("Getting started takes a minute", three
   steps). Fine.
8. **"Protects me from scams" (11).** Well covered (15-minute wait, no
   countdowns, look-alike name warnings, the "Common tricks" box).

## Required beliefs, as claim and proof

| Belief needed | Claim | Proof |
| --- | --- | --- |
| Posting now is useful | Every listing and offer is a vote in the price estimate. | The item page lists each price that went into the estimate, and marks which ones were counted. |
| Better than asking in Discord | One reply in #trading is one person's guess. This is the median of everyone's. | The method: median, one vote per trader per day, outliers more than 2.5× the spread cut. |
| Not a scam / not official | Made by a WalkScape player. Not affiliated with the WalkScape team. | Elliot's name/first person (NEED OK). Footer disclaimer. |
| Discord sign-in is safe | Trailpost only sees your Discord name. | `identify` scope only, so no email, servers or messages. |
| Verification costs nothing | The bot rejects your offer, so your coins never leave. | The mechanism: trade offers in WalkScape need both sides to accept. |
| Prices are honest | No single trader can move the estimate. | The same mechanism, plus the "data health" trader count. |
| Preview work carries over | (NEED ANSWER) | |
| Reports do something | (NEED ANSWER: what actually happens today) | |

## What the current copy gets wrong

- **Overclaims on reports** (see above). This is the biggest honesty problem.
- **Hero promises what the preview can't do yet.** "Find a trade partner. Know
  the fair price." You can't trade yet. "Know the fair price" is the honest
  half.
- **Argues a future feature as a selling point.** The "Verified names, soon"
  card sells something that doesn't exist.
- **Missing ethos.** "Fan project" in the footer is the only sign of who made
  it. Readers from Elliot's post know, but Discord-link readers don't.
- **Repetition.** The banner, homepage card, listing page, trades page,
  verify screen and price page all re-explain that trading isn't live.
- **Stilted future-tense phrasing.** "arrives with trading", "comes with
  trading", "once that's live". These are fine once. Six times reads like a
  disclaimer.
- **Bare adjectives.** "Prices from real offers". In the preview they're asks
  and offers, not trades, so "real" is doing a lot of work.

## Section plan (homepage; other screens get honesty + voice passes)

1. **Hero:** lead with prices, the thing you can actually get now. CTA: sign in.
   *Serves:* 1, 3.
2. **"Why post if nothing trades?"** Say it outright: your listing is a vote, so
   more votes mean better prices for everyone on trading day. *Serves:* 3, 4.
   This is the top-ranked missing belief, so it gets its own beat.
3. **How the estimate works:** median, one vote per trader per day, outliers
   cut. Contrast with asking in Discord. *Serves:* 2, 8.
4. **Safe to try:** Discord only shares your name, and the bot never takes
   coins. No countdowns, and look-alike names get flagged. *Serves:* 5, 6, 7, 11.
5. **Getting started:** the three steps. *Serves:* 9.
6. **Who made this:** a line in Elliot's voice plus the disclaimer.
   *Serves:* 5, 14.

## Interview answers (rounds 1–2)

- **Who made it:** first person, by name, one line: "I'm Elliot, a WalkScape
  player. I built this so we'd have prices figured out before trading opens."
- **Reports/moderation:** drop the specific moderation promises. The preview
  barely needs moderation. Offensive names are the only real risk, and the
  forced verification at launch fixes that. Add a short section on moderation
  options and tradeoffs for after launch, and ask for feedback in a Discord thread.
- **Carry-over:** accounts and claimed names stay. Listings and price history
  reset at launch.
- **Hero:** lead with prices, not trade partners.
- **Being removed soon (don't rewrite):** Reports page (incl. Common tricks),
  the Verify/TrailpostBot step, and trade-room references.
- **Feedback link:** in the banner and the homepage. The Discord thread doesn't
  exist yet, so use a placeholder constant.

### What this changes in the note

- Belief 13 ("preview work carries over") resolves honestly: the account and
  name carry over, the prices don't. So belief 3 ("posting is worth it") can't
  lean on "your data builds the launch-day price". It has to stand on what you
  get *now*: a rough idea of value, and a say in how the app works.
- Belief 7 (coin verification) is moot once the verify step goes.
- Belief 12 (reports) becomes "the preview doesn't need much moderation, and
  here's how I'm thinking about it for launch".
