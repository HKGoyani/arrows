#!/usr/bin/env bash
# One-shot Android release-signing setup for Arrows.
#
# This script contains NO password. It prompts you for one at runtime, then:
#   1. generates the upload keystore (if it doesn't already exist)
#   2. writes android/key.properties with your keystore path/alias/password
#
# Run it from anywhere:  bash android/setup_signing.sh
#
# After it finishes, BACK UP the .jks file — losing it means you can never
# update the app on Google Play again.

set -euo pipefail

KEYSTORE="$HOME/arrows-upload-keystore.jks"
ALIAS="upload"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_PROPS="$SCRIPT_DIR/key.properties"

echo "Arrows — Android release signing setup"
echo "======================================"
echo "Keystore will be created at: $KEYSTORE"
echo

# --- prompt for the password (hidden input, confirmed) ---
while true; do
  read -r -s -p "Choose a keystore password: " PW1; echo
  read -r -s -p "Confirm the password:       " PW2; echo
  if [ "$PW1" != "$PW2" ]; then
    echo "  Passwords didn't match — try again."; echo
  elif [ -z "$PW1" ]; then
    echo "  Password can't be empty — try again."; echo
  else
    break
  fi
done

# --- generate the keystore (skip if it already exists) ---
if [ -f "$KEYSTORE" ]; then
  echo
  echo "A keystore already exists at $KEYSTORE — reusing it (not overwriting)."
  echo "If the password below is wrong for it, the build will fail; delete the"
  echo "file and re-run to make a fresh one."
else
  echo
  echo "Generating keystore… (you'll be asked a few identity questions —"
  echo "any reasonable answers are fine; they're just metadata)."
  keytool -genkeypair -v \
    -keystore "$KEYSTORE" \
    -storepass "$PW1" \
    -keypass "$PW1" \
    -alias "$ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10000
fi

# --- write key.properties ---
cat > "$KEY_PROPS" <<EOF
storePassword=$PW1
keyPassword=$PW1
keyAlias=$ALIAS
storeFile=$KEYSTORE
EOF

echo
echo "✓ Wrote $KEY_PROPS (gitignored)."
echo "✓ Keystore ready at $KEYSTORE"
echo
echo "IMPORTANT: back up $KEYSTORE somewhere safe (password manager / secure"
echo "cloud). If you lose it, you can never update this app on Play again."
echo
echo "Done — tell Claude to build the release AAB."
