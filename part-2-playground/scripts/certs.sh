#!/usr/bin/env bash
# certs.sh: the server certificate of Traefik, signed by the playgrounds root CA.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

dir="$PG_RUNTIME/tls"
mkdir -p "$dir"

# Keep a certificate that chains to the current root and lives 7 more days.
if [[ -e $dir/server.crt && -e $dir/server.key ]] &&
  openssl x509 -in "$dir/server.crt" -noout -checkend $((7 * 86400)) >/dev/null 2>&1 &&
  openssl verify -CAfile "$PG_CA_DIR/ca.crt" "$dir/server.crt" >/dev/null 2>&1; then
  cp "$PG_CA_DIR/ca.crt" "$dir/ca.crt"
  exit 0
fi

ext="$dir/server.ext"
cat >"$ext" <<'EXT'
basicConstraints=CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=serverAuth
subjectAltName=DNS:*.playground.localhost,DNS:*.playground.internal
EXT
(umask 077 && openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
  -subj "/CN=playground" -keyout "$dir/server.key" -out "$dir/server.csr" 2>/dev/null)
# -set_serial keeps openssl from writing a .srl file next to the root CA.
openssl x509 -req -in "$dir/server.csr" -CA "$PG_CA_DIR/ca.crt" -CAkey "$PG_CA_DIR/ca.key" \
  -set_serial "0x$(openssl rand -hex 8)" -days 90 -extfile "$ext" -out "$dir/leaf.crt" 2>/dev/null
cat "$dir/leaf.crt" "$PG_CA_DIR/ca.crt" >"$dir/server.crt"
cp "$PG_CA_DIR/ca.crt" "$dir/ca.crt"
rm -f "$dir/leaf.crt" "$dir/server.csr" "$ext"
log "created $dir/server.crt"
# Traefik reads the certificate once; restart a running one (not in the tests).
if [[ $PG_RUNTIME == "$PG_ROOT/runtime" && -n $(docker compose -f "$PG_ROOT/compose.yaml" ps -q --status running traefik 2>/dev/null) ]]; then
  docker compose -f "$PG_ROOT/compose.yaml" restart traefik
fi
