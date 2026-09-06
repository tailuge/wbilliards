# Billiards → TWA (Android) prep instructions

Goal: ship the billiards PWA as an Android app via a Trusted Web Activity (TWA), wrapped with Bubblewrap.

## Decisions made

- The web app will be served from **`https://billiards.tailuge.workers.dev`** (the Cloudflare Workers origin that mirrors this repo's `dist/`).
- Bubblewrap / Android signing lives in a **separate, private repo: `wbilliards`** — keep signing material out of the public, open-source `billiards` repo.
- Only the generated **`assetlinks.json`** (public info: package name + SHA-256 fingerprint) is copied back into the `billiards` repo, at **`dist/.well-known/assetlinks.json`**, because the site must serve it at `https://billiards.tailuge.workers.dev/.well-known/assetlinks.json`.

## Terminology

- The file is **`assetlinks.json`** (Digital Asset Links), not "assets.json".
- Bubblewrap is a global/npx CLI — it adds **no** dependencies to either repo.

## Verified facts (checked 2026-09-06)

- `https://billiards.tailuge.workers.dev/manifest.json` serves exactly the content of this repo's `dist/manifest.json` → the CF origin mirrors `dist/`.
- `https://billiards.tailuge.workers.dev/.well-known/assetlinks.json` currently returns **404** (nothing hosted yet).
- The origin rewrites `lobby.html` → `307 /lobby`. Harmless for TWA (same-origin redirect), but `bubblewrap init` will record `startUrl: /lobby.html`.
- `dist/manifest.json` is TWA-ready: 192/512 icons, `512 maskable`, `display: standalone`, scope + start_url (`./lobby.html`).
- Only `dist/lobby.html` links the manifest and registers `sw.js`. Fine for the app entry; pages navigated to inside the app (e.g. `index.html`) aren't SW-controlled (non-blocking).
- The `billiards` repo has **no wrangler/Cloudflare config** and its CI (`.github/workflows/main.yml`) deploys only to **GitHub Pages**. Whatever pipeline feeds `billiards.tailuge.workers.dev` is external — it must pick up new `dist/` files and must **not ignore dot-directories** (`.well-known`).

## Prerequisites (on the machine doing the first build)

- Node.js (14.15+)
- JDK 17 and Android command-line tools, OR just use Bubblewrap's auto-download, OR use the prebuilt container `ghcr.io/googlechromelabs/bubblewrap:latest` (has everything installed) — ideal for CI.
- `npm i -g @bubblewrap/cli`

## Step-by-step

### 1. Create the `wbilliards` repo (private)

Holds:
- `twa-manifest.json` (no passwords in it — only keystore path + alias)
- the GitHub Actions workflow
- Android build outputs (APK/AAB)

Must **never** be committed anywhere public:
- `android.keystore` — the signing secret. Keep it out of git; store locally + encrypted backup (e.g. password manager).

### 2. Initialize the TWA project

```bash
bubblewrap init --manifest=https://billiards.tailuge.workers.dev/manifest.json
```

- Reads the live manifest; prompts for app name, package ID (e.g. `dev.tailuge.billiards`), version, and signing key details.
- Generates the signing keystore, `twa-manifest.json`, and records the key fingerprint.
- Commit `twa-manifest.json`; add keystore + passwords to the repo as Actions secrets (`TWA_KEYSTORE_B64`, `TWA_KEYSTORE_PASSWORD`, `TWA_KEY_PASSWORD`).

### 3. Build

```bash
bubblewrap build
```

Outputs (in the project dir):
- `app-release-signed.apk` — testable / sideloadable
- `app-release-bundle.aab` — upload to Play
- `assetlinks.json` — the file to publish on the site

Passwords in CI: env vars `BUBBLEWRAP_KEYSTORE_PASSWORD` and `BUBBLEWRAP_KEY_PASSWORD` (docs: "allows running `build` as part of a continuous integration").

Example workflow (fits in the `wbilliards` repo):

```yaml
name: Build Android TWA
on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - name: Restore signing keystore
        run: echo "${{ secrets.TWA_KEYSTORE_B64 }}" | base64 -d > android.keystore
      - name: Bubblewrap build
        run: docker run --rm -v "$(pwd)":/app -w /app \
            -e BUBBLEWRAP_KEYSTORE_PASSWORD="${{ secrets.TWA_KEYSTORE_PASSWORD }}" \
            -e BUBBLEWRAP_KEY_PASSWORD="${{ secrets.TWA_KEY_PASSWORD }}" \
            ghcr.io/googlechromelabs/bubblewrap:latest build
      - name: Upload APK + AAB
        uses: actions/upload-artifact@v7
        with:
          name: twa-release
          path: |
            app-release-signed.apk
            app-release-bundle.aab
```

### 4. Publish `assetlinks.json` on the site

1. Copy the generated `assetlinks.json` into the `billiards` repo: **`dist/.well-known/assetlinks.json`**
2. Commit + deploy so it is served at `https://billiards.tailuge.workers.dev/.well-known/assetlinks.json`
3. Verify:

```bash
curl -sI https://billiards.tailuge.workers.dev/.well-known/assetlinks.json   # expect 200
```

4. Validate ownership:

```bash
curl "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://billiards.tailuge.workers.dev&relation=delegate_permission/common.handle_all_urls"
```

Should return the package name + fingerprint.

### 5. Test on a device

```bash
bubblewrap install        # or: adb install app-release-signed.apk
```

Until step 4 is live and verified, the app opens as a **Custom Tab with the URL bar** — that is asset-links verification failing, not a code bug.

## Automation guidance

- Do **not** automate copying `assetlinks.json` into the site repo (cross-repo PR/PAT overhead). It changes almost never (only when package name or signing key changes). Add a one-line reminder in `wbilliards`'s README instead: "regenerate → copy to the site repo at `dist/.well-known/assetlinks.json`".
- Rebuild the APK only for Play releases (bump `appVersionCode` in `twa-manifest.json`), not on every code push — the TWA serves live web content.
- Optional later: `bubblewrap play publish` (service account) to upload the AAB to Play from CI.

## Play App Signing gotcha

The `assetlinks.json` generated from your keystore is correct for **sideloaded** builds. When you publish to Play, Play re-signs the app with **its own** app-signing key, so Play-installed users will fall back to a browser tab unless you:

1. After first upload, copy Play's app-signing SHA-256 (Play Console → Setup → App signing).
2. Add it to the fingerprint list in `wbilliards` (`bubblewrap fingerprint add <SHA-256>`).
3. Regenerate and re-copy `assetlinks.json` into `dist/.well-known/` (both fingerprints can coexist in the array).

## Notes / optional follow-ups

- Consider changing the manifest `start_url` to `/lobby` to skip the `lobby.html` → 307 redirect at app launch.
- Decide whether `billiards` should keep its own copy of the workflow: public repos get free Actions minutes, but any write-access collaborator could exfiltrate repo secrets via a workflow — a separate private repo avoids that surface. That was the chosen option.
