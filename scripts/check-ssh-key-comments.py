#!/usr/bin/env python3
"""Require descriptive comments on authorized SSH public keys."""

from __future__ import annotations

import pathlib
import re
import sys

KEY_PATTERN = re.compile(r"^(?P<type>ssh-(?:ed25519|rsa)|ecdsa-sha2-\S+|sk-\S+)\s+(?P<material>\S+)(?:\s+(?P<comment>\S.*))?$")


def check_file(path: pathlib.Path) -> list[str]:
    errors: list[str] = []

    for number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.strip()

        if not line or line.startswith("#"):
            continue

        match = KEY_PATTERN.fullmatch(line)
        if not match:
            errors.append(f"{path}:{number}: not a recognized SSH public key")
            continue

        comment = (match.group("comment") or "").strip()
        if not comment:
            errors.append(
                f"{path}:{number}: SSH key has no comment; add a unique 'user@device' comment"
            )
        elif "@" not in comment:
            errors.append(
                f"{path}:{number}: SSH key comment '{comment}' should use the 'user@device' convention"
            )

    return errors


def main() -> int:
    errors: list[str] = []

    for path in sorted(pathlib.Path("users").rglob("*.nix")):
        text = path.read_text(encoding="utf-8")
        if "openssh.authorizedKeys.keys" not in text:
            continue

        for match in re.finditer(r"['\"](ssh-[^'\"]+)['\"]", text):
            key = match.group(1).strip()
            parsed = KEY_PATTERN.fullmatch(key)
            if not parsed:
                errors.append(f"{path}: unrecognized SSH public key")
                continue

            comment = (parsed.group("comment") or "").strip()
            if not comment:
                errors.append(
                    f"{path}: SSH key has no comment; add a unique 'user@device' comment"
                )
            elif "@" not in comment:
                errors.append(
                    f"{path}: SSH key comment '{comment}' should use the 'user@device' convention"
                )

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    print("SSH key comments follow the user@device convention.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
