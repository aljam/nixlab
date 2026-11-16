#!/usr/bin/env bash
set -euo pipefail

: "${DEPLOY_SCRIPT:?}"
: "${DEPLOY_HOSTS:?}"
: "${VALID_REV:?}"
: "${OTHER_REV:?}"
: "${FIXTURE_DIR:?}"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
mkdir -p "$workdir/bin"

cp "$FIXTURE_DIR/git" "$workdir/bin/git"
cp "$FIXTURE_DIR/nix" "$workdir/bin/nix"
cp "$FIXTURE_DIR/ssh" "$workdir/bin/ssh"
chmod +x "$workdir/bin/git" "$workdir/bin/nix" "$workdir/bin/ssh"

test_head=""
test_origin_main=""
test_dirty=""

run_deploy() {
  local expected="$1"
  shift

  : > "$workdir/ssh.log"

  set +e
  TEST_HEAD="$test_head" \
    TEST_ORIGIN_MAIN="$test_origin_main" \
    TEST_DIRTY="$test_dirty" \
    TEST_SSH_LOG="$workdir/ssh.log" \
    PATH="$workdir/bin:$PATH" \
    "$DEPLOY_SCRIPT" "$@" >"$workdir/stdout" 2>"$workdir/stderr"
  local actual=$?
  set -e

  if [[ "$actual" != "$expected" ]]; then
    echo "expected deployment exit status $expected, got $actual" >&2
    cat "$workdir/stderr" >&2
    exit 1
  fi
}

assert_ssh_hardening() {
  if [[ ! -s "$workdir/ssh.log" ]]; then
    echo "expected at least one SSH invocation" >&2
    exit 1
  fi

  while IFS= read -r invocation; do
    if [[ "$invocation" != *"-o BatchMode=yes"* ]]; then
      echo "SSH invocation lacks BatchMode=yes: $invocation" >&2
      exit 1
    fi

    if [[ "$invocation" != *"-o ConnectTimeout=10"* ]]; then
      echo "SSH invocation lacks ConnectTimeout=10: $invocation" >&2
      exit 1
    fi
  done < "$workdir/ssh.log"
}

# A dirty working tree must stop before any host is contacted.
test_head="$VALID_REV"
test_origin_main="$VALID_REV"
test_dirty=1
run_deploy 1

if [[ -s "$workdir/ssh.log" ]]; then
  echo "dirty working tree unexpectedly contacted a deployment host" >&2
  exit 1
fi

grep -F 'Refusing to deploy: Git working tree is dirty.' \
  "$workdir/stderr" >/dev/null

# An abbreviated revision must be rejected.
test_dirty=""
test_head="abc123"
run_deploy 1

if [[ -s "$workdir/ssh.log" ]]; then
  echo "abbreviated revision unexpectedly contacted a deployment host" >&2
  exit 1
fi

grep -F 'Refusing to deploy: unable to resolve a full commit SHA.' \
  "$workdir/stderr" >/dev/null

# HEAD must match the tip of origin/main.
test_head="$VALID_REV"
test_origin_main="$OTHER_REV"
run_deploy 1

if [[ -s "$workdir/ssh.log" ]]; then
  echo "non-main revision unexpectedly contacted a deployment host" >&2
  exit 1
fi

grep -F 'is not the tip of origin/main' \
  "$workdir/stderr" >/dev/null

# Explicit host arguments must be honored exactly.
test_origin_main="$VALID_REV"
run_deploy 0 r820 r730

expected_count=2
actual_count="$(wc -l < "$workdir/ssh.log")"
if [[ "$actual_count" != "$expected_count" ]]; then
  echo "expected $expected_count SSH invocations, got $actual_count" >&2
  cat "$workdir/ssh.log" >&2
  exit 1
fi

assert_ssh_hardening

grep -F "-o BatchMode=yes -o ConnectTimeout=10 deploy@r820 deploy-rebuild switch $VALID_REV" \
  "$workdir/ssh.log" >/dev/null
grep -F "-o BatchMode=yes -o ConnectTimeout=10 deploy@r730 deploy-rebuild switch $VALID_REV" \
  "$workdir/ssh.log" >/dev/null

# With no arguments, deploy exactly the configured default hosts.
run_deploy 0

expected_count="$(printf '%s\n' "$DEPLOY_HOSTS" | wc -w)"
actual_count="$(wc -l < "$workdir/ssh.log")"

if [[ "$actual_count" != "$expected_count" ]]; then
  echo "expected $expected_count default deployments, got $actual_count" >&2
  cat "$workdir/ssh.log" >&2
  exit 1
fi

assert_ssh_hardening

for host in $DEPLOY_HOSTS; do
  grep -F "-o BatchMode=yes -o ConnectTimeout=10 deploy@$host deploy-rebuild switch $VALID_REV" \
    "$workdir/ssh.log" >/dev/null
done
