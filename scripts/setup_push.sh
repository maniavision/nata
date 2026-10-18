#!/usr/bin/env bash
# Sets up push notifications (20240155_push_notifications.sql, send-push):
#   1. Connects the app to the Firebase project (flutterfire configure):
#      writes ios/Runner/GoogleService-Info.plist and
#      android/app/google-services.json, for iOS com.nata.nataApp and
#      Android com.carrywise.carrywise_app.
#   2. Stores the Firebase service account (the JSON file you download from
#      Firebase console > Project settings > Service accounts > Generate new
#      private key) as the FCM_SERVICE_ACCOUNT secret. The file isn't kept.
#   3. Deploys send-push.
#
# Also needed, by hand (Apple developer account):
#   * Apple Developer > Identifiers > com.nata.nataApp: enable Push
#     Notifications, then make a new provisioning profile for Codemagic.
#   * Apple Developer > Keys: create an APNs key (.p8) and upload it in
#     Firebase console > Project settings > Cloud Messaging > Apple app.
#
#   bash scripts/setup_push.sh <firebase-project-id> <service-account.json>
set -euo pipefail

PROJECT_REF="${PROJECT_REF:-xnzredskhxfgywggetzw}"
FIREBASE_PROJECT="${1:?Firebase project id, e.g. nata-app}"
SERVICE_ACCOUNT="${2:?Path to the service account JSON file}"

cd "$(dirname "$0")/.."

if [ ! -f "$SERVICE_ACCOUNT" ]; then
  echo "No file at $SERVICE_ACCOUNT" >&2
  exit 1
fi
if ! python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["type"]=="service_account" and d["private_key"]' "$SERVICE_ACCOUNT" 2>/dev/null; then
  echo "That doesn't look like a Firebase service account JSON." >&2
  exit 1
fi

FLUTTERFIRE="$(command -v flutterfire || echo "$HOME/.pub-cache/bin/flutterfire")"
if [ ! -x "$FLUTTERFIRE" ]; then
  dart pub global activate flutterfire_cli >/dev/null
fi

echo "1/3 Connecting the app to Firebase ($FIREBASE_PROJECT)"
"$FLUTTERFIRE" configure \
  --project="$FIREBASE_PROJECT" \
  --platforms=ios,android \
  --ios-bundle-id=com.nata.nataApp \
  --android-package-name=com.carrywise.carrywise_app \
  --yes

echo "2/3 Storing the service account as FCM_SERVICE_ACCOUNT"
tmp=$(mktemp)
chmod 600 "$tmp"
trap 'rm -f "$tmp"' EXIT
python3 - "$SERVICE_ACCOUNT" "$tmp" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
open(sys.argv[2], "w").write("FCM_SERVICE_ACCOUNT=" + json.dumps(d, separators=(",", ":")) + "\n")
PY
supabase secrets set --project-ref "$PROJECT_REF" --env-file "$tmp" >/dev/null

echo "3/3 Deploying send-push"
supabase functions deploy send-push --project-ref "$PROJECT_REF" --use-api

echo
echo "Done. Delete $SERVICE_ACCOUNT from this computer when you no longer need it."
