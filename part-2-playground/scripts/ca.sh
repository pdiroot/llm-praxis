#!/usr/bin/env bash
# ca.sh ensure | trust: the playgrounds root CA.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

crt="$PG_CA_DIR/ca.crt"
key="$PG_CA_DIR/ca.key"

ensure() {
  if [[ -e $crt && -e $key ]]; then
    return 0
  elif [[ -e $crt || -e $key ]]; then
    die "only one of $crt and $key exists; fix it by hand"
  fi

  mkdir -p "$PG_CA_DIR"
  # step has no flag for the organization, so openssl makes the CA.
  (umask 077 && openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
    -days 3650 -subj "/O=Dmytro Pinchukov (github.com\\/pdiroot)/CN=Playgrounds Root CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -keyout "$key" -out "$crt" 2>/dev/null)

  chmod 644 "$crt"
  chmod 600 "$key"
  log "created $crt"
}

trust() {
  [[ -e $crt ]] || die "no CA at $crt; run ensure first"
  if security verify-cert -c "$crt" >/dev/null 2>&1; then
    log "CA already trusted"
    return 0
  fi

  # PG_CA_TRUST_CMD is split on purpose; the tests replace it with echo.
  # shellcheck disable=SC2086
  ${PG_CA_TRUST_CMD:-sudo security add-trusted-cert} -d -r trustRoot -k /Library/Keychains/System.keychain "$crt"
}

case "${1:-}" in
ensure) ensure ;;
trust) trust ;;
*) die "usage: ca.sh ensure|trust" ;;
esac
