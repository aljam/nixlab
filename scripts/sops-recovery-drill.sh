#!/usr/bin/env bash
# Run a host-specific or fleet-wide SOPS recovery drill.
#
# This command validates the repository's recipient policy and prints the
# recovery steps for one host. With --decrypt, it also verifies that the
# local SOPS identity can decrypt every secret file intended for that host.
#
# Usage:
#   ./scripts/sops-recovery-drill.sh --host r730xd
#   ./scripts/sops-recovery-drill.sh --host r730xd --decrypt
#   ./scripts/sops-recovery-drill.sh --all
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

known_hosts="$(python3 scripts/sops_policy.py --hosts)"

usage() {
  cat <<EOF
Usage: scripts/sops-recovery-drill.sh --host HOST [--decrypt]
       scripts/sops-recovery-drill.sh --all

Validate the SOPS recipient policy and print recovery guidance.

Hosts:
$known_hosts

Options:
  --host HOST  Select the host to drill.
  --all        Run a keyless policy dry run for every host.
  --decrypt    With --host, also attempt to decrypt every secret file allowed
               for HOST. This requires a local SOPS identity authorized for
               those files.
  -h, --help   Show this help.
EOF
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

host=""
decrypt=false
all_hosts=false

while (($#)); do
  case "$1" in
    --host)
      (($# >= 2)) || fail "--host requires an argument"
      host="$2"
      shift 2
      ;;
    --all)
      all_hosts=true
      shift
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

if [[ "$all_hosts" == true ]]; then
  [[ -z "$host" ]] || fail "--all cannot be combined with --host"
  [[ "$decrypt" == false ]] || fail "--all cannot be combined with --decrypt"
fi

if [[ "$all_hosts" == false && -z "$host" ]]; then
  usage >&2
  fail "--host is required"
fi

printf 'Running SOPS recipient policy audit...\n'
python3 scripts/check-sops-recipients.py

validate_host() {
  local drill_host="$1"
  local recipient

  recipient="$(python3 scripts/sops_policy.py --host "$drill_host" --recipient)" || \
    fail "could not resolve SOPS recipient for host: $drill_host"

  mapfile -t allowed_files < <(python3 scripts/sops_policy.py --host "$drill_host" --files)
  ((${#allowed_files[@]} > 0)) || \
    fail "no secret files are authorized for host: $drill_host"

  printf 'Host: %s\n' "$drill_host"
  printf 'Recipient: %s\n' "$recipient"
  printf 'Allowed secret files:\n'
  for file in "${allowed_files[@]}"; do
    printf '  - %s\n' "$file"
  done
}

if [[ "$all_hosts" == true ]]; then
  mapfile -t drill_hosts < <(python3 scripts/sops_policy.py --hosts)
  ((${#drill_hosts[@]} > 0)) || fail "no SOPS recipient aliases are defined"

  for drill_host in "${drill_hosts[@]}"; do
    validate_host "$drill_host"
  done

  printf 'All-host SOPS recovery policy dry run passed.\n'
  exit 0
fi

recipient="$(python3 scripts/sops_policy.py --host "$host" --recipient)" || \
  fail "could not resolve SOPS recipient for host: $host"

mapfile -t allowed_files < <(python3 scripts/sops_policy.py --host "$host" --files)
((${#allowed_files[@]} > 0)) || \
  fail "no secret files are authorized for host: $host"

printf 'Host: %s\n' "$host"
printf 'Recipient: %s\n' "$recipient"
printf 'Allowed secret files:\n'
for file in "${allowed_files[@]}"; do
  printf '  - %s\n' "$file"
done

if [[ "$decrypt" == true ]]; then
  command -v sops >/dev/null 2>&1 || fail "--decrypt requires sops"

  decrypted_file="$(mktemp)"
  trap 'rm -f "$decrypted_file"' EXIT

  printf 'Decrypting allowed secret files with the local SOPS identity...\n'
  for file in "${allowed_files[@]}"; do
    : > "$decrypted_file"
    sops -d "$file" > "$decrypted_file"
    [[ -s "$decrypted_file" ]] || fail "decrypted output is empty: $file"
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
