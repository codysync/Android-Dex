# Self-hosted Android DEX (codysync fork)

Upstream is closed-source; this fork carries our packaging, mirror and rebrand, not the app source.

| Piece | Where |
|---|---|
| Release mirror + site (tailnet only) | https://oracle.skink-tailor.ts.net:8799/ |
| Mirror assets | `/mnt/scratch/android-dex/dist` (checksums in `selfhost/manifest.json`) |
| Service | `android-dex-site.service` (user unit, python http.server on 127.0.0.1:8799) + `tailscale serve --https=8799` |
| Linux install (oracle) | `~/.local/opt/android-dex` (AppImage extracted; run `AppRun`) |
| macOS install (macbook) | `/Applications/Android_Dex.app`, shown as "Fold DeX" |
| Phone | Galaxy Z Fold 6 (SM-F971B), companion `com.shrey.androiddex`, adb over tailnet `100.109.217.118:5555` |

## Rebuild / update

```sh
./selfhost/sync-dist.sh <release-tag>   # mirror assets + rewrite manifest
./selfhost/build-www.sh                 # rebuild served site (runs on service start too)
./patch/make-icon.sh                    # regenerate our icon from the app icon
./patch/customise.sh --name "Fold DeX" <bundle>   # rebrand an install
```

Customisation so far: name "Fold DeX", our tinted icon, version.json app_name, and a local
mirror so downloads never touch GitHub. App logic is untouched because there is no source.

## Connect a machine

```sh
adb connect 100.109.217.118:5555        # phone must have wireless debugging on
```
The app ships its own adb (`Build_copy/adb-linux` or `adb-mac`); use that binary so it shares
the app's adb server. Fold reboots drop the connection — reconnect once, then the app's device
manager keeps it.
