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
| `Backend.elm` | Every `ToBackend` is re-dispatched with a timestamp (`FromFrontendAt`). A 15s `BackendTick` broadcasts listings whose 15-minute go-live delay has passed; until then a listing is only sent to its owner. |
| `Frontend.elm` | Routing, update, the app shell (header, preview banner, mobile tab bar, toast). |
| `Page/*.elm` | One module per screen: Home, SignIn (sign-in + onboarding steps), Market, Listing (offers), NewListing, Prices (index + item), Trades, Profile, Report. |
| `Ui.elm`, `Chart.elm` | Shared components (design tokens are in `tailwind.config.js`) and SVG charts. |
| `Pricing.elm` | Pure price-estimate rules: median, one vote per trader per day, outliers > 2.5× spread cut. |
| `Market.elm`, `Derived.elm` | Listing/offer rules shared by both sides, and frontend-derived values (estimates, stats, filtered market). |
| `Item.elm`, `ItemData.elm` | Item types and the catalog. `ItemData.elm` is **generated** by `python3 scripts/import-items.py` from walkscapedb.com/items (870 items; currency/lore skipped). Loot has a fixed rarity, crafted items take a quality, everything else is `Plain "Material"` etc. Only two items have our own icons. |
| `Name.elm` | WalkScape-name validation and look-alike detection. |
| `Users.elm` | Backend account helpers (sign-in, `Me`, public `Trader`). |
| `Auth.elm`, `Auth/Method/OAuthDiscord.elm` | Google (vendored lamdera/auth) + Discord OAuth. Apple is placeholder-only. |

## Preview-mode placeholders

- **Sign-in:** a provider with an empty client id in `Env.elm` (Apple always)
  falls back to a "preview account" keyed to the Lamdera session. Set
  `googleClientId`/`googleClientSecret` and `discordClientId`/`discordClientSecret`
  to turn on real OAuth (callback URL: `<origin>/login/OAuthGoogle/callback`,
  `<origin>/login/OAuthDiscord/callback`).
- **Verification:** the coin-offer-to-TrailpostBot step is shown with a real
  random amount, but "Continue unverified" skips it (`ClaimStatus.PreviewUnverified`).
  Names are first-come and shown with an UNVERIFIED tag.
- **WalkScape API** lookups (level, steps, last active) are shown as "with trading".

## Screenshot loop (`scripts/cdp-drive.js`)

With `lamdera live` running (default `BASE=http://localhost:8000`), script a
journey and read the PNGs back:

```bash
BASE=http://localhost:8011 node scripts/cdp-drive.js scripts/scenarios/smoke.json
# → /tmp/trailpost-shots/{home-desktop,market-desktop,home-mobile,signin-preview,claim,verify,done}.png
BASE=http://localhost:8011 node scripts/cdp-drive.js scripts/scenarios/seed-market.json
# 8 accounts, 10 listings, waits 16 min for go-live, then offers + screenshots
```

Each `ctx` is its own headless Chrome and Lamdera session. Always open a
`leader` ctx first that never navigates again: the dev backend lives in a tab,
and reloading the only tab drops sessions. Don't edit `src/` mid-run (hot
reload breaks open tabs), and give the first `goto` after a rebuild a long
`delay`. The dev BackendModel is in memory, so restarting `lamdera live` wipes it.

## Testing

`npm test` runs `tests/E2ETests.elm` (lamdera/program-test user journeys:
onboarding, claim errors, 15-minute go-live, offers + accept, estimates, look-alikes,
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
lamdera backend --no-colors --eval='Dict.size model.someDict' # focused query
lamdera backend --no-colors --import='import Set' \
  --eval='Set.size model.someSet'                             # extra imports
lamdera backend --repl                                        # interactive
```

- `model : Types.BackendModel` is in scope. `Dict` is imported by default;
  anything else (`Set`, your own modules, …) needs `--import='import X'`
  (repeatable).
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

## Deploying (`npm run deploy`)

Production deploys run from **`main`** on the primary checkout (not a worktree —
lamdera can't run where `.git` is a pointer file). `scripts/deploy.sh` enforces
the invariant that local `main` only ever mirrors `origin/main`, and hard-stops
before pushing if the tree is dirty, `main` has un-pushed commits, or
`lamdera check` would generate an uncommitted Evergreen migration. See the
[`lamdera-deploy`](.claude/skills/lamdera-deploy/SKILL.md) skill for the full
PR-first migration workflow — the `.githooks/pre-push` gate runs `lamdera check`
on every push so a missing migration is caught at PR time, not deploy time.

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
  `elm-review` + `npm test` on PRs, installing a **checksum-pinned** Lamdera
  compiler (bump both `LAMDERA_VERSION` and `LAMDERA_SHA256` in lockstep when
  upgrading).
- `src/Env.elm` is guarded by a pre-commit hook against secret leaks
  ([.githooks](.githooks/)).
- `elm-review` runs on file edits via a `PostToolUse` hook in
  [.claude/settings.json](.claude/settings.json).
