#!/usr/bin/env bash
# Make sure the dex-edge CA is trusted (macOS). Does nothing once the CA is in the trust store.
# A trust settings write blocks while the screen is locked and shows a Touch ID prompt, so the
# writer is bounded to 20 s, killed if it overruns, and retried on the next agent tick.
set -uo pipefail
STATE="${DEX_EDGE_STATE:-$HOME/.local/state/dex-edge}"
BIN="$HOME/.local/libexec/dex-edge-trustset"
LOCK=/tmp/dex-edge-trust.lock

trusted() { security dump-trust-settings 2>/dev/null | grep -q "homelab dex-edge CA"; }
trusted && exit 0
mkdir "$LOCK" 2>/dev/null || exit 1
trap 'rmdir "$LOCK"' EXIT
trusted && exit 0

openssl x509 -in "$STATE/ca.crt" -outform der -out /tmp/dex-edge-ca.der 2>/dev/null || exit 1
"$BIN" /tmp/dex-edge-ca.der >/tmp/dex-edge-trustset.out 2>&1 &
pid=$!
for _ in $(seq 20); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
if kill -0 "$pid" 2>/dev/null; then kill "$pid"; exit 1; fi
trusted
