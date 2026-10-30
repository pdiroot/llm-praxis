#!/usr/bin/env bats

setup() {
  CERTS="$BATS_TEST_DIRNAME/../scripts/certs.sh"
  export PG_CA_DIR="$BATS_TEST_TMPDIR/ca"
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime"
  "$BATS_TEST_DIRNAME/../scripts/ca.sh" ensure 2>/dev/null
}

@test "the certificate covers both names" {
  run "$CERTS"
  [ "$status" -eq 0 ]
  run openssl x509 -in "$PG_RUNTIME/tls/server.crt" -noout -ext subjectAltName
  [[ $output == *"DNS:*.playground.localhost"* ]]
  [[ $output == *"DNS:*.playground.internal"* ]]
}

@test "a valid certificate is kept" {
  "$CERTS"
  before=$(shasum "$PG_RUNTIME"/tls/*)
  run "$CERTS"
  [ "$status" -eq 0 ]
  [ "$(shasum "$PG_RUNTIME"/tls/*)" = "$before" ]
}

@test "the certificate chains to the root" {
  "$CERTS"
  run openssl verify -CAfile "$PG_CA_DIR/ca.crt" "$PG_RUNTIME/tls/server.crt"
  [ "$status" -eq 0 ]
  cmp "$PG_CA_DIR/ca.crt" "$PG_RUNTIME/tls/ca.crt"
  [ "$(grep -c BEGIN "$PG_RUNTIME/tls/server.crt")" -eq 2 ]
}
