#!/usr/bin/env bash
# Point this machine's Android DEX traffic at dex-edge and trust its CA.
# Run on oracle (hosts apex + service) and on the macbook (hosts apex = oracle, CA trust).
# Usage: ./install-edge.sh [host|client]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
STATE="${DEX_EDGE_STATE:-$HOME/.local/state/dex-edge}"
ROLE="${1:-host}"
HOSTS="api.github.com ipinfo.io api.weatherapi.com cdn.weatherapi.com"

"$HERE/gen-certs.sh" >/dev/null

# 1. hosts: every machine runs its own shim on loopback; nothing crosses the network.
APEX_FOR_HOSTS=127.0.0.1
tmp="$(mktemp)"
grep -vE "dex-edge" /etc/hosts > "$tmp" || true
for h in $HOSTS; do printf '%s %s # dex-edge\n' "$APEX_FOR_HOSTS" "$h" >> "$tmp"; done
sudo -n cp "$tmp" /etc/hosts; rm -f "$tmp"
echo "hosts entries -> $APEX_FOR_HOSTS"

# 2. trust our CA
if [ "$(uname -s)" = Darwin ]; then
  mkdir -p "$HOME/.local/libexec"
  xcrun clang -O2 -framework Security -framework CoreFoundation \
    -o "$HOME/.local/libexec/dex-edge-trustset" "$HERE/trustset.c"
  install -m 755 "$HERE/ensure-trust.sh" "$HOME/.local/libexec/dex-edge-ensure-trust"
  # A trust settings write blocks while the screen is locked, so keep one attempt running and
  # let a launch agent retry until it lands (SecurityAgent prompt appears once on unlock).
  sudo -n tee /Library/LaunchAgents/au.bilson.dex-edge-trust.plist >/dev/null <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>au.bilson.dex-edge-trust</string>
  <key>ProgramArguments</key><array>
    <string>$HOME/.local/libexec/dex-edge-ensure-trust</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>600</integer>
  <key>StandardOutPath</key><string>/tmp/dex-edge-trust.log</string>
  <key>StandardErrorPath</key><string>/tmp/dex-edge-trust.log</string>
</dict></plist>
PLIST
  launchctl bootout gui/"$(id -u)"/au.bilson.dex-edge-trust 2>/dev/null || true
  launchctl bootstrap gui/"$(id -u)" /Library/LaunchAgents/au.bilson.dex-edge-trust.plist
  if "$HOME/.local/libexec/dex-edge-ensure-trust"; then
    echo "CA trusted"
  else
    echo "CA queued: finishes once the Mac's screen is unlocked (agent retries every 10 min)"
  fi
fi

# 3. service: systemd user-independent unit on oracle, LaunchDaemon on macOS
if [ "$(uname -s)" = Darwin ]; then
  sudo -n tee /Library/LaunchDaemons/au.bilson.dex-edge.plist >/dev/null <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>au.bilson.dex-edge</string>
  <key>ProgramArguments</key><array>
    <string>/usr/bin/python3</string><string>-u</string><string>$HERE/dex-edge.py</string>
  </array>
  <key>UserName</key><string>root</string>
  <key>EnvironmentVariables</key><dict>
    <key>HOME</key><string>$HOME</string>
  </dict>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/var/log/dex-edge.log</string>
  <key>StandardErrorPath</key><string>/var/log/dex-edge.log</string>
</dict></plist>
PLIST
  sudo -n launchctl bootout system/au.bilson.dex-edge 2>/dev/null || true
  sudo -n launchctl bootstrap system /Library/LaunchDaemons/au.bilson.dex-edge.plist
  sleep 2
  sudo -n launchctl print system/au.bilson.dex-edge >/dev/null && echo "dex-edge daemon loaded"
else
  sudo -n install -m 644 "$HERE/dex-edge.service" /etc/systemd/system/dex-edge.service
  sudo -n systemctl daemon-reload
  sudo -n systemctl enable --now dex-edge.service
  sleep 2
  sudo -n systemctl is-active dex-edge.service
fi
