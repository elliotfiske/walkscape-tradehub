# Trailpost — Claude notes

Trailpost is a fan-made trading hub for WalkScape, built from the
`Trailpost Trading.dc.html` design (claude.ai/design). Trading isn't live in
WalkScape yet, so the app runs in **preview mode**: people post listings and
make offers (interest) so everyone gets a rough idea of item values. Nothing
changes hands, and there are no trade rooms yet.

## Map of the code

| Module | What lives there |
|---|---|
| `Types.elm` | All models/messages. Public identity of a trader is their claimed WalkScape name. |
| `Backend.elm` | Every `ToBackend` is re-dispatched with a timestamp (`FromFrontendAt`). A 15s `BackendTick` broadcasts listings whose 5-minute go-live delay has passed; until then a listing is only sent to its owner. |
| `Frontend.elm` | Routing, update, the app shell (header, preview banner, mobile tab bar, toast). |
| `Page/*.elm` | One module per screen: Home, SignIn (sign-in + onboarding steps), Market, Listing (offers), NewListing, Prices (index + item), Trades, Profile, Report, Admin. |
| `Ui.elm`, `Chart.elm` | Shared components (design tokens are in `tailwind.config.js`) and SVG charts. |
| `Pricing.elm` | Pure price-estimate rules: median, one vote per trader per day, outliers > 2.5× spread cut. |
| `Market.elm`, `Derived.elm` | Listing/offer rules shared by both sides, and frontend-derived values (estimates, stats, filtered market). |
| `Item.elm`, `ItemData.elm` | Item types and the catalog. `ItemData.elm` is **generated** by `python3 scripts/import-items.py` from the WalkScape Tools API (781 items, those with `canBeTraded`; ids like `iron_pickaxe`). Loot has a fixed rarity, crafted items take a quality, everything else is `Plain "Material"` etc. Materials and consumables can also be **fine**, and pet eggs (type `egg`) can be **rare** (shown in red, like the game's egg label): a listing's `Item.Variant` is `{ fine, rare, quality }`, and each variant is its own price series (`Item.priceKey`: `iron_bar`, `iron_bar/fine`, `camel_egg/rare`, `iron_pickaxe/perfect`) and price page (`/prices/iron_bar?fine=1`, `/prices/camel_egg?rare=1`). The API's `canBeFine` is true for nearly everything, so `scripts/import-items.py` keeps it only for materials and consumables. Icons are `public/icons/<id>.png`, pulled by `python3 scripts/pull-icons.py` (see below). |
| `Analytics.elm` | Typed Simple Analytics events (`Analytics.track`), sent through a port to `elm-pkg-js/analytics.js`. See "Analytics events". |
| `Name.elm` | WalkScape **character name** validation and look-alike detection. Character names are letters, digits and single spaces, 3–30 chars, where the minimum of 3 doesn't count spaces (the game's character creation caps at 30 and rejects consecutive, leading and trailing spaces, and the claim form trims the last two rather than erroring; examples from scraping the portal leaderboard, where "Slyth Inaru" is a character and `Slyth_Inaru` its portal username, shown in grey parentheses after the character when that account is public). Only ASCII letters, digits and spaces are allowed (no accents; the game's character creation confirms all of this, and compares names case-insensitively like we do); `lookalikeOf` still ignores underscores in case an older claim has one. Names go in URLs, so `Route` percent-encodes and decodes them. |
| `Users.elm` | Backend account helpers (sign-in, `Me`, public `Trader`, who's an admin). |
| `Auth.elm`, `Auth/Method/OAuthDiscord.elm` | Discord OAuth (on the vendored lamdera/auth). Discord is the only sign-in. |

## Preview-mode placeholders

- **Sign-in:** Discord only. With an empty `discordClientId` in `Env.elm` the
  button falls back to a "preview account" keyed to the Lamdera session. Set
  `discordClientId`/`discordClientSecret` to turn on real OAuth (callback URL:
  `<origin>/login/OAuthDiscord/callback`). Accounts are keyed by the Discord
  user id. Outside `Env.Production` the sign-in page also shows "Use a preview
  account instead" (`#signin-preview`), which the E2E tests and the
  screenshot scenarios use. In production with Discord configured, the
  backend refuses `PreviewSignIn` too, so it can't be used to get around
  Discord (or a ban). **Testing OAuth under `lamdera live`:**
  keep a second app tab open. The dev backend runs in a tab, so if the only tab
  leaves for discord.com the pending sign-in is lost and the callback fails.
- **Verification:** there is no verify step while trading isn't live. Claiming
  a name goes straight to the done screen (`ClaimStatus.PreviewUnverified`).
  Names are first-come and shown with an UNVERIFIED tag.
- **Feedback thread:** the "Feedback?" banner link and the home page's
  "Trailpost thread on the WalkScape Discord" both use `Ui.feedbackThreadUrl`.
- **WalkScape API** lookups (level, steps, last active) are shown as "with trading".

## Link previews and favicon

`head.html` (project root) is injected into the served page's `<head>` by
Lamdera: description, Open Graph tags for Discord/social embeds, favicon, and a
dark background so the page doesn't flash white while loading. The images are
`public/og.png` (1200×630), `public/favicon.svg` and `public/apple-touch-icon.png`.

## Analytics events

`head.html` loads Simple Analytics and a `sa_event` queue stub (so early events
aren't lost). Custom events go through `Analytics.track`, a
`Command.sendToJs` on the `analyticsEvent` port (so program-test records it in
`portRequests`). Lamdera's elm-pkg-js mechanism (`elm-pkg-js-includes.js` →
`elm-pkg-js/analytics.js`) subscribes to the port and calls `sa_event(name,
metadata)`; it does nothing if an ad blocker removed `sa_event`. To add an
event: add a constructor and its name in `Analytics.elm`, then `Analytics.track`
it in `Frontend.elm`. Names are lowercase + underscores, and metadata must never
identify a trader.

| Event | When |
|---|---|
| `signin_discord_clicked` | Discord sign-in button pressed |
| `signin_preview_confirmed` | Preview account chosen (dev and preview apps) |
| `signed_in` | `YouAre` arrives for a visitor on `/signin` or back from Discord (not on every page load) |
| `signed_out` | Sign out pressed |
| `claim_name_submitted` / `claim_name_rejected` | Claim form sent / backend refused the name |
| `onboarding_completed` | `YouAre` shows a claim where there was none (there's no dedicated claim response) |
| `listing_submit_rejected` | Listing form failed client validation |
| `listing_submitted` | Valid listing sent. Metadata: `side` (`sell`/`buy`), `itemId` |
| `listing_created` / `listing_create_failed` | Backend confirmed / refused it |
| `listing_closed`, `offer_submitted`, `report_submitted` | Those buttons pressed |

The E2E tests assert the event sequence with `trackedEvents`.

## Admin screen (`/admin`)

Admins are the Discord accounts whose username is in the comma-separated
`Env.adminDiscordUsernames` (set it in the Lamdera dashboard too, or
`lamdera check` fails with MISSING PRODUCTION CONFIG). The backend checks
`Users.isAdmin` on every `AdminLoad` / `AdminRequest`; the page only decides
what to show. Admins can resolve reports, delete listings (any state) and
offers, ban/unban players, and release a claimed name. Banning or releasing a
name deletes that player's listings and offers. A banned account can still
sign in and browse, but every other request fails. Every action is written to
`BackendModel.adminLog`.

In `Env.Development` (`lamdera live`, the E2E tests) the sign-in page also has
"Use a preview admin account" (`#signin-preview-admin`), so you can try the
admin screen without Discord. The backend refuses it in production.

## WalkScape Tools API (items and icons)

Both scripts call https://tools-api-dev.dev.walkscape.app (docs at `/docs/`;
the spec is embedded in `/docs/swagger-ui-init.js`) through
`scripts/walkscape_api.py`, and need `WALKSCAPE_DATA_API_KEY` in `.env`
(gitignored, never commit it).

- `python3 scripts/import-items.py` regenerates `src/ItemData.elm` with every
  tradeable item. Item ids end up in URLs and stored listings, so if the game
  renames one, its old listings no longer find their item.
- `python3 scripts/pull-icons.py` downloads each catalog item's icon into
`public/icons/<item id>.png`. It skips the download when the API's assets
version matches `public/icons/VERSION` (`--force` to override), and removes
icons for items no longer in the catalog. Re-run it after
`scripts/import-items.py`. The icons are committed because Lamdera serves
`public/` from git.

## Screenshot loop (`scripts/cdp-drive.js`)

With `lamdera live` running (default `BASE=http://localhost:8000`), script a
journey and read the PNGs back:

```bash
BASE=http://localhost:8011 node scripts/cdp-drive.js scripts/scenarios/smoke.json
# → ./.context/shots/{home-desktop,market-desktop,home-mobile,signin-preview,claim,done}.png
BASE=http://localhost:8011 node scripts/cdp-drive.js scripts/scenarios/seed-market.json
# 8 accounts, 10 listings, waits 6 min for go-live, then offers + screenshots
```

Each `ctx` is its own headless Chrome and Lamdera session. Chrome is found by
`scripts/find-chrome.js` (macOS Chrome, Playwright's Chromium in cloud
sessions, or `CHROME_BIN`). Always open a
`leader` ctx first that never navigates again: the dev backend lives in a tab,
and reloading the only tab drops sessions. Don't edit `src/` mid-run (hot
reload breaks open tabs), and give the first `goto` after a rebuild a long
`delay`. The dev BackendModel is in memory, so restarting `lamdera live` wipes it.

## Testing

`npm test` runs `tests/E2ETests.elm` (lamdera/program-test user journeys:
onboarding, claim errors, 5-minute go-live, offers + accept, estimates, look-alikes,
validation, reports, sign-out) and `tests/UnitTests.elm` (pricing, names, routes,
listing form). In program-test, `clickLink` needs a matching `href` in the
current view, and `pushUrl` must be given a path (not an absolute URL) or the
simulated router falls back to `/`.


## Inspecting the BackendModel (`lamdera backend`)

For reading **backend state**, prefer `lamdera backend` over CDP — it evaluates
an Elm expression against the live `lamdera live` BackendModel and prints the
result. It's **read-only** (you can't assign to `model`), deterministic, and
needs no browser, tab, or leader detection. If `lamdera live` isn't running it
falls back to the last saved BackendModel.

```bash
lamdera backend --no-colors                                   # whole model
lamdera backend --no-colors --import='import Dict' \
  --eval='Dict.size model.someDict'                           # focused query
lamdera backend --no-colors --import='import Set' \
  --eval='Set.size model.someSet'                             # extra imports
lamdera backend --repl                                        # interactive
```

- `model : Types.BackendModel` is in scope. Nothing else is imported, not even
  `Dict`: every module you use (`Dict`, `Set`, your own modules, …) needs
  `--import='import X'` (repeatable).
- Prefer a focused `--eval` over dumping the whole model — the full model can
  be large and wastes context.
- This is the right tool to verify backend effects without racing the WebSocket
  connect → first-`ToFrontend` round-trip that makes CDP flaky right after a
  reload.
- **Scoping / parallel worktrees:** the expression is compiled against the
  *current directory's* code, but the model *data* comes from the `lamdera live`
  server on `--port` (default 8000), not the directory. With multiple worktrees,
  run each `lamdera live` on its own `--port` and pass the matching `--port`
  here — otherwise the default 8000 reads whichever worktree owns that port,
  interpreted with the current dir's types (silently wrong if they've diverged).

**There is no way to *write* the BackendModel** — not via `lamdera backend`
(read-only) and not via CDP. CDP only drives the **frontend** (clicks, keydowns,
reload); those change backend state only *indirectly*, through the normal
`ToBackend` message flow. To set up backend state for a check, drive the UI —
there is no direct-mutation tool.

## Debugging frontend state via Chrome DevTools Protocol

CDP is for the **frontend**: console logs, screenshots, rendered DOM, and
triggering UI actions. For backend *model* inspection use `lamdera backend`
(above) instead.

Lamdera's official Chrome extension/MCP is blocked at the org level, so we tail
the browser console over CDP directly. This gives Claude (or anyone) read-only
access to `console.log` output without any extension.

### One-time setup

Launch a **separate** debuggable Chrome instance so your normal browser/profile
stays untouched:

```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-debug \
  http://localhost:8000
```

Run `lamdera live` as usual in another terminal.

### Worktree port: auto-detected, override with `--port`

The :9222 debug Chrome is often shared by several worktrees, each running
`lamdera live` on its own port. To avoid attaching to another worktree's tab,
the four single-target scripts (`cdp-console`, `cdp-eval`, `cdp-html`,
`cdp-screenshot`) **auto-detect this worktree's port**: they match the running
`lamdera live` process whose working directory is this worktree and use its port
(see [scripts/cdp-port.js](scripts/cdp-port.js)). You'll see
`[cdp] auto-detected this worktree's lamdera port: <n>` on stderr.

Pass `--port <n>` (or `--port=<n>`) to override — e.g. to target *another*
worktree's tab, or when detection can't decide (no `lamdera live` matches this
worktree's cwd, or several do; it prints a hint and falls back to the first
matching `localhost` tab). `cdp-tabs` doesn't auto-detect — it lists every tab
by design (use it to discover ports), and still honors `--port` to filter.

### Tailing logs

```bash
node scripts/cdp-console.js 10           # listen for 10 seconds
node scripts/cdp-console.js --port 8002 10   # pin to this worktree's port
node scripts/cdp-console.js 30 ws://...  # override tab WS URL
```

To list tabs:

```bash
node scripts/cdp-tabs.js            # compact list
node scripts/cdp-tabs.js --port 8002  # only this worktree's tabs
node scripts/cdp-tabs.js --ws       # include each tab's webSocket URL
node scripts/cdp-tabs.js --json     # machine-readable (trimmed fields)
```

CDP only streams events going forward — to capture init-time logs, reload the
page *after* the listener is running (or trigger reload via
`Runtime.evaluate { expression: "location.reload()" }`).

### Evaluating JS in a tab

```bash
node scripts/cdp-eval.js "document.title"
node scripts/cdp-eval.js "location.reload(); 'reloading'"
node scripts/cdp-eval.js "({url: location.href, ls: Object.keys(localStorage)})"
echo "(async () => { ... })()" | node scripts/cdp-eval.js -      # stdin
node scripts/cdp-eval.js --port 8002 "1+1"                        # pin worktree's port
```

Multi-statement scripts work; the last expression's value is returned. For
async, wrap in `(async () => { ... })()` — `awaitPromise` is on by default.
Objects are auto-JSON-stringified. Exceptions print to stderr with exit code 1.

### Screenshots and rendered HTML

```bash
node scripts/cdp-screenshot.js                          # → /tmp/lamdera-screenshot.png
node scripts/cdp-screenshot.js --full-page              # capture beyond viewport
node scripts/cdp-screenshot.js --out shot.png           # custom path
node scripts/cdp-html.js                                # full document → stdout
node scripts/cdp-html.js --selector '[data-testid="x"]' # outerHTML of one node
node scripts/cdp-html.js --out page.html                # write to file
node scripts/cdp-screenshot.js --port 8002              # pin worktree's port
```

Both auto-detect this worktree's port (`--port <n>` to override). The screenshot
script prints the output path on stdout so the Read tool can open the PNG
directly. Use `cdp-html.js` instead of `curl localhost:8000` when you need
post-render output — the curl response is just Lamdera's bootstrap shell.

### What Lamdera already logs for free

In dev mode, Lamdera pipes a lot of state into the browser console with no
`Debug.log` needed:

| Prefix | Meaning |
|---|---|
| `☀️ Initializing new app: "..."` | Fresh frontend init |
| `☀️ Restored BackendModel: { ... }` | Backend state snapshot on reload |
| `❇️ ReceivedBackendModel: { ... }` | Backend model sent over wire |
| `F   : <msg>` | FrontendMsg dispatched |
| `F▶️  : <msg>` | Frontend → Backend send |
| ` ▶️B : <msg>` | Backend receives ToBackend |
| `  B : <msg>` | BackendMsg dispatched |
| ` ◀️B : <msg>` | Backend → Frontend send |
| `F◀️  : <msg>` | Frontend receives ToFrontend |

So for read-only inspection of `FrontendModel` or any msg flowing through a
tab, **just attach the listener** — no source edits needed. Note the
backend-side traces (` ▶️B`, `  B`, ` ◀️B`, `Restored BackendModel`) only
surface in the leader tab's console, and the scripts attach to an arbitrary
tab — so to read backend state reliably, use `lamdera backend` from the
terminal (see the top section) rather than fishing for it in the console.

### `Debug.log` escape hatch

For values *not* in the model (e.g. mid-update derived state), add `Debug.log`
inside `update` so it fires on each msg:

```elm
update msg model =
    let _ = Debug.log "msg" msg in
    case msg of ...
```

Logging in `view` is noisier and Elm may DCE a `let _ = Debug.log ...` whose
result is unused; if that happens, bind the result and thread it into the
output (e.g. via `always`).

**Gotcha:** `lamdera live` is started manually by the user. Its cwd may be a
worktree, not the main checkout. If your `Debug.log` edit compiles on disk but
never fires in the browser, check `lsof -p $(pgrep -f 'lamdera live') | grep cwd`
and edit there instead.

## Deploying

**Production deploys are automatic:** every merge to `main` runs
[.github/workflows/deploy.yml](.github/workflows/deploy.yml), which runs
`npm run deploy` on CI. **Every PR push gets a preview app** at
`https://<app>-pr-<N>.lamdera.app` via
[.github/workflows/preview.yml](.github/workflows/preview.yml), plus a sticky
PR comment with the preview URL and screenshots. The app name lives in
`package.json` → `config.lamderaApp`. Preview apps don't run Evergreen and
reset their backend on every deploy. Discord sign-in doesn't work on previews
yet; see [TODO.md](TODO.md).

**Every deploy bumps production's Evergreen version, even with no type
changes**, and a migration is numbered production+1 when `lamdera check` runs.
So any merge can make an open PR's `src/Evergreen/V<N>` stale.
`scripts/evergreen-version-check.sh` catches that. It runs in the pre-push
hook, in the `Evergreen` job in `tests.yml` (re-run on every open PR after each
deploy), and in `deploy.sh`. Fix a stale migration with
`scripts/regen-migration.sh`, never by finishing the `V<N+1>` that `lamdera
check` generates on top of it. Run checks with `scripts/lamdera-check.sh`
(worktree-safe, never hangs on lamdera's `git add` prompt). After a
deploy, `deploy.sh` moves the `deployed` branch to the deployed commit.
Details are in the [`lamdera-deploy`](.claude/skills/lamdera-deploy/SKILL.md)
skill.

Both workflows push to `git@apps.lamdera.com` over SSH using the
`LAMDERA_SSH_KEY` repo secret. `lamdera check` uses `LAMDERA_CLI_AUTH`, the
contents of `~/.elm/.lamdera-cli`. Shared setup is in
[.github/actions/lamdera-setup](.github/actions/lamdera-setup/action.yml).

### Manual deploy (`npm run deploy`)

Manual deploys run from **`main`** on the primary checkout (not a worktree —
lamdera can't run where `.git` is a pointer file). `scripts/deploy.sh` enforces
the invariant that local `main` only ever mirrors `origin/main`, and hard-stops
before pushing if the tree is dirty, `main` has un-pushed commits, a migration
is stale, or `lamdera check` would generate an uncommitted Evergreen migration. See the
[`lamdera-deploy`](.claude/skills/lamdera-deploy/SKILL.md) skill for the full
PR-first migration workflow — the `.githooks/pre-push` gate runs `lamdera check`
on every push so a missing migration is caught at PR time, not deploy time.

## Cloud sessions (claude.ai/code)

[.claude/hooks/cloud-setup.sh](.claude/hooks/cloud-setup.sh) is a SessionStart
hook that only runs when `CLAUDE_CODE_REMOTE=true`. It installs the pinned
Lamdera binary to `~/.local/bin`, runs `npm install`, fills `~/.elm`, writes the
Lamdera CLI auth, and adds the `lamdera` remote. After it runs, `lamdera make`,
`npm test`, `npm run review`, `lamdera live`, and `lamdera backend` all work
as they do locally.

Cloud quirks to know about:

- **Elm packages:** the cloud egress proxy blocks GitHub zipball downloads for
  any repo except this one, so the compiler's own package download fails
  ("PROBLEM DOWNLOADING PACKAGE"). [scripts/elm-prefetch.js](scripts/elm-prefetch.js)
  `git clone`s every package listed in `elm.json` and `review/elm.json` into
  `~/.elm` instead, since git clones are allowed. **If you add or upgrade an Elm
  package, run `node scripts/elm-prefetch.js` first**; to install a brand-new
  one, use `node scripts/elm-prefetch.js --pkg owner/name@x.y.z`, then edit
  `elm.json`. `lamdera/*` packages come from static.lamdera.com, which works.
  elm-test-rs's runner package is listed in `EXTRA` in that script.
- **`elm` for elm-review** comes from the `@lydell/elm` devDependency. `lamdera`
  can't stand in for it, because review packages fail to build under it.
- **`lamdera check --force`** works when the cloud environment has a
  `LAMDERA_CLI_AUTH` secret env var. Without it, the pre-push hook skips the
  check and CI enforces it on the PR.
- **No pushes to Lamdera from the container:** SSH (port 22) is blocked. To
  deploy, open or push to a PR (preview) or merge it (production).
- **Screenshots:** `npm start` launches headless Playwright Chromium on Linux,
  so the `cdp-*.js` scripts work unchanged. For one-off captures without a debug
  Chrome, run `node scripts/screenshots.js --base http://localhost:<port> --out
  screenshots`. It covers every route and viewport in
  [scripts/screenshot-routes.json](scripts/screenshot-routes.json). `Read` the
  PNGs to check your own work, and send them to the user to ask for feedback.
  Add routes to that JSON as the app grows; CI uses the same list for PR
  comments.

## Running the dev server (`npm start`)

`npm start` runs [scripts/run.js](scripts/run.js), which babysits the local dev
stack: it picks free ports, does a one-shot `build:css`, starts the Tailwind and
cachebust watchers, pre-warms `elm-stuff`, launches `lamdera live` (auto-restarting
it on a crash or a known bad-state pattern), and — unless `--no-chrome` — opens a
debuggable Chrome (`:9222`+) pointed at the app (that's the CDP target the
`scripts/cdp-*.js` tools attach to). Override ports with `LAMDERA_PORT` /
`CHROME_PORT`; skip Chrome with `node scripts/run.js --no-chrome`.

## Tailwind

Tailwind v3 via the standalone CLI. Source is `src/input.css` → `public/output.css`
(served by Lamdera at `/output.css`).

```bash
npm run build:css     # one-shot
npm run watch:css     # rebuild on Elm changes
```

`public/output.css` **is committed to git** (it is *not* gitignored): Lamdera
publishes static assets from the git remote, so the built stylesheet must be
checked in for production to serve it. The pre-commit hook rebuilds and re-stages
it; if you regenerate it manually, `git add public/output.css` along with your
change.

`tailwind.config.js` scans `./src/**/*.elm` for class names — re-run the build
after adding new classes (or keep `watch:css` going alongside `lamdera live`). The
stylesheet is wired into the page by a `<link rel="stylesheet"
href="/output.css?dev=<hash>">` node in `Frontend.elm`'s `view` (a plain `<head>`
link does nothing under Lamdera). `?dev=<hash>` is a content-hash cache-buster
stamped by [scripts/cachebust.js](scripts/cachebust.js) (dev watcher + pre-commit)
from the hash of `output.css`, so the URL changes only when the CSS actually
changes. If you move the view into its own module, update `viewPath` in
`cachebust.js` and `VIEW_ELM` in `.githooks/pre-commit` to point at it.

## Other conventions

- Backlog lives in [TODO.md](TODO.md).
- E2E tests live in [tests/E2ETests.elm](tests/E2ETests.elm) and run via
  `npm test` (elm-test-rs against the lamdera compiler). The `.claude/skills/`
  directory has a `red-green-tdd` skill and a set of `testing-*` skills
  (quick-ref, user-interaction, view-assertions, http-mocking, timing,
  pitfalls) for `lamdera/program-test`.
- CI ([.github/workflows/tests.yml](.github/workflows/tests.yml)) runs
  `elm-review`, `npm test`, and `lamdera check --force` on PRs, installing a
  **checksum-pinned** Lamdera compiler via
  [scripts/install-lamdera.sh](scripts/install-lamdera.sh). That script is the
  single source of truth for the version: bump both `LAMDERA_VERSION` and
  `LAMDERA_SHA256` in lockstep when upgrading.
- `src/Env.elm` is guarded by a pre-commit hook against secret leaks
  ([.githooks](.githooks/)).
- `elm-review` runs on file edits via a `PostToolUse` hook in
  [.claude/settings.json](.claude/settings.json).
