#!/usr/bin/env python3
"""Single source of truth for the repository's SOPS recipient policy."""

from __future__ import annotations

import argparse
import json
import sys

POLICY = {
    "secrets/common.yaml": {"aljam", "navi", "oryx", "r730", "r730xd", "r820"},
    "secrets/nas.yaml": {"aljam", "navi", "oryx"},
    "secrets/database.yaml": {"aljam", "r820"},
    "secrets/matrix.yaml": {"aljam", "r730xd", "r820"},
    "secrets/vaultwarden.yaml": {"aljam", "r730xd", "r820"},
    "secrets/monitoring.yaml": {"aljam", "r730", "r730xd", "r820"},
    "secrets/media.yaml": {"aljam", "r730xd"},
}


def files_for_host(host: str) -> list[str]:
    return sorted(path for path, recipients in POLICY.items() if host in recipients)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", help="Show secret files allowed for this host")
    parser.add_argument("--files", action="store_true", help="Print allowed files, one per line")
    parser.add_argument("--json", action="store_true", help="Print the full policy as JSON")
    args = parser.parse_args()

    if args.json:
        print(json.dumps({path: sorted(recipients) for path, recipients in POLICY.items()}, indent=2))
        return

    if not args.host or not args.files:
        parser.error("--files requires --host HOST")

    if args.host not in {recipient for recipients in POLICY.values() for recipient in recipients}:
        parser.error(f"unknown SOPS recipient: {args.host}")

    for path in files_for_host(args.host):
        print(path)


if __name__ == "__main__":
    main()
