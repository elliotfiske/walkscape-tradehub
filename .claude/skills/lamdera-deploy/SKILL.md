---
name: lamdera-deploy
description: What every agent must do before opening a PR for this Lamdera app — run lamdera check and commit any generated Evergreen migration. Use before submitting any PR, or when deploying/reconciling "deploy from main" with "main is protected".
---

# Before submitting a PR: run `lamdera check`

**Always run `lamdera check` before opening a PR and commit anything it
generates.** Skipping this is the #1 way to block a deploy.

```bash
lamdera check --force
```

- `--force` runs the real **production** Evergreen check from a feature branch
  (it diffs against the *deployed* app, so the result is genuine; `--force` only
  bypasses Lamdera's "must be on main" guard).
- If your change touched any type in `Types.elm` (or anything reachable from
  `FrontendModel` / `BackendModel` / the msg types), `check` writes new files
  under `src/Evergreen/V<N>/…` plus a migration `src/Evergreen/Migrate/V<N>.elm`.
- **Open and finish the migration.** The generated `Migrate/V<N>.elm` often has
  `Unimplemented` placeholders — replace them so old production data migrates
  cleanly. (Only use `--destructive-migration` if you intend to drop all prod
  data.)
- **Commit the `src/Evergreen/**` files as part of this PR.** The deploy happens
  from `main` *after* merge and requires a clean tree, so the migration must
  already be committed.

If `lamdera check` reports no type changes, there's nothing to commit — proceed.

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

## Deploy (for whoever ships it, after merge)

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
- `lamdera check` generates uncommitted Evergreen files (→ a migration skipped
  the PR flow; commit it via a PR first).

Otherwise it fast-forwards `main` to `origin/main` and runs `lamdera deploy`,
leaving `main`, `origin/main`, and `lamdera/main` all on the same commit.
