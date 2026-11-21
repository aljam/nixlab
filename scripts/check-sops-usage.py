#!/usr/bin/env python3
"""Validate that SOPS secrets are referenced by NixOS configuration.

This static, keyless check ensures that:

- Every ``sops.secrets`` file reference resolves to an encrypted YAML file
  beneath ``secrets/``.
- Every encrypted YAML file beneath ``secrets/`` is either referenced by at
  least one Nix configuration file or explicitly marked as operator-managed.

It does not decrypt secrets or validate recipient authorization; those concerns
are covered by the repository's SOPS policy and recovery checks.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SECRETS_DIR = ROOT / "secrets"

REFERENCE_PATTERN = re.compile(
    r"sopsFile\s*=\s*(?:\.\./)*(?:\./)?(?P<path>secrets/[A-Za-z0-9_./-]+\.yaml)\s*;"
)

# SOPS files that are intentionally managed and decrypted by an operator
# rather than consumed directly by a NixOS module. They must still exist and
# remain covered by the SOPS recipient policy.
OPERATOR_MANAGED = {
    "secrets/acme.yaml",
}


def main() -> int:
    existing = {
        path.relative_to(ROOT).as_posix()
        for path in SECRETS_DIR.glob("*.yaml")
    }

    if not existing:
        print("error: no encrypted SOPS files found beneath secrets/", file=sys.stderr)
        return 1

    referenced: set[str] = set()

    for nix_path in sorted(ROOT.rglob("*.nix")):
        try:
            text = nix_path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            print(f"error: unable to read {nix_path}: {exc}", file=sys.stderr)
            return 1

        for match in REFERENCE_PATTERN.finditer(text):
            referenced.add(match.group("path"))

    missing_files = sorted(referenced - existing)
    orphan_secrets = sorted(
        (existing - referenced) - OPERATOR_MANAGED
    )

    failures = False

    if missing_files:
        failures = True
        print("error: SOPS secret references that do not resolve to existing files:", file=sys.stderr)
        for path in missing_files:
            print(f"  - {path}", file=sys.stderr)

    if orphan_secrets:
        failures = True
        print("error: encrypted SOPS files not referenced by NixOS configuration:", file=sys.stderr)
        for path in orphan_secrets:
            print(f"  - {path}", file=sys.stderr)

    if failures:
        return 1

    print(
        f"OK: validated {len(existing)} SOPS files and "
        f"{len(referenced)} NixOS secret references; "
        f"{len(existing & OPERATOR_MANAGED)} operator-managed SOPS files."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
