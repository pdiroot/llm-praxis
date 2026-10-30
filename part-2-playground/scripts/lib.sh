#!/usr/bin/env bash
# Shared helpers. Source this file; it sets no shell options.

PG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PG_RUNTIME="$PG_ROOT/runtime"
PG_CA_DIR="${PG_CA_DIR:-$HOME/.config/playgrounds/tls}"

log() { printf '%s\n' "$*" >&2; }
die() {
  log "error: $*"
  exit 1
}

# wait_http <url> <code> <timeout_s>: 0 when the URL answers <code>, 1 on timeout.
wait_http() {
  local url=$1 code=$2 deadline=$((SECONDS + $3)) got
  while ((SECONDS < deadline)); do
    got=$(curl -s --max-time $((deadline - SECONDS)) -o /dev/null -w '%{http_code}' --cacert "$PG_CA_DIR/ca.crt" "$url" 2>/dev/null || true)
    [[ $got == "$code" ]] && return 0
    sleep 1
  done
  return 1
}

# api <method> <path> [curl args]: call the GitLab API as admin.
api() {
  local method=$1 path=$2
  shift 2
  curl -sS --fail-with-body --cacert "$PG_CA_DIR/ca.crt" \
    -X "$method" -H "PRIVATE-TOKEN: $(cat "$PG_RUNTIME/tokens/admin")" \
    "https://gitlab.playground.localhost/api/v4$path" "$@"
}
