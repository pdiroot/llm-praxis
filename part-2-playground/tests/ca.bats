#!/usr/bin/env bats

setup() {
  CA="$BATS_TEST_DIRNAME/../scripts/ca.sh"
  export PG_CA_DIR="$BATS_TEST_TMPDIR/tls"
  export PG_CA_TRUST_CMD=echo
  STUB="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUB"
}

# stub_security <exit code of verify-cert>
stub_security() {
  printf '#!/usr/bin/env bash\nexit %s\n' "$1" >"$STUB/security"
  chmod +x "$STUB/security"
}

@test "ensure creates the CA with the subject" {
  run "$CA" ensure
  [ "$status" -eq 0 ]
  run openssl x509 -in "$PG_CA_DIR/ca.crt" -noout -subject
  [[ $output == *"CN=Playgrounds Root CA"* ]]
  [[ $output == *"O=Dmytro Pinchukov (github.com/pdiroot)"* ]]
  [ "$(stat -f %Lp "$PG_CA_DIR/ca.key")" = 600 ]
}

@test "ensure keeps an existing CA" {
  "$CA" ensure
  before=$(shasum "$PG_CA_DIR/ca.crt" "$PG_CA_DIR/ca.key")
  run "$CA" ensure
  [ "$status" -eq 0 ]
  [ "$(shasum "$PG_CA_DIR/ca.crt" "$PG_CA_DIR/ca.key")" = "$before" ]
}

@test "ensure refuses a half CA" {
  mkdir -p "$PG_CA_DIR"
  echo x >"$PG_CA_DIR/ca.crt"
  run "$CA" ensure
  [ "$status" -eq 1 ]
  [ ! -e "$PG_CA_DIR/ca.key" ]
}

@test "trust skips a trusted CA" {
  "$CA" ensure
  stub_security 0
  PATH="$STUB:$PATH" run "$CA" trust
  [ "$status" -eq 0 ]
  [[ $output != *add-trusted-cert* ]]
  [[ $output != *"$PG_CA_DIR/ca.crt"* ]]
}

@test "trust installs an untrusted CA" {
  "$CA" ensure
  before=$(shasum "$PG_CA_DIR/ca.crt")
  stub_security 1
  PATH="$STUB:$PATH" run "$CA" trust
  [ "$status" -eq 0 ]
  [ "$(grep -c "^-d -r trustRoot -k /Library/Keychains/System.keychain $PG_CA_DIR/ca.crt\$" <<<"$output")" -eq 1 ]
  [ "$(shasum "$PG_CA_DIR/ca.crt")" = "$before" ]
}
