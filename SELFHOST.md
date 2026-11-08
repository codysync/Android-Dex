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

Customisation so far: name "Fold DeX", our tinted icon, version.json app_name, the upstream
"· Made with ❤️ by shrey113" credit blanked (`patch/no-credit.sh <libapp.so|App binary>`, re-run after
every re-extract/upgrade, then `codesign --force --deep --sign -` on macOS), and a local mirror so
downloads never touch GitHub. App logic is untouched because there is no source.

## Connect a machine

```sh
adb connect 100.109.217.118:5555        # phone must have wireless debugging on
```
The app ships its own adb (`Build_copy/adb-linux` or `adb-mac`); use that binary so it shares
the app's adb server. Fold reboots drop the connection — reconnect once, then the app's device
manager keeps it.

## Privacy: it now runs entirely on our hardware

Audit (2026-11-08) of the shipped binaries found exactly four hosts the app itself calls, plus
links it opens only when clicked:

| Host | Why | Served by |
|---|---|---|
| `api.github.com/repos/Shrey113/Android-Dex/releases/latest` | startup version check | `dex-edge`, tag from `selfhost/manifest.json` |
| `ipinfo.io/json` | IP/geo widget | `dex-edge`, static answer |
| `api.weatherapi.com/v1/{current,forecast}.json` | weather widget | `dex-edge`, `weather.json` |
| `cdn.weatherapi.com/weather/**` | weather icons | `dex-edge`, mirrored `selfhost/edge/icons` |

No analytics, telemetry, crash reporting, Firebase, Sentry or ad SDK exists in the desktop bundle
or in the companion APK (`strings` across `libapp.so`, the Rust core, every jar and `classes.dex`).
The phone app makes no network calls at all: the desktops drive it over adb.

`selfhost/edge/` replaces all four hosts with a local TLS shim (own CA, 127.0.0.1:443), so the app
needs no DNS or internet. Install with `./selfhost/edge/install-edge.sh host` (oracle) and
`./selfhost/edge/push-to-macbook.sh` (macbook). Rollback: drop the `# dex-edge` lines from
`/etc/hosts` and stop `dex-edge`.

Still third-party by design: links you click (YouTube, Wikipedia, Reddit, GitHub, the buy-me-a-coffee
button, and the Brave/Google/Perplexity search widgets) open in the browser, so those go out from
whichever machine — and they work offline-by-host-block only in the sense that a blocked host means
the page fails.
