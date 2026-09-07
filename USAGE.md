# Usage

## How it works

The APK/AAB is a thin TWA (Trusted Web Activity) shell that opens the deployed site fullscreen — game code is served live from the web, nothing is bundled at build time. That's why the [build workflow](.github/workflows/build.yml) is **manual** (`workflow_dispatch`): re-run it only when `twa-manifest.json` changes (icons/name/start URL) or when cutting a new Play release (`appVersionCode` bump).

## First-time setup

```bash
./scripts/init.sh     # needs Docker
```

This runs `bubblewrap init` against the live manifest in a scratch directory, then copies back `android.keystore` (gitignored) and a regenerated `twa-manifest.json`.

> **⚠️ Password trap (read before the prompts):** init asks for *two* passwords — `Password for the Key Store:` and `Password for the Key:` — but `keytool` **ignores the second one for PKCS12 keystores** (the default since JDK 9). The private key is protected only by the **keystore** password. Type the **same password at both prompts**, and use that one value for both password secrets below. A different "key" password will make the CI build fail with `apksigner: Failed to obtain key ... Wrong password?` (see [bubblewrap#693](https://github.com/GoogleChromeLabs/bubblewrap/issues/693)).

Then:

1. **Review + commit the manifest**: `git diff -- twa-manifest.json` — check `packageId` (`dev.tailuge.billiards`), `signingKey.alias`, and that `signingKey.path` is `android.keystore` with a `fingerprints` entry. Commit it.
2. **Back up the keystore now** (encrypted, e.g. password manager). `android.keystore` is never committed; losing it means you can never update the published app.
3. **Add repo secrets** (Settings → Secrets and variables → Actions):

   | Secret | Value |
   | --- | --- |
   | `TWA_KEYSTORE_B64` | `base64 -w0 android.keystore` (macOS: `base64 android.keystore \| tr -d '\n'`) |
   | `TWA_KEYSTORE_PASSWORD` | the password you entered at init |
   | `TWA_KEY_PASSWORD` | **the same password** — PKCS12 has no separate key password |

4. **Build**: Actions → *Build Android TWA* → Run workflow → download the `twa-release` artifacts:
   - `app-release-signed.apk` — sideload and test
   - `app-release-bundle.aab` — upload to the Play Console
   - `assetlinks.json` — publish next

No Docker? `npm i -g @bubblewrap/cli`, run `bubblewrap init --manifest=https://billiards.tailuge.workers.dev/manifest.json` in a scratch dir, copy the two files out, then follow the same steps.

## Publishing

### assetlinks.json (makes the app open fullscreen)

Copy `assetlinks.json` into the `billiards` repo at `dist/.well-known/assetlinks.json`, push, and verify it's served:

```bash
curl -sI https://billiards.tailuge.workers.dev/.well-known/assetlinks.json   # expect 200
curl "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://billiards.tailuge.workers.dev&relation=delegate_permission/common.handle_all_urls"
```

The second command should return your package name + fingerprint. Until it resolves, the app opens in a Custom Tab **with the URL bar** — that's verification failing, not a code bug. (The external mirror of `dist/` must pick up new files and must not ignore `.well-known`.)

### Play releases

1. Bump `appVersionCode` in `twa-manifest.json`, commit, run the workflow.
2. **Play App Signing gotcha:** Play re-signs with its own key, so after the first upload add Play's app-signing SHA-256 (Play Console → Setup → App signing) alongside the first (`bubblewrap fingerprint add <SHA-256>`), regenerate `assetlinks.json`, and update the copy in the `billiards` repo — both fingerprints coexist.

## Security model (public repo)

No secrets live in the repo. The keystore and passwords exist only as **GitHub Actions secrets**, exposed to the runner as masked env vars: never available to fork PRs, and `workflow_dispatch` requires write access. The workflow runs with `permissions: contents: read`. Keep the write-access list small, require PR review (especially for workflow-file changes), and note that build logs and artifacts are public like the app itself.
