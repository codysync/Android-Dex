#!/usr/bin/env bash
# Make sure the dex-edge CA is trusted (macOS). Safe to run repeatedly, does nothing once trusted.
# A trust settings write blocks while the screen is locked, so the attempt is left running in the
# background and the launch agent retries every 10 minutes until it lands.
set -uo pipefail
STATE="${DEX_EDGE_STATE:-$HOME/.local/state/dex-edge}"
BIN="$HOME/.local/libexec/dex-edge-trustset"
LEAF="$STATE/leaf.crt"

security verify-cert -c "$LEAF" -p ssl >/dev/null 2>&1 && exit 0
openssl x509 -in "$STATE/ca.crt" -outform der -out /tmp/dex-edge-ca.der 2>/dev/null || exit 1
"$BIN" /tmp/dex-edge-ca.der >/tmp/dex-edge-trustset.out 2>&1 &
pid=$!
for _ in $(seq 20); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
security verify-cert -c "$LEAF" -p ssl >/dev/null 2>&1
