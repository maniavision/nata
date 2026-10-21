#!/usr/bin/env bash
# Builds a release App Bundle signed with Nata's upload key, for uploading to
# Google Play by hand (Google requires the first upload to be manual; after
# that Codemagic uploads, see codemagic.yaml).
#
#   bash scripts/build_play_bundle.sh [build-number]
#
# Reads the keystore and its passwords from ~/NataSecrets (nata-upload.jks,
# keystore_password.txt, key_alias.txt, key_password.txt), writes them to
# android/key.properties only for the build, and removes it afterwards. No
# password is printed. Output: build/app/outputs/bundle/release/app-release.aab
set -euo pipefail

SECRETS="${NATA_SECRETS:-$HOME/NataSecrets}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_NUMBER="${1:-1}"

for f in nata-upload.jks keystore_password.txt key_alias.txt key_password.txt; do
  test -s "$SECRETS/$f" || { echo "Missing $SECRETS/$f"; exit 1; }
done

PROPS="$ROOT/android/key.properties"
cleanup() { rm -f "$PROPS"; }
trap cleanup EXIT

umask 077
{
  echo "storeFile=$SECRETS/nata-upload.jks"
  echo "storePassword=$(tr -d '\r\n' < "$SECRETS/keystore_password.txt")"
  echo "keyAlias=$(tr -d '\r\n' < "$SECRETS/key_alias.txt")"
  echo "keyPassword=$(tr -d '\r\n' < "$SECRETS/key_password.txt")"
} > "$PROPS"
echo "Signing with $SECRETS/nata-upload.jks"

cd "$ROOT"
flutter build appbundle --release --build-number="$BUILD_NUMBER"

AAB="$ROOT/build/app/outputs/bundle/release/app-release.aab"
# Confirm it is signed with the upload key, not the debug key.
if jarsigner -verify -certs "$AAB" 2>/dev/null | grep -q "Android Debug"; then
  echo "Signed with the DEBUG key: Google Play will refuse it."; exit 1
fi
echo "Built $AAB"
