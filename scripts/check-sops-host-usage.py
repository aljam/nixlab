#!/usr/bin/env python3
"""Enforce that hosts only consume SOPS secrets authorized for them.

This static, keyless audit maps Nix configuration beneath ``hosts/<host>/`` to
a SOPS policy host and verifies every referenced secret file against that
host's authorized secret set.

It does not decrypt secrets or validate recipient metadata; those concerns are
covered by the repository's SOPS policy and recovery checks.
"""

from __future__ import annotations

import importlib.util
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HOSTS_DIR = ROOT / "hosts"

REFERENCE_PATTERN = re.compile(
    r'file\s*=\s*"(?P<path>secrets/[A-Za-z0-9_./-]+\.yaml)"\s*;'
)


def load_policy():
    policy_path = ROOT / "scripts" / "sops_policy.py"
    spec = importlib.util.spec_from_file_location("sops_policy", policy_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"unable to load SOPS policy module: {policy_path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    try:
        policy = load_policy()
    except (OSError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if not HOSTS_DIR.is_dir():
        print(f"error: missing hosts directory: {HOSTS_DIR}", file=sys.stderr)
        return 1

    known_hosts = set(policy.hosts())
    unauthorized: list[str] = []
    unknown_hosts: list[str] = []

    for host_dir in sorted(path for path in HOSTS_DIR.iterdir() if path.is_dir()):
        host = host_dir.name

        if host not in known_hosts:
            unknown_hosts.append(host)
            continue

        allowed = set(policy.files_for_host(host))

        for nix_path in sorted(host_dir.rglob("*.nix")):
            try:
                text = nix_path.read_text(encoding="utf-8")
            except (OSError, UnicodeError) as exc:
                print(f"error: unable to read {nix_path}: {exc}", file=sys.stderr)
                return 1

            for match in REFERENCE_PATTERN.finditer(text):
                secret = match.group("path")

                if secret not in allowed:
                    unauthorized.append(f"{host}: {secret}")

    failures = False

    if unknown_hosts:
        failures = True
        print(
            "error: host directories that do not map to a SOPS policy recipient:",
            file=sys.stderr,
        )
        for host in unknown_hosts:
            print(f"  - {host}", file=sys.stderr)

    if unauthorized:
        failures = True
        print(
            "error: hosts referencing SOPS secrets outside their authorized policy:",
            file=sys.stderr,
        )
        for entry in unauthorized:
            print(f"  - {entry}", file=sys.stderr)

    if failures:
        return 1

    print(f"OK: validated SOPS secret usage for {len(known_hosts)} policy hosts.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
