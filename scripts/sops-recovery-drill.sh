#!/usr/bin/env bash
# Run a host-specific SOPS recovery drill.
#
# This command validates the repository's recipient policy and prints the
# recovery steps for one host. With --decrypt, it also verifies that the
# local SOPS identity can decrypt every secret file intended for that host.
#
# Usage:
#   ./scripts/sops-recovery-drill.sh --host r730xd
#   ./scripts/sops-recovery-drill.sh --host r730xd --decrypt
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<'EOF'
Usage: scripts/sops-recovery-drill.sh --host HOST [--decrypt]

Validate the SOPS recipient policy and print recovery guidance for one host.

Hosts:
  navi, oryx, r730, r730xd, r820

Options:
  --host HOST  Select the host to drill.
  --decrypt    Also attempt to decrypt every secret file allowed for HOST.
               This requires a local SOPS identity authorized for those files.
  -h, --help   Show this help.
EOF
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

host=""
decrypt=false

while (($#)); do
  case "$1" in
    --host)
      (($# >= 2)) || fail "--host requires an argument"
      host="$2"
      shift 2
      ;;
    --decrypt)
      decrypt=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -n "$host" ]] || { usage >&2; fail "--host is required"; }

printf 'Running SOPS recipient policy audit...\n'
python3 scripts/check-sops-recipients.py

mapfile -t allowed_files < <(python3 scripts/sops_policy.py --host "$host" --files)

recipient_line="$(grep -E "^[[:space:]]*-[[:space:]]*&${host}[[:space:]]" .sops.yaml)" || \
  fail "no SOPS recipient alias found for host: $host"

recipient="$(printf '%s\n' "$recipient_line" | awk '{print $3}')"
[[ -n "$recipient" ]] || fail "could not resolve SOPS recipient for host: $host"

printf 'Host: %s\n' "$host"
printf 'Recipient: %s\n' "$recipient"
printf 'Allowed secret files:\n'
for file in "${allowed_files[@]}"; do
  printf '  - %s\n' "$file"
done

if [[ "$decrypt" == true ]]; then
  command -v sops >/dev/null 2>&1 || fail "--decrypt requires sops"

  printf 'Decrypting allowed secret files with the local SOPS identity...\n'
  for file in "${allowed_files[@]}"; do
    sops -d "$file" >/dev/null
    printf '  OK %s\n' "$file"
  done
else
  printf 'Skipping decryption check; pass --decrypt to exercise local decryption.\n'
fi

cat <<EOF

Recovery checklist for $host:
1. Preserve or restore the host SSH Ed25519 key at:
   /etc/ssh/ssh_host_ed25519_key
2. Confirm its age recipient matches the recipient above.
3. If the recipient changed, update .sops.yaml and run:
   sops updatekeys <affected-secret-file>
   for every affected secret file.
4. Rebuild the host and confirm SOPS decryption succeeds.
5. Run this drill again with --decrypt from an identity authorized for the
   host's allowed secret files.
EOF
