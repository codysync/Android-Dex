#!/usr/bin/env bash
# Rebrand an installed Android DEX bundle (macOS .app or Linux AppDir).
# Usage: ./customise.sh --name "Fold DeX" --icon icon.png /Applications/Android_Dex.app
#        ./customise.sh --name "Fold DeX" --icon icon.png ~/.local/opt/android-dex
# Bundle id is left alone so preferences and device pairings survive.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="Fold DeX"; ICON="$HERE/icon.png"
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2;;
    --icon) ICON="$2"; shift 2;;
    -*) echo "unknown flag $1" >&2; exit 2;;
    *) TARGET="$1"; shift;;
  esac
done
: "${TARGET:?target bundle required}"
[ -f "$ICON" ] || { ICON="$HERE/icon.png"; }

if [ -d "$TARGET/Contents" ]; then
  PLIST="$TARGET/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName '$NAME'" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleName string '$NAME'" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName '$NAME'" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string '$NAME'" "$PLIST"
  RES="$TARGET/Contents/Resources"
  cp "$ICON" "$RES/patch-icon.png"
  if [ -f "$HERE/icon.icns" ] && cmp -s "$ICON" "$HERE/icon.png"; then
    cp "$HERE/icon.icns" "$RES/AppIcon.icns"
  else
    python3 - "$ICON" "$RES/AppIcon.icns" <<'PY'
import sys
from PIL import Image
Image.open(sys.argv[1]).save(sys.argv[2], format="ICNS")
PY
  fi
  touch "$TARGET"
  codesign --force --deep --sign - "$TARGET" || echo "warn: ad-hoc re-sign failed" >&2
  echo "customised macOS bundle: $TARGET -> $NAME"
else
  DESK="$TARGET/Android_Dex.desktop"
  [ -f "$DESK" ] || { echo "not a DEX AppDir: $TARGET" >&2; exit 1; }
  sed -i "s/^Name=.*/Name=$NAME/; s/^Comment=.*/Comment=Self-hosted build of Android DEX/" "$DESK"
  for size in 128 256 512; do
    dir="$TARGET/usr/share/icons/hicolor/${size}x${size}/apps"
    [ -d "$dir" ] && magick "$ICON" -resize "${size}x${size}" "$dir/Android_Dex.png"
  done
  VJ="$TARGET/usr/share/Android_Dex/data/flutter_assets/version.json"
  [ -f "$VJ" ] && python3 - "$VJ" "$NAME" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["app_name"] = sys.argv[2]
json.dump(d, open(p, "w"))
PY
  echo "customised AppDir: $TARGET -> $NAME"
fi
