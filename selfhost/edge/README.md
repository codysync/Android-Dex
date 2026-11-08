# dex-edge

Local stand-in for the only four hosts Android DEX calls (audit: homelab
`docs/android-dex-privacy-audit-2026-11-08.md`). With hosts entries pointing those names at
loopback, the app never needs DNS or internet.

- `gen-certs.sh` — private CA + leaf (SANs: api.github.com, ipinfo.io, api.weatherapi.com,
  cdn.weatherapi.com) in `~/.local/state/dex-edge`.
- `dex-edge.py` — HTTPS server on `127.0.0.1:443`: version answer from `../manifest.json`, static
  geo, weather from `~/.local/state/dex-edge/weather.json`, mirrored icons.
- `install-edge.sh host|client` — hosts entries, CA trust, service (systemd unit on Linux,
  LaunchDaemon + trust retry agent on macOS).
- `push-to-macbook.sh` — copy this tree to the macbook and reinstall there.
- `ensure-trust.sh`, `trustset.c` — macOS trust retry (a trust write blocks while the screen is locked).

## Change the weather it shows

`~/.local/state/dex-edge/weather.json`, e.g. `{"temp_c": 31, "condition": {"text": "Sunny",
"code": 1000, "icon": "113"}, "is_day": 1}`. Restart nothing; it is read per request.

## After an upstream update, re-check the host list

```sh
strings -a ~/.local/opt/android-dex/usr/lib/libapp.so | grep -oaE 'https?://[^ ]{6,90}' | sort -u
for j in /mnt/scratch/android-dex/linux/squashfs-root/usr/share/Android_Dex/Build_copy/*.jar; do
  unzip -p "$j" '*.class' | strings | grep -oaE 'https?://[^ ]{6,90}'; done
```
New host? add it to `HOSTS` in `install-edge.sh` and a route in `dex-edge.py`.

## Rollback

`sudo sed -i '/# dex-edge$/d' /etc/hosts` (macOS: same, then
`sudo launchctl bootout gui/$(id -u)/au.bilson.dex-edge-trust`, `sudo rm /Library/LaunchAgents/au.bilson.dex-edge-trust.plist`),
then `sudo systemctl disable --now dex-edge` (macOS: `sudo launchctl bootout system/au.bilson.dex-edge`).
