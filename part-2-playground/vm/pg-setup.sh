#!/usr/bin/env bash
# Installs the deploy keys and the playground CA from the mounted /pg folder.
set -euo pipefail
# Host keys live in the /etc/ssh volume, so each VM keeps its own.
ssh-keygen -A

install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
cat /pg/ssh/mac.pub /pg/ssh/ci.pub >/home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys

cp /pg/tls/ca.crt /usr/local/share/ca-certificates/playground-ca.crt
update-ca-certificates
