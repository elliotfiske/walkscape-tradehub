---
name: lamdera-deploy
description: What every agent must do before opening a PR for this Lamdera app — run lamdera check and commit any generated Evergreen migration. Use before submitting any PR, when deploying/reconciling "deploy from main" with "main is protected", or when a check reports a STALE MIGRATION or "types have changed since last deploy (vN)" while the branch already has its own src/Evergreen/V<N>.
---

# Before submitting a PR: run `lamdera check`

**Always run the check before opening a PR and commit anything it
generates.** Skipping this is the #1 way to block a deploy.

```bash
scripts/lamdera-check.sh
```

That's `lamdera check --force` with the fiddly parts handled: it works in a
Conductor worktree, and it never hangs on lamdera's "Shall I run `git add`?"
prompt. Exit 0 = passed, 3 = passed but `src/Evergreen` isn't committed yet,
1 = failed. (Running bare `lamdera check --force` without a TTY hangs at that
prompt, or exits 1 with `hGetLine: end of file` if stdin is closed, even when
the check passed.)

- `--force` runs the real **production** Evergreen check from a feature branch
  (it diffs against the *deployed* app, so the result is genuine; `--force` only
  bypasses Lamdera's "must be on main" guard).
- If your change touched any type in `Types.elm` (or anything reachable from
  `FrontendModel` / `BackendModel` / the msg types), `check` writes new files
  under `src/Evergreen/V<N>/…` plus a migration `src/Evergreen/Migrate/V<N>.elm`,
  where **N = production's version + 1 at the moment you run it**.
- **Open and finish the migration.** The generated `Migrate/V<N>.elm` often has
  `Unimplemented` placeholders — replace them so old production data migrates
  cleanly. (Only use `--destructive-migration` if you intend to drop all prod
  data.)
- **Commit the `src/Evergreen/**` files as part of this PR.** The deploy happens
  from `main` *after* merge and requires a clean tree, so the migration must
  already be committed.

If `lamdera check` reports no type changes, there's nothing to commit — proceed.

**In a cloud session (claude.ai/code):** this works the same way if the
environment has the `LAMDERA_CLI_AUTH` secret, which the SessionStart hook
writes to `~/.elm/.lamdera-cli`. If `check` says "No CLI auth", ask the user to
add that secret. Meanwhile, CI's `Evergreen` job in `tests.yml` fails the
PR if a migration is missing.

## Stale migration (production moved past your V<N>)

**Every production deploy bumps the version, even when no types changed**, and
every merge to `main` deploys. So if anything merges while your PR is open,
your `V<N>` now names a deployed version that has *other* types. Your migration
is stale.

How you'll see it:

- `scripts/evergreen-version-check.sh` (pre-push hook, CI `Evergreen` job,
  `deploy.sh`) prints **STALE MIGRATION**. CI re-runs it on every open PR after
  each deploy, so a PR that was green can turn red without a push.
- `lamdera check` says types changed "since last deploy (v<N>)" and generates
  `V<N+1>` **while your branch already has its own `V<N>`**.

**Don't finish that generated `V<N+1>`.** Lamdera treats your `V<N>` as deployed
history, so `V<N+1>` migrates from your new types to your new types. It
typechecks and passes `lamdera check`, and in production it would read data
that never had `V<N>`'s types. Delete it and renumber instead:

```bash
git fetch origin && git merge origin/main   # the branch must be up to date
scripts/regen-migration.sh                  # renumbers, then runs the check
git add -A src/Evergreen && git commit -m "Renumber Evergreen migration to V<N+1>"
```

`regen-migration.sh` finds the stale version and works out what to do:

- **Trunk gained no migration since yours** (the usual case: the deploys in
  between were type-neutral). It `git mv`s `V<N>` → `V<N+1>` and renumbers the
  `Evergreen.V<N>` references inside, so **your hand edits carry over
  unchanged**. It also moves aside an untracked `V<N+1>` that `lamdera check`
  generated, and drops a committed one built on the stale `V<N>`.
- **Trunk gained a migration** (another PR changed types and deployed). Your
  migration starts from the wrong version, so the script removes it, lets
  lamdera generate a fresh one, and prints where it saved the old file
  (`.git/…/evergreen-regen/<time>/V<N>.elm`). Port your hand edits across,
  then run `scripts/lamdera-check.sh` until it passes.

**If the stale migration already merged** (`main`'s Deploy run failed with
"UNIMPLEMENTED MIGRATION … since last deploy", or the version check says
"already on origin/main"), `main` can't deploy until it's fixed. Every PR's
`Evergreen` check fails too, pointing at the files on `origin/main`. Fix `main`
first: branch off `origin/main`, run `scripts/regen-migration.sh`, then PR and
merge that.

The rule behind all of this (`scripts/evergreen-version-check.sh`): every
`src/Evergreen` file that differs from the **deployed commit** must be version
production+1. Production's version comes from `https://<app>.lamdera.app/_i`.
The deployed commit is `lamdera/main` in `deploy.sh`, and the `deployed` branch
on GitHub (pushed by `deploy.sh` after each deploy) everywhere else. Neither
needs a Lamdera login. `bash scripts/test-evergreen.sh` exercises the
scenarios.

## Why this is needed (context)

- Production deploys run from **`main`** (`lamdera deploy` ≡
  `lamdera check && git push lamdera main`). Any other branch makes a throwaway
  preview app with a separate backend.
- GitHub `main` is **protected** — changes land only via an approved PR, never a
  direct/force push.
- The `lamdera deploy` push targets the **`lamdera` remote**
  (`apps.lamdera.com`), *not* GitHub, so the two restrictions don't actually
  collide — they're separate remotes.

Net effect: migrations must ride in through the normal PR, so they're committed
on `main` by the time someone deploys. Hence: **generate + commit the migration
in your PR.**

## Deploy (automatic after merge)

Merging to `main` triggers `.github/workflows/deploy.yml`, which runs
`npm run deploy` on CI, then re-runs the Tests workflow on every open PR so
their `Evergreen` check sees the new production version. Every PR push also
deploys a preview to one of five fixed slots, `<app>-pr-{a..e}.lamdera.app`
(`.github/workflows/preview.yml`; see "Preview slots" in CLAUDE.md).
The steps below are the manual fallback.

## Manual deploy

From the **primary checkout** (the main clone — not a Conductor
worktree, where lamdera can't run):

```bash
npm run deploy
```

`scripts/deploy.sh` enforces the invariant that local `main` is only ever a
mirror of `origin/main`, so a deploy can't leave `main` inconsistent. It will
**hard-stop** (before pushing anything) if:

- run from a linked worktree (lamdera needs the primary checkout),
- not on `main`, or the working tree is dirty,
- local `main` has commits not on `origin/main` (→ you committed to main
  directly; move them to a branch + PR),
- an undeployed Evergreen file isn't numbered production+1 (→ stale migration;
  see above),
- `lamdera check` fails or generates uncommitted Evergreen files (→ a migration
  skipped the PR flow; commit it via a PR first).

Otherwise it fast-forwards `main` to `origin/main`, runs `lamdera deploy`, and
moves the `deployed` branch, leaving `main`, `origin/main`, `origin/deployed`
and `lamdera/main` all on the same commit.
