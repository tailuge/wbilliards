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
cat <<'EOF'

NOTE: the init wizard asks for TWO passwords ("Password for the Key Store:"
then "Password for the Key:"), but keytool IGNORES the second one for PKCS12
keystores (the default since JDK 9) - the private key is protected only by the
keystore password. Enter the SAME password at both prompts, and later store
that one password in BOTH GitHub secrets (TWA_KEYSTORE_PASSWORD and
TWA_KEY_PASSWORD). Using two different passwords here causes an apksigner
"Wrong password?" failure at build time (bubblewrap issue #693).
EOF
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

# Record the signing key's SHA-256 fingerprint in twa-manifest.json so CI can
# generate a valid assetlinks.json. The fingerprint is public (it is published
# in the assetlinks file), so committing it is expected - only the keystore file
# itself and the passwords stay secret.
ALIAS="$(python3 - <<'PY'
import json
print(json.load(open("twa-manifest.json"))["signingKey"]["alias"])
PY
)"
read -rsp "Keystore password (the one password you used at init): " KS_PW
echo
if [ -n "$KS_PW" ]; then
  # Keep keytool's colon-separated form (e.g. AA:BB:...): Bubblewrap's validator
  # and the assetlinks.json format both require it.
  SHA="$(docker run --rm -e KS_PW="$KS_PW" -v "$(pwd)":/app -w /app \
    --entrypoint keytool ghcr.io/googlechromelabs/bubblewrap:latest \
    -list -v -keystore android.keystore -storepass:env KS_PW -alias "$ALIAS" 2>/dev/null \
    | awk '/SHA256:/{print $2}')"
  if [ -n "$SHA" ]; then
    docker run --rm -v "$(pwd)":/app -w /app \
      ghcr.io/googlechromelabs/bubblewrap:latest fingerprint add "$SHA"
    echo "Fingerprint recorded in twa-manifest.json; assetlinks.json generated here (gitignored)."
  else
    echo "warning: could not read the keystore fingerprint (wrong password or alias '$ALIAS'?)."
    echo "Fix later with: bubblewrap fingerprint add <SHA-256-of-your-signing-cert>"
  fi
else
  echo "Skipped fingerprint recording. Fix later with: bubblewrap fingerprint add <SHA-256-of-your-signing-cert>"
fi

cat <<'EOF'

Bootstrap complete. Next steps:

1. Review twa-manifest.json (generated - it replaces the committed draft):
     git diff -- twa-manifest.json
   Check packageId, signingKey.alias, startUrl, versions and that
   signingKey.path reads "android.keystore" and fingerprints is populated.
   Commit it.

2. Add these GitHub repo secrets (Settings -> Secrets and variables -> Actions):
     TWA_KEYSTORE_B64       base64 of android.keystore:
                              base64 -w0 android.keystore        # GNU/Linux
                              base64 android.keystore | tr -d '\n'  # macOS
     TWA_KEYSTORE_PASSWORD  keystore password you entered at init
     TWA_KEY_PASSWORD       the SAME value as TWA_KEYSTORE_PASSWORD (PKCS12
                            has no separate key password - a different value
                            here fails the build with "Wrong password?")

3. Run the "Build Android TWA" workflow from the Actions tab. Artifacts:
     app-release-signed.apk   sideload test
     app-release-bundle.aab   upload to Play
     assetlinks.json          copy into the billiards repo at
                              dist/.well-known/assetlinks.json
EOF
