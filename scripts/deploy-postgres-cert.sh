#!/usr/bin/env bash
# Deploy a renewed PostgreSQL certificate to r820.
#
# Run it from an administrator workstation after pfSense has renewed the
# certificate. sudo on the fleet requires a password, so the script asks for
# it once; it cannot run unattended from a pfSense hook.
#
# Usage: deploy-postgres-cert.sh [server.crt] [server.key]
#
# The destination matches `ssl_cert_file` and `ssl_key_file` in
# modules/features/postgres.nix, so renewals need no NixOS, SOPS, or Synapse
# configuration changes.
set -euo pipefail

REMOTE="${REMOTE:-aljam@r820}"
DEST="/var/lib/postgresql/tls"
CERT="${1:-server.crt}"
KEY="${2:-server.key}"

[[ -f "$CERT" ]] || { echo "missing certificate: $CERT" >&2; exit 1; }
[[ -f "$KEY" ]] || { echo "missing private key: $KEY" >&2; exit 1; }

# Stage in a private directory. A fixed name such as /tmp/server.key is
# world-readable for as long as it exists.
staging="$(ssh "$REMOTE" 'umask 077 && mktemp -d')"
# shellcheck disable=SC2029 # $staging is meant to expand locally.
trap 'ssh "$REMOTE" "rm -rf -- $staging"' EXIT

scp -q "$CERT" "$REMOTE:$staging/server.crt"
scp -q "$KEY" "$REMOTE:$staging/server.key"

# One sudo invocation, so one password prompt; -t gives sudo a terminal.
# shellcheck disable=SC2029 # $DEST and $staging are meant to expand locally.
ssh -t "$REMOTE" "sudo sh -c '
  install -d -o postgres -g postgres -m 700 $DEST &&
  install -o postgres -g postgres -m 640 $staging/server.crt $DEST/server.crt &&
  install -o postgres -g postgres -m 600 $staging/server.key $DEST/server.key &&
  systemctl reload postgresql
'"

echo "PostgreSQL certificate deployed and service reloaded."
