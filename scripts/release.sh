#!/bin/bash
# Builds a universal Pastlog release that is signed with a Developer ID certificate,
# notarized by Apple, and stapled, so it opens on any Mac without a Gatekeeper warning.
#
# Output in dist/:
#   Pastlog.dmg  disk image with Pastlog and an Applications shortcut (what the website links to)
#   Pastlog.zip  zipped app, for people and tools that prefer a zip
#
# Signing identity: PASTLOG_SIGN_IDENTITY, or the first "Developer ID Application" identity
# found in your keychain.
#
# Notary credentials, either:
#   PASTLOG_NOTARY_PROFILE  a profile saved with `xcrun notarytool store-credentials`
# or an App Store Connect API key:
#   APPLE_API_KEY_PATH  path to the AuthKey_XXXXXXXXXX.p8 file
#   APPLE_API_KEY_ID    the key ID
#   APPLE_API_ISSUER    the issuer ID
#
# PASTLOG_VERSION (for example 1.1.0) sets the version. It defaults to the one in scripts/Info.plist.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Pastlog.app"
DMG="$ROOT/dist/Pastlog.dmg"
ZIP="$ROOT/dist/Pastlog.zip"
cd "$ROOT"

die() { echo "✗ $*" >&2; exit 1; }

# --- Signing identity -------------------------------------------------------------------------
if [ -z "${PASTLOG_SIGN_IDENTITY:-}" ]; then
  PASTLOG_SIGN_IDENTITY="$(security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
fi
[[ "$PASTLOG_SIGN_IDENTITY" == "Developer ID Application:"* ]] \
  || die "No Developer ID Application certificate found. Set PASTLOG_SIGN_IDENTITY or install one from developer.apple.com."
export PASTLOG_SIGN_IDENTITY

# --- Notary credentials -----------------------------------------------------------------------
if [ -n "${PASTLOG_NOTARY_PROFILE:-}" ]; then
  NOTARY=(--keychain-profile "$PASTLOG_NOTARY_PROFILE")
elif [ -n "${APPLE_API_KEY_PATH:-}" ] && [ -n "${APPLE_API_KEY_ID:-}" ] && [ -n "${APPLE_API_ISSUER:-}" ]; then
  NOTARY=(--key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER")
else
  die "No notary credentials. Set PASTLOG_NOTARY_PROFILE, or APPLE_API_KEY_PATH, APPLE_API_KEY_ID and APPLE_API_ISSUER."
fi

export PASTLOG_VERSION="${PASTLOG_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' scripts/Info.plist)}"
echo "▸ Releasing Pastlog $PASTLOG_VERSION, signed by \"$PASTLOG_SIGN_IDENTITY\""

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Sends a file to Apple's notary service, waits for the verdict and prints the log if it's rejected.
notarize() {
  echo "▸ Notarizing $(basename "$1") (this usually takes a few minutes)…"
  local out id status
  out="$(xcrun notarytool submit "$1" "${NOTARY[@]}" --wait --output-format json)" || true
  id="$(plutil -extract id raw - <<<"$out" 2>/dev/null || true)"
  status="$(plutil -extract status raw - <<<"$out" 2>/dev/null || true)"
  if [ "$status" != "Accepted" ]; then
    echo "$out" >&2
    [ -n "$id" ] && xcrun notarytool log "$id" "${NOTARY[@]}" >&2 || true
    die "Apple did not accept $(basename "$1") (status: ${status:-unknown})."
  fi
  echo "  Accepted (submission $id)"
}

# --- Build and sign ---------------------------------------------------------------------------
"$ROOT/scripts/build.sh" --universal
codesign --verify --strict --verbose=2 "$APP"
codesign --display --verbose=2 "$APP" 2>&1 | grep -q "flags=.*runtime" || die "The hardened runtime isn't enabled."

# --- Notarize and staple the app --------------------------------------------------------------
ditto -c -k --keepParent "$APP" "$WORK/Pastlog.zip"
notarize "$WORK/Pastlog.zip"
xcrun stapler staple "$APP"

rm -f "$ZIP" "$DMG"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

# --- Disk image -------------------------------------------------------------------------------
echo "▸ Creating disk image"
mkdir "$WORK/dmg"
ditto "$APP" "$WORK/dmg/Pastlog.app"
ln -s /Applications "$WORK/dmg/Applications"
hdiutil create -quiet -volname "Pastlog" -srcfolder "$WORK/dmg" -fs HFS+ -format UDZO -ov "$DMG"
codesign --force --timestamp --sign "$PASTLOG_SIGN_IDENTITY" "$DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"

# --- Check it the way Gatekeeper will ---------------------------------------------------------
echo "▸ Verifying"
spctl --assess --type execute --verbose=2 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
xcrun stapler validate "$DMG" >/dev/null

echo "✓ Pastlog $PASTLOG_VERSION is notarized:"
(cd dist && shasum -a 256 Pastlog.dmg Pastlog.zip)
