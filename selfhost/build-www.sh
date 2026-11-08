#!/usr/bin/env bash
# Build the served site: our copy of the pages, with release links pointing at the local mirror.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WWW=/mnt/scratch/android-dex/www
DIST=/mnt/scratch/android-dex/dist
mkdir -p "$WWW"
rm -rf "$WWW"/*
cp -a "$REPO_ROOT"/{index.html,download.html,style.css,Data,web,doc} "$WWW"/
cd "$WWW"
sed -i \
  -e 's#https://github\.com/Shrey113/Android-Dex/releases/latest/download/Android_Dex_Linux\.zip#dist/Android_Dex_Linux_x64.zip#g' \
  -e 's#https://github\.com/Shrey113/Android-Dex/releases/latest/download/#dist/#g' \
  index.html download.html
ln -sfn "$DIST" "$WWW/dist"
cp "$REPO_ROOT/selfhost/manifest.json" "$WWW/manifest.json"
echo "site built at $WWW"
