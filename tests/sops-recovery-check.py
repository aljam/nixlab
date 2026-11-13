#!/usr/bin/env python3
"""Validate SOPS creation rules and secret recipient authorization."""

import re
import sys
from pathlib import Path

import yaml


def fail(message: str) -> None:
    print(f"FAIL: {message}")


def main() -> int:
    config_path = Path(sys.argv[1])
    secrets_dir = Path(sys.argv[2])

    config = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    rules = config.get("creation_rules", []) or []
    key_entries = config.get("keys", []) or []

    failures = []

    declared_recipients = set()
    for entry in key_entries:
        if isinstance(entry, str):
            parts = entry.split()
            if parts:
                declared_recipients.add(parts[-1])
        elif isinstance(entry, dict):
            recipient = entry.get("age") or entry.get("recipient")
            if recipient:
                declared_recipients.add(recipient)

    if not rules:
        failures.append("No SOPS creation rules are declared.")

    compiled_rules = []
    for index, rule in enumerate(rules):
        pattern = rule.get("path_regex")
        if not pattern:
            failures.append(
                f"Creation rule {index} has no path_regex; fleet-wide fallback rules are prohibited."
            )
            continue

        if re.fullmatch(r"\.\*|.*", pattern):
            failures.append(
                f"Creation rule {index} uses a catch-all path_regex; fleet-wide fallback rules are prohibited."
            )

        try:
            compiled = re.compile(pattern)
        except re.error as exc:
            failures.append(f"Creation rule {index} has an invalid path_regex: {exc}")
            continue

        recipients = []
        for group in rule.get("key_groups", []) or []:
            recipients.extend(group.get("age", []) or [])

        unauthorized = set(recipients) - declared_recipients
        if unauthorized:
            failures.append(
                f"Creation rule {index} authorizes recipients that are not declared in .sops.yaml: "
                + ", ".join(sorted(unauthorized))
            )

        compiled_rules.append((compiled, pattern, set(recipients)))

    secret_files = sorted(secrets_dir.glob("*.yaml"))
    if not secret_files:
        failures.append(f"No SOPS secret files were found under {secrets_dir}.")

    for secret_path in secret_files:
        matches = [
            (compiled, pattern, recipients)
            for compiled, pattern, recipients in compiled_rules
            if compiled.search(secret_path.name)
        ]

        if len(matches) != 1:
            failures.append(
                f"{secret_path.name} matches {len(matches)} creation rules; every secret path must have exactly one explicit rule."
            )
            continue

        _, _, authorized = matches[0]
        secret = yaml.safe_load(secret_path.read_text(encoding="utf-8")) or {}
        sops_metadata = secret.get("sops", {})
        age_entries = sops_metadata.get("age", []) or []

        recipients = {
            entry.get("recipient")
            for entry in age_entries
            if isinstance(entry, dict) and entry.get("recipient")
        }

        undeclared = recipients - declared_recipients
        if undeclared:
            failures.append(
                f"{secret_path.name} is encrypted for recipients that are not declared in .sops.yaml: "
                + ", ".join(sorted(undeclared))
            )

        unauthorized = recipients - authorized
        if unauthorized:
            failures.append(
                f"{secret_path.name} is encrypted for recipients outside its creation rule: "
                + ", ".join(sorted(unauthorized))
            )

    if failures:
        for failure in failures:
            fail(failure)
        return 1

    print(
        f"Validated {len(rules)} SOPS creation rules and {len(secret_files)} secret files."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
