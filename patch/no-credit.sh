#!/usr/bin/env bash
# Remove the "· Made with ❤️ by shrey113" credit from an installed build, keeping "V.1.5".
# Both are fixed strings in the Dart snapshot (UTF-16 in the pool), so the bytes are blanked in
# place with spaces: same length, no offset shifts. Re-run after re-extracting a release.
# Usage: ./no-credit.sh <binary>        (Linux: .../usr/lib/libapp.so; macOS: App.framework/Versions/A/App)
set -euo pipefail
BIN="${1:?path to libapp.so or App.framework/.../App}"
[ -w "$BIN" ] || { echo "not writable: $BIN" >&2; exit 1; }
python3 - "$BIN" <<'PY'
import sys
from pathlib import Path

p = Path(sys.argv[1])
buf = bytearray(p.read_bytes())
MARK = "V.1.5 · Made with ❤️ by".encode("utf-16-le")
KEEP = len("V.1.5") * 2
blanked = 0
i = buf.find(MARK)
while i >= 0:
    for j in range(i + KEEP, i + len(MARK)):
        buf[j] = 0x20 if (j - i) % 2 == 0 else 0x00
    blanked += 1
    i = buf.find(MARK, i + len(MARK))
names = 0
n = buf.find(b"shrey113")
while n >= 0:
    if buf[n - 1] == 0 and buf[n + len("shrey113")] == 0:  # standalone literal, not inside a URL
        buf[n:n + 8] = b" " * 8
        names += 1
    n = buf.find(b"shrey113", n + 8)
if not blanked:
    sys.exit("credit string not found (already patched, or a different build)")
p.write_bytes(buf)
print(f"blanked {blanked} credit string(s), {names} name literal(s)")
PY
