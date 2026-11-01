#!/usr/bin/env python3
"""Enforce the repository's SOPS recipient policy.

This audit is intentionally dependency-free. It validates both the declarative
recipient model in `.sops.yaml` and the actual age recipients embedded in each
encrypted secret file. It does not decrypt secret files.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOPS_CONFIG = ROOT / ".sops.yaml"
SECRETS_DIR = ROOT / "secrets"

EXPECTED_RECIPIENTS = {
    "secrets/common.yaml": {"aljam", "navi", "oryx", "r730", "r730xd", "r820"},
    "secrets/nas.yaml": {"aljam", "navi", "oryx"},
    "secrets/database.yaml": {"aljam", "r820"},
    "secrets/matrix.yaml": {"aljam", "r730xd", "r820"},
    "secrets/vaultwarden.yaml": {"aljam", "r730xd", "r820"},
    "secrets/monitoring.yaml": {"aljam", "r730", "r730xd", "r820"},
    "secrets/media.yaml": {"aljam", "r730xd"},
}

REQUIRED_ALIASES = {
    "aljam",
    "navi",
    "oryx",
    "r730",
    "r730xd",
    "r820",
}

ALIAS_DEFINITION = re.compile(
    r"^\s*-\s*&([A-Za-z0-9_-]+)\s+(.+?)\s*$",
    re.MULTILINE,
)
ALIAS_REFERENCE = re.compile(r"\*([A-Za-z0-9_-]+)")
RULE_SPLIT = re.compile(r"^(?=\s*-\s*path_regex:\s*)", re.MULTILINE)
PATH_REGEX = re.compile(r"^\s*-\s*path_regex:\s*(\S+)\s*$", re.MULTILINE)
ENCRYPTED_RECIPIENT = re.compile(
    r"^\s*(?:-\s*)?recipient:\s*(.+?)\s*$",
    re.MULTILINE,
)


def fail(message: str) -> None:
    raise SystemExit(message)


def parse_rules(config: str) -> list[tuple[str, str]]:
    rules = []

    for block in RULE_SPLIT.split(config):
        match = PATH_REGEX.search(block)
        if match:
            rules.append((match.group(1), block))

    return rules


def rule_recipients(block: str) -> set[str]:
    recipients = []

    for line in block.splitlines():
        if "key_groups:" in line:
            continue

        match = ALIAS_REFERENCE.search(line)
        if match:
            recipients.append(match.group(1))

    duplicates = sorted(
        recipient
        for recipient in set(recipients)
        if recipients.count(recipient) > 1
    )

    if duplicates:
        fail("Duplicate recipient aliases in a SOPS creation rule: " + ", ".join(duplicates))

    return set(recipients)


def encrypted_recipients(path: pathlib.Path, alias_to_key: dict[str, str]) -> set[str]:
    text = path.read_text()
    keys = ENCRYPTED_RECIPIENT.findall(text)

    if not keys:
        fail(f"{path.relative_to(ROOT).as_posix()}: no SOPS age recipients found")

    key_to_alias = {key: alias for alias, key in alias_to_key.items()}
    aliases = set()

    for key in keys:
        alias = key_to_alias.get(key)
        if alias is None:
            fail(
                f"{path.relative_to(ROOT).as_posix()}: encrypted file contains an "
                f"unknown SOPS recipient: {key}"
            )
        aliases.add(alias)

    return aliases


def main() -> None:
    if not SOPS_CONFIG.is_file():
        fail("Missing .sops.yaml")

    config = SOPS_CONFIG.read_text()
    definitions = ALIAS_DEFINITION.findall(config)
    defined_aliases = [name for name, _ in definitions]
    alias_to_key = {name: key for name, key in definitions}

    duplicate_aliases = sorted(
        alias for alias in set(defined_aliases) if defined_aliases.count(alias) > 1
    )
    if duplicate_aliases:
        fail("Duplicate SOPS key aliases: " + ", ".join(duplicate_aliases))

    missing_aliases = sorted(REQUIRED_ALIASES - set(defined_aliases))
    if missing_aliases:
        fail("Missing required SOPS key aliases: " + ", ".join(missing_aliases))

    unknown_references = sorted(
        set(ALIAS_REFERENCE.findall(config)) - set(defined_aliases)
    )
    if unknown_references:
        fail("Unknown SOPS recipient aliases: " + ", ".join(unknown_references))

    if re.search(r"path_regex:\s*['\"]?secrets/\.\*\\.yaml\$", config):
        fail("SOPS must not define a fleet-wide fallback creation rule")

    rules = parse_rules(config)
    errors = []

    secret_paths = {
        path.relative_to(ROOT).as_posix()
        for path in SECRETS_DIR.glob("*.yaml")
    }
    expected_paths = set(EXPECTED_RECIPIENTS)

    for unexpected in sorted(secret_paths - expected_paths):
        errors.append(f"{unexpected}: no recipient policy is defined")

    for missing in sorted(expected_paths - secret_paths):
        errors.append(f"{missing}: recipient policy exists but the secret file does not")

    for secret_path, expected in sorted(EXPECTED_RECIPIENTS.items()):
        path = ROOT / secret_path

        if not path.is_file():
            continue

        matches = [
            block
            for pattern, block in rules
            if re.fullmatch(pattern.strip("'\""), secret_path)
        ]

        if not matches:
            errors.append(f"{secret_path}: missing explicit SOPS creation rule")
            continue

        if len(matches) > 1:
            errors.append(f"{secret_path}: matched by multiple SOPS creation rules")
            continue

        declared = rule_recipients(matches[0])

        if declared != expected:
            errors.append(
                f"{secret_path}: expected recipients {sorted(expected)}, "
                f"declared {sorted(declared)}"
            )

        try:
            encrypted = encrypted_recipients(path, alias_to_key)
        except SystemExit as exc:
            errors.append(str(exc))
            continue

        if encrypted != expected:
            errors.append(
                f"{secret_path}: expected encrypted recipients {sorted(expected)}, "
                f"found {sorted(encrypted)}"
            )

    if errors:
        fail("SOPS recipient audit failed:\n" + "\n".join(f"- {error}" for error in errors))

    print(
        f"Validated declared and encrypted recipients for "
        f"{len(EXPECTED_RECIPIENTS)} SOPS files."
    )


if __name__ == "__main__":
    main()
