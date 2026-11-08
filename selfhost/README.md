# selfhost/

Static site + release mirror for our Android DEX fork, served on the tailnet only.

- `sync-dist.sh [tag]` mirrors Linux/macOS/Windows zips and the companion APK from the pinned
  upstream release into `/mnt/scratch/android-dex/dist` and writes `manifest.json` with sha256s.
- `build-www.sh` copies the site into `/mnt/scratch/android-dex/www` and repoints every
  download link at `dist/`. It runs as `ExecStartPre` of `android-dex-site.service`.

Serving: `python3 -m http.server 8799 --bind 127.0.0.1` behind
`sudo tailscale serve --bg --https=8799 http://127.0.0.1:8799`. No auth is needed because only
tailnet devices can reach it.
