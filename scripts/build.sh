#!/bin/bash
# Builds Pastlog.app into dist/. Pass --install to copy it to /Applications and launch it.
# Pass --snapshots to render theme previews into dist/snapshots.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="$HOME/Library/Caches/Pastlog-build"
APP="$ROOT/dist/Pastlog.app"
cd "$ROOT"

echo "▸ Building (release)…"
swift build -c release --product Pastlog --scratch-path "$SCRATCH" 2>&1 | grep -E "error|warning: unre" || true
BIN="$(swift build -c release --product Pastlog --scratch-path "$SCRATCH" --show-bin-path)/Pastlog"
[ -x "$BIN" ] || { echo "Build failed"; exit 1; }

echo "▸ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts"
cp "$BIN" "$APP/Contents/MacOS/Pastlog"
cp "$ROOT/scripts/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT"/Resources/Fonts/*.ttf "$ROOT"/Resources/Fonts/*.txt "$APP/Contents/Resources/Fonts/"

echo "▸ Rendering icon"
TMP="$(mktemp -d)"
"$BIN" --render-icon "$TMP/icon.png" --art "$ROOT/Resources/Icon/AppIcon-art.png"
ICONSET="$TMP/AppIcon.iconset"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$TMP/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$TMP"

echo "▸ Signing"
# A stable signing identity keeps macOS privacy grants (Accessibility) valid across rebuilds.
# Override with PASTLOG_SIGN_IDENTITY; falls back to ad-hoc signing if the identity is missing.
SIGN_ID="${PASTLOG_SIGN_IDENTITY:-Pastlog Local Signing}"
if security find-identity -p codesigning 2>/dev/null | grep -q "\"$SIGN_ID\""; then
  codesign --force --deep --sign "$SIGN_ID" "$APP" >/dev/null 2>&1
  echo "Signed with \"$SIGN_ID\""
else
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1
  echo "Signed ad-hoc (Accessibility must be re-granted after each rebuild)"
fi

if [[ " $* " == *" --snapshots "* ]]; then
  echo "▸ Rendering theme snapshots"
  "$APP/Contents/MacOS/Pastlog" --snapshot "$ROOT/dist/snapshots" --fonts "$ROOT/Resources/Fonts"
fi

if [[ " $* " == *" --install "* ]]; then
  echo "▸ Installing to /Applications/Pastlog.app"
  for pid in $(pgrep -x Pastlog || true); do kill "$pid"; done
  sleep 0.5
  rm -rf /Applications/Pastlog.app
  ditto "$APP" /Applications/Pastlog.app
  open /Applications/Pastlog.app
fi
echo "✓ Done"
