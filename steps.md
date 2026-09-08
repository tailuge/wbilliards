# Steps: Get Billiards into the Obtainium app catalog

Goal: have `dev.tailuge.billiards` listed on [apps.obtainium.imranr.dev](https://apps.obtainium.imranr.dev) so users can install/track the app with one tap.

Key facts up front:

- **No registration anywhere.** The catalog is a static site backed by the GitHub repo [`ImranR98/apps.obtainium.imranr.dev`](https://github.com/ImranR98/apps.obtainium.imranr.dev). Contributing = a normal GitHub PR with your existing account. Users need no account either.
- **Order matters: fix the repo first, PR second.** Reviewers will test that the latest release actually installs via Obtainium.
- Everything below happens in the GitHub UI / on an Android phone. No local build is required (the APK is built in GitHub Actions).

---

## Phase 0 — Repo readiness (this repo: `tailuge/wbilliards`)

Already done in the working tree — commit and push:

- [ ] `.github/workflows/build.yml` — tag-driven versioning (`versionName` = tag, `versionCode` = commit count) **and the fix for the missing APK rename step** (`app-release-signed.apk` → `Billiards.apk`). This is why the current v1.0.1 release only has the `.aab`: the workflow referenced `Billiards.apk` but nothing renamed the file bubblewrap produces.
- [ ] `scripts/bump-version.js` — optional local helper, prints release checklist.
- [ ] `twa-manifest.json` — `appVersionName` = `1.0.0`.
- [ ] `obtainium.json` — catalog metadata (single source of truth for the PR content; schema verified against real catalog entries).
- [ ] `README.md` / `USAGE.md` — new APK name + Obtainium sections.

```bash
git add -A && git commit -m "Obtainium prep: tag-driven versioning, fixed Billiards.apk asset name, catalog metadata"
git push origin main
```

## Phase 1 — Publish a release that contains `Billiards.apk`

The current [v1.0.1 release](https://github.com/tailuge/wbilliards/releases) is missing the APK (only `app-release-bundle.aab` + `assetlinks.json` were uploaded). Fix without cutting a new version:

- [ ] 1.1 Go to **Actions → Build Android TWA → Run workflow**, set `release_tag` = `v1.0.1`, run it on `main` (which now has the rename fix). The run re-attaches assets to the existing `v1.0.1` release; `versionCode` is recomputed from the same commit, so nothing drifts.
- [ ] 1.2 Confirm the release now shows exactly:

  | Asset | |
  |---|---|
  | `Billiards.apk` | ← required for Obtainium |
  | `app-release-bundle.aab` | Play only, ignored by Obtainium |
  | `assetlinks.json` | for the PWA repo |
  | Source code (zip/tar.gz) | auto, harmless |

- [ ] 1.3 Sanity-check the stable URL Obtainium will use:

  ```bash
  curl -sIL https://github.com/tailuge/wbilliards/releases/latest/download/Billiards.apk | grep -iE '^(HTTP|content-(type|length))'
  # expect: 302 -> 200, content-type: application/vnd.android.package-archive (or octet-stream), size > 1 MB
  ```

(Alternatively cut `v1.0.2` instead of re-running v1.0.1 — but then delete the stale v1.0.1 APK-less release or mark it clearly, so "latest" always points at a good one. Re-running is simpler.)

## Phase 2 — Verify with Obtainium before the PR

Reviewers will try this; do it first so the PR is known-good.

- [ ] 2.1 Install [Obtainium](https://github.com/ImranR98/Obtainium/releases) on an Android device.
- [ ] 2.2 In Obtainium: **Add App** → paste `https://github.com/tailuge/wbilliards` → it should detect the GitHub source and list `v1.0.1` with `Billiards.apk` → install.
- [ ] 2.3 Confirm: app installs (versionName `1.0.1`), opens the game fullscreen (no URL bar — depends on the `assetlinks.json` already deployed in the billiards repo), and updates are detected when a future release lands.

## Phase 3 — Pre-PR due diligence (required by their APP_CRITERIA.md)

- [ ] 3.1 Search [apps.obtainium.imranr.dev](https://apps.obtainium.imranr.dev) for "Billiards" — confirm not already listed.
- [ ] 3.2 Search **open AND closed** issues *and* PRs in `ImranR98/apps.obtainium.imranr.dev` for `billiards`, `wbilliards`, `dev.tailuge.billiards` — if a past request was declined, read why before proceeding.
- [ ] 3.3 Criteria check: official source ✅ (you own both the PWA `tailuge/billiards` and the wrapper `tailuge/wbilliards` — state this explicitly in the PR, since "wrappers" can look like forks); package name `dev.tailuge.billiards` and display name `Billiards` are distinct from any other app ✅; stable releases only, defaults everywhere ✅.

## Phase 4 — Create the config file in a fork

- [ ] 4.1 Fork `ImranR98/apps.obtainium.imranr.dev` with the GitHub UI (uncheck "Copy the main branch only" is irrelevant here; main-only is fine).
- [ ] 4.2 In your fork, create **`public/data/apps/simple/dev.tailuge.billiards.json`** (exactly this path — files elsewhere are not loaded; `simple/` because it's a plain GitHub source with default settings) with this exact content:

  ```json
  {
    "config": {
      "id": "dev.tailuge.billiards",
      "url": "https://github.com/tailuge/wbilliards",
      "author": "tailuge",
      "name": "Billiards"
    },
    "icon": "https://billiards.tailuge.workers.dev/assets/icon-512.png",
    "categories": [
      "games",
      "sports_and_health"
    ],
    "description": {
      "en": "Free multiplayer lobby for Billiards. Find matches, challenge players, and play realistic pool online. Official Trusted Web Activity wrapper for billiards.tailuge.workers.dev — the app is a thin shell that opens the live game fullscreen."
    }
  }
  ```

  Schema notes (verified against real entries like `com.beemdevelopment.aegis.json`): `config` needs at least `id`/`url`/`author`/`name`; `description` is an **object** with an `en` key (not a string); `categories` must be slugs from the repo's `public/data/categories.json` (`sports` alone doesn't exist — use `sports_and_health`); `icon` sits at the top level, not inside `config`.

## Phase 5 — Open the PR

- [ ] 5.1 Branch name e.g. `add-billiards`, then **Contribute → Open pull request** against `ImranR98/apps.obtainium.imranr.dev:main`.
- [ ] 5.2 PR title: `Add Billiards (dev.tailuge.billiards)`
- [ ] 5.3 PR body — include at minimum:

  ```markdown
  APK link: https://github.com/tailuge/wbilliards/releases/latest/download/Billiards.apk
  Source: https://github.com/tailuge/wbilliards (official Trusted Web Activity wrapper,
  maintained by the author of the PWA at https://billiards.tailuge.workers.dev —
  same owner, so this is the official source, not a third-party repackage).

  Tested with Obtainium: app detected from the GitHub source, v1.0.1 installs and
  launches the game fullscreen. Simple config, default settings, stable releases only.
  Searched existing issues/PRs — no prior request for this app.
  ```

- [ ] 5.4 Watch CI on the PR (the repo validates config JSON) and respond to review comments. If asked to change categories/name, update **both** the PR and this repo's `obtainium.json` so they stay in sync.

## Phase 6 — After merge

- [ ] 6.1 Confirm the app appears at apps.obtainium.imranr.dev (search "Billiards").
- [ ] 6.2 Share the one-tap link (site redirect form):

  ```
  https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/%7B%22id%22%3A%22dev.tailuge.billiards%22%2C%22url%22%3A%22https%3A%2F%2Fgithub.com%2Ftailuge%2Fwbilliards%22%2C%22author%22%3A%22tailuge%22%2C%22name%22%3A%22Billiards%22%7D
  ```

- [ ] 6.3 Add it (or the plain `obtainium://app/{...}` deep link) to README.md, and tick off the "after the catalog PR merges" note in the Install section.
- [ ] 6.4 Update `obtainium.json` here if anything changed during review (name/description/categories).

## Ongoing (no action needed per release)

- Releases stay tag-driven: `node scripts/bump-version.js vX.Y.Z` (optional) → commit → tag → run the workflow. `versionCode` = commit count, so it strictly increases and Obtainium offers updates automatically.
- Never rename or remove `Billiards.apk` from releases — the catalog entry and the `/releases/latest/download/Billiards.apk` URL depend on the fixed name.
- Only touch the catalog config again if the source repo moves, the icon URL dies, or you want a description/category change (small PR to your file in their repo).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Release has `.aab` but no APK | Workflow ran before the rename fix was pushed — re-run (Phase 1.1). |
| Obtainium finds no releases | Release is draft/prerelease, or no `.apk` asset — check both. |
| Install blocked / opens with URL bar | `assetlinks.json` not deployed/updated in the billiards repo `dist/.well-known/` — see USAGE.md. |
| PR CI fails on JSON | Path must be `public/data/apps/simple/<package>.json`; validate JSON; categories must exist in their `categories.json`. |
| Icon missing on the site | `https://billiards.tailuge.workers.dev/assets/icon-512.png` must stay live (checked: HTTP 200). |
| Update not offered after new release | `versionCode` didn't increase — check the Actions run stamped the new commit count. |
