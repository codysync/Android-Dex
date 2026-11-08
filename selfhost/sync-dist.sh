#!/usr/bin/env bash
# Mirror the pinned upstream release assets locally and record them in manifest.json.
# Usage: ./selfhost/sync-dist.sh [version-tag]
set -euo pipefail
TAG="${1:-Android-Dex-v.1.5}"
DIST=/mnt/scratch/android-dex/dist
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK_SRC="$HOME/.local/opt/android-dex/usr/share/Android_Dex/Build_copy/AndroidDex.apk"
mkdir -p "$DIST"
for asset in Android_Dex_Linux_x64.zip Android_Dex_macOS.zip; do
  [ -s "$DIST/$asset" ] || curl -fsSL -o "$DIST/$asset" \
    "https://github.com/Shrey113/Android-Dex/releases/download/$TAG/$asset"
done
[ -s "$DIST/AndroidDex.apk" ] || cp "$APK_SRC" "$DIST/AndroidDex.apk"
python3 - "$DIST" "$TAG" <<'PY' > "$REPO_ROOT/selfhost/manifest.json"
import hashlib, json, os, sys
dist, tag = sys.argv[1], sys.argv[2]
out = {"tag": tag, "assets": {}}
for name in sorted(os.listdir(dist)):
    p = os.path.join(dist, name)
    if not os.path.isfile(p):
        continue
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    out["assets"][name] = {"sha256": h.hexdigest(), "bytes": os.path.getsize(p)}
json.dump(out, sys.stdout, indent=2, sort_keys=True)
PY
echo "manifest written: $REPO_ROOT/selfhost/manifest.json"
