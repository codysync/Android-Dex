#!/usr/bin/env bash
# Local CA + leaf cert for the three hosts Android DEX calls. Cert never leaves oracle.
set -euo pipefail
STATE="${DEX_EDGE_STATE:-$HOME/.local/state/dex-edge}"
mkdir -p "$STATE"; chmod 700 "$STATE"
cd "$STATE"
HOSTS="api.github.com ipinfo.io api.weatherapi.com cdn.weatherapi.com"
if [ ! -s ca.key ]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout ca.key -out ca.crt -subj "/CN=homelab dex-edge CA" \
    -addext "basicConstraints=critical,CA:TRUE" 2>/dev/null
  chmod 600 ca.key
fi
SAN=""; i=1
for h in $HOSTS; do SAN="${SAN}DNS.${i}:${h},"; i=$((i+1)); done
SAN="${SAN%,}"
cat > leaf.ext <<EXT
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=${SAN}
EXT
openssl req -newkey rsa:2048 -sha256 -nodes -keyout leaf.key -out leaf.csr \
  -subj "/CN=api.github.com" 2>/dev/null
openssl x509 -req -in leaf.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 825 -sha256 -extfile leaf.ext -out leaf.crt 2>/dev/null
cat leaf.crt ca.crt > fullchain.pem
chmod 600 leaf.key
{ openssl x509 -in leaf.crt -noout -ext subjectAltName 2>/dev/null || openssl x509 -in leaf.crt -noout -text | grep -A1 "Subject Alternative Name" | tail -1; }
echo "certs in $STATE"
