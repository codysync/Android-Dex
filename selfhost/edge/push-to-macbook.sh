#!/usr/bin/env bash
# Copy the edge tree to the macbook and reinstall it there.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST=macbook:~/Projects/android-dex-selfhost/
ssh "$1" 'mkdir -p ~/Projects/android-dex-selfhost' 2>/dev/null || ssh macbook 'mkdir -p ~/Projects/android-dex-selfhost'
tar -czf /tmp/edge.tgz -C "$HERE" . && scp -q /tmp/edge.tgz macbook:/tmp/ && rm -f /tmp/edge.tgz
ssh macbook 'tar -xzf /tmp/edge.tgz -C ~/Projects/android-dex-selfhost && rm -f /tmp/edge.tgz && cd ~/Projects/android-dex-selfhost && bash ./install-edge.sh client'
