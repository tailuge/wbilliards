# wbilliards

Android TWA (Trusted Web Activity) wrapper for the billiards PWA, built with
[Bubblewrap](https://github.com/GoogleChromeLabs/bubblewrap).

- Web app: https://billiards.tailuge.workers.dev (mirrors `dist/` of the public
  [tailuge/billiards](https://github.com/tailuge/billiards) repo). Main page is `lobby.html`.
- This repo is **private on purpose**: it holds the Android signing configuration
  (`twa-manifest.json`) and the signing keystore (as Actions secrets). The public
  `billiards` repo only ever receives the generated `assetlinks.json`.
- The APK/AAB is a thin shell that opens the deployed site fullscreen. Game code
  is served live from the web - nothing is bundled and nothing is cloned at build
  time. That is why the build is **manual** (`workflow_dispatch`): rebuild only
  when wrapper config changes (icons/name/start URL) or for a new Play release.

## Contents

| File | Purpose |
| --- | --- |
| `twa-manifest.json` | Bubblewrap config: package id, host, icons, signing alias/versions, fingerprints. **Draft until the one-time bootstrap replaces it.** |
| `.github/workflows/build.yml` | The only automation: regenerates the Android project from `twa-manifest.json` and builds signed APK + AAB in the official Bubblewrap container. |
| `scripts/init.sh` | One-time bootstrap helper (see below). |
| `.gitignore` | Keeps keystore, generated Android project and build outputs out of git. |

`android.keystore` is never committed. Keep an encrypted backup (e.g. password
manager) - losing it means you can never update the published app.

## One-time bootstrap (run once, on your machine)

```bash
./scripts/init.sh
```

This runs `bubblewrap init` against the live manifest in a scratch directory
(needs Docker), then copies two files back here:

- `android.keystore` (gitignored - back it up!)
- `twa-manifest.json` - **review `git diff`, then commit it**

When init prompts, use:

- App/package id: `dev.tailuge.billiards`
- Signing key alias: `billiards` (must match what the generated manifest records)
- Version: `1.0.0` / version code `1`

No Docker? `npm i -g @bubblewrap/cli`, run `bubblewrap init --manifest=https://billiards.tailuge.workers.dev/manifest.json` in a scratch dir, copy the two files out.

Then add three **repo secrets** (Settings → Secrets and variables → Actions):

| Secret | Value |
| --- | --- |
| `TWA_KEYSTORE_B64` | `base64 -w0 android.keystore` (macOS: `base64 android.keystore \| tr -d '\n'`) |
| `TWA_KEYSTORE_PASSWORD` | keystore password entered at init |
| `TWA_KEY_PASSWORD` | key password entered at init |

## Build

Actions tab → **Build Android TWA** → Run workflow → download the `twa-release`
artifacts:

- `app-release-signed.apk` — sideload and test on a device
- `app-release-bundle.aab` — upload to the Play Console
- `assetlinks.json` — publish on the site (next section)

## Publish assetlinks.json on the site

Until the site serves a matching `assetlinks.json`, the app opens as a Custom Tab
**with the URL bar** - that is verification failing, not a code bug.

1. Copy `assetlinks.json` into the `billiards` repo (commit + push to `master`):
   `dist/.well-known/assetlinks.json`
2. Verify it is served (the external pipeline mirroring `dist/` must not ignore dot-directories):
   ```bash
   curl -sI https://billiards.tailuge.workers.dev/.well-known/assetlinks.json   # expect 200
   ```
3. Confirm ownership resolves:
   ```bash
   curl "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://billiards.tailuge.workers.dev&relation=delegate_permission/common.handle_all_urls"
   ```
   Should return the package name + fingerprint.

Rebuild the APK/AAB **only** for Play releases, not on every code push - the TWA
serves live web content.

## Play releases

1. Bump `appVersionCode` in `twa-manifest.json`, commit, run the workflow.
2. **Play App Signing gotcha:** Play re-signs with its own key, so Play-installed
   users would fall back to a browser tab. After the first upload, copy Play's
   app-signing SHA-256 (Play Console → Setup → App signing), add it alongside the
   first (`bubblewrap fingerprint add <SHA-256>`), regenerate `assetlinks.json`,
   and update the copy in the `billiards` repo (both fingerprints coexist).

## Notes

- `startUrl` is `/lobby.html` (what init records from the live manifest). The
  origin 307-redirects to `/lobby`; harmless. Could be changed to `/lobby` later.
- The repo is GPL-3.0 (see `LICENSE`).
