{
  pkgs,
  deployScript,
  deployHosts,
}:

let
  inherit (pkgs) lib;

  validRev = "0123456789abcdef0123456789abcdef01234567";
  otherRev = "fedcba9876543210fedcba9876543210fedcba98";
  hostList = lib.concatStringsSep " " deployHosts;
in
pkgs.runCommand "deploy-behavior" { } ''
set -euo pipefail

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
mkdir -p "$workdir/bin"

cp ${./fixtures/deploy/git} "$workdir/bin/git"
cp ${./fixtures/deploy/nix} "$workdir/bin/nix"
cp ${./fixtures/deploy/ssh} "$workdir/bin/ssh"
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
    "${deployScript}" "$@" >"$workdir/stdout" 2>"$workdir/stderr"
  local actual=$?
  set -e

  if [[ "$actual" != "$expected" ]]; then
    echo "expected deployment exit status $expected, got $actual" >&2
    cat "$workdir/stderr" >&2
    exit 1
  fi
}

# A dirty working tree must stop before any host is contacted.
test_head="$validRev"
test_origin_main="$validRev"
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
test_head="$validRev"
test_origin_main="$otherRev"
run_deploy 1

if [[ -s "$workdir/ssh.log" ]]; then
  echo "non-main revision unexpectedly contacted a deployment host" >&2
  exit 1
fi

grep -F 'is not the tip of origin/main' \
  "$workdir/stderr" >/dev/null

# Explicit host arguments must be honored exactly.
test_origin_main="$validRev"
run_deploy 0 r820 r730

expected_count=2
actual_count="$(wc -l < "$workdir/ssh.log")"
if [[ "$actual_count" != "$expected_count" ]]; then
  echo "expected $expected_count SSH invocations, got $actual_count" >&2
  cat "$workdir/ssh.log" >&2
  exit 1
fi

grep -F "deploy@r820 deploy-rebuild switch $validRev" \
  "$workdir/ssh.log" >/dev/null
grep -F "deploy@r730 deploy-rebuild switch $validRev" \
  "$workdir/ssh.log" >/dev/null

# With no arguments, deploy exactly the configured default hosts.
run_deploy 0

read -r -a expected_hosts <<< "${hostList}"
expected_count="${#expected_hosts[@]}"
actual_count="$(wc -l < "$workdir/ssh.log")"

if [[ "$actual_count" != "$expected_count" ]]; then
  echo "expected $expected_count default deployments, got $actual_count" >&2
  cat "$workdir/ssh.log" >&2
  exit 1
fi

for host in "${expected_hosts[@]}"; do
  grep -F "deploy@${host} deploy-rebuild switch $validRev" \
    "$workdir/ssh.log" >/dev/null
done

touch "$out"
''
