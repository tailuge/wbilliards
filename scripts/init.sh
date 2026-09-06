#!/usr/bin/env bash
# One-time bootstrap: generate the TWA signing keystore and twa-manifest.json
# from the live PWA manifest, using the official Bubblewrap container.
#
#   ./scripts/init.sh [site-url]
#
# Runs in a throwaway directory (printed below and kept for inspection) so the
# generated Android project never lands in this repo. Then copies the two files
# you need back here:
#   - android.keystore   -> gitignored; back it up encrypted, never commit it
#   - twa-manifest.json  -> replaces the committed draft; review + commit it
#
# Needs Docker. Without Docker: npm i -g @bubblewrap/cli and run
#   bubblewrap init --manifest=<site-url>/manifest.json
# in a scratch directory instead, then copy the two files out the same way.
set -euo pipefail

SITE_URL="${1:-https://billiards.tailuge.workers.dev}"
BOOT_DIR="$(mktemp -d)"

echo "Scratch dir (kept, not deleted): $BOOT_DIR"
docker run --rm -it \
  -v "$BOOT_DIR":/app -w /app \
  ghcr.io/googlechromelabs/bubblewrap:latest \
  init --manifest="$SITE_URL/manifest.json"

cp "$BOOT_DIR/twa-manifest.json" .
cp "$BOOT_DIR/android.keystore" .

# The init output records the keystore's absolute path into the scratch dir.
# Normalize it to a repo-relative path so no machine-specific path is ever
# committed to a public repo (CI signs with --signingKeyPath=android.keystore
# regardless of what this field says).
if command -v python3 >/dev/null 2>&1; then
  python3 - <<'PY'
import json

with open("twa-manifest.json") as f:
    manifest = json.load(f)
manifest.setdefault("signingKey", {})["path"] = "android.keystore"
with open("twa-manifest.json", "w") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")
PY
else
  echo "warning: python3 not found - set signingKey.path to \"android.keystore\" in twa-manifest.json before committing"
fi

cat <<'EOF'

Bootstrap complete. Next steps:

1. Review twa-manifest.json (generated - it replaces the committed draft):
     git diff -- twa-manifest.json
   Check packageId, signingKey.alias, startUrl, versions and that
   signingKey.path reads "android.keystore". Commit it.

2. Add these GitHub repo secrets (Settings -> Secrets and variables -> Actions):
     TWA_KEYSTORE_B64       base64 of android.keystore:
                              base64 -w0 android.keystore        # GNU/Linux
                              base64 android.keystore | tr -d '\n'  # macOS
     TWA_KEYSTORE_PASSWORD  keystore password you entered at init
     TWA_KEY_PASSWORD       key password you entered at init

3. Run the "Build Android TWA" workflow from the Actions tab. Artifacts:
     app-release-signed.apk   sideload test
     app-release-bundle.aab   upload to Play
     assetlinks.json          copy into the billiards repo at
                              dist/.well-known/assetlinks.json
EOF
