#!/usr/bin/env bash
# Generate our icon (normal + macOS icns) from the upstream app icon.
set -euo pipefail
SRC="${1:-$HOME/.local/opt/android-dex/usr/share/icons/hicolor/256x256/apps/Android_Dex.png}"
HERE="$(cd "$(dirname "$0")" && pwd)"
magick "$SRC" -filter Lanczos -resize 1024x1024 -modulate 105,112,100 /tmp/dex-icon.png
magick /tmp/dex-icon.png -fill '#0e1116' -colorize 14% "$HERE/icon.png"
magick "$HERE/icon.png" -resize 512x512 "$HERE/icon-512.png"
python3 - "$HERE/icon-512.png" "$HERE/icon.icns" <<'PY'
import sys
from PIL import Image
Image.open(sys.argv[1]).save(sys.argv[2], format="ICNS")
PY
rm -f "$HERE/icon-512.png"
echo "wrote $HERE/icon.png and $HERE/icon.icns"
