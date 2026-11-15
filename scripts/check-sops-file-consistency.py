#!/usr/bin/env python3
"""Validate consistency between SOPS files, creation rules, and host policy.

This script checks that:

- Every encrypted YAML file beneath ``secrets/`` matches exactly one explicit
  SOPS creation rule.
- Every creation rule matches exactly one encrypted YAML file.
- Every matching creation rule declares at least one age recipient.
- Every encrypted file has an entry in the Nix SOPS host allowlist.
- The hosts approved in Nix exactly match the age recipient identities declared
  for that file in ``.sops.yaml``.

The operator identity (for example, ``aljam``) is intentionally excluded from
host allowlists because it is not a NixOS host.
"""

from __future__ import annotations

import pathlib
import re
import sys

try:
    import yaml
except ImportError:
    print("PyYAML is required: python3 -m pip install pyyaml", file=sys.stderr)
    raise SystemExit(1)

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOPS_CONFIG = ROOT / ".sops.yaml"
SECRETS_DIR = ROOT / "secrets"
SOPS_MODULE = ROOT / "modules" / "features" / "sops.nix"


def fail(message: str, problems: list[str]) -> None:
    """Print a grouped error and exit nonzero when problems exist."""
    if not problems:
        return

    print(f"error: {message}", file=sys.stderr)
    for problem in problems:
        print(f"  - {problem}", file=sys.stderr)

    raise SystemExit(1)


def load_config() -> dict:
    """Load and validate the top-level SOPS configuration."""
    if not SOPS_CONFIG.is_file():
        raise SystemExit(f"error: missing SOPS configuration: {SOPS_CONFIG}")

    with SOPS_CONFIG.open(encoding="utf-8") as handle:
        config = yaml.safe_load(handle)

    if not isinstance(config, dict):
        raise SystemExit(f"error: invalid SOPS configuration: {SOPS_CONFIG}")

    return config


def load_identity_aliases(config: dict) -> dict[str, str]:
    """Map age recipient values to the YAML anchor names that define them.

    ``.sops.yaml`` uses anchors such as ``&navi`` for host age keys. SOPS
    resolves those anchors while loading YAML, so the raw file is parsed with a
    regular expression to retain the human-readable identity names.
    """
    text = SOPS_CONFIG.read_text(encoding="utf-8")
    aliases: dict[str, str] = {}

    for match in re.finditer(
        r"^\s*-\s*&([A-Za-z0-9_-]+)\s+(.+?)\s*$",
        text,
        re.MULTILINE,
    ):
        identity, recipient = match.groups()
        aliases[recipient] = identity

    if not aliases:
        raise SystemExit("error: no anchored identities found in .sops.yaml")

    return aliases


def recipients_for_rule(rule: dict) -> set[str]:
    """Collect all age recipients declared directly or in key groups."""
    recipients: set[str] = set()

    for recipient in rule.get("age") or []:
        recipients.add(str(recipient))

    for group in rule.get("key_groups") or []:
        for recipient in group.get("age") or []:
            recipients.add(str(recipient))

    return recipients


def hosts_for_recipients(
    recipients: set[str],
    identity_aliases: dict[str, str],
) -> tuple[set[str], list[str]]:
    """Translate recipient values into host identities.

    Returns the recognized host identities and a list of recipients that could
    not be resolved to a known host alias.
    """
    hosts: set[str] = set()
    unresolved: list[str] = []

    for recipient in recipients:
        identity = identity_aliases.get(recipient)

        if identity is None:
            unresolved.append(recipient)
            continue

        # The operator identity is expected in recipient lists but is not a
        # NixOS host and therefore must not appear in a host allowlist.
        if identity != "aljam":
            hosts.add(identity)

    return hosts, unresolved


def parse_nix_allowlists(policy_text: str) -> dict[str, set[str]]:
    """Parse ``roles.security.sopsApprovedFiles`` entries from the SOPS module.

    The expected Nix form is::

        "secrets/example.yaml" = [ "host1" "host2" ];

    A simple parser is intentional here: it avoids adding a Nix evaluator as a
    CI dependency while still detecting drift in the policy mapping.
    """
    allowlists: dict[str, set[str]] = {}

    pattern = re.compile(
        r'"(?P<path>secrets/[A-Za-z0-9_./-]+\.yaml)"\s*=\s*\['
        r"(?P<hosts>.*?)"
        r"\];",
        re.DOTALL,
    )

    for match in pattern.finditer(policy_text):
        path = match.group("path")
        hosts = set(re.findall(r'"([A-Za-z0-9_-]+)"', match.group("hosts")))
        allowlists[path] = hosts

    return allowlists


def main() -> None:
    config = load_config()
    rules = config.get("creation_rules") or []

    if not rules:
        raise SystemExit("error: no SOPS creation rules are defined")

    identity_aliases = load_identity_aliases(config)

    encrypted_paths = sorted(
        path.relative_to(ROOT).as_posix()
        for path in SECRETS_DIR.glob("*.yaml")
    )

    if not encrypted_paths:
        raise SystemExit("error: no encrypted YAML files found beneath secrets/")

    policy_text = SOPS_MODULE.read_text(encoding="utf-8")
    nix_allowlists = parse_nix_allowlists(policy_text)

    unmatched_files: list[str] = []
    ambiguous_files: list[str] = []
    missing_recipients: list[str] = []
    unresolved_recipients: list[str] = []
    missing_nix_entries: list[str] = []
    host_mismatches: list[str] = []
    unmatched_rules: list[str] = []

    for path in encrypted_paths:
        matching = [
            rule
            for rule in rules
            if re.fullmatch(rule.get("path_regex", ""), path)
        ]

        if not matching:
            unmatched_files.append(path)
            continue

        if len(matching) > 1:
            ambiguous_files.append(
                f"{path} matches {len(matching)} creation rules"
            )
            continue

        rule = matching[0]
        recipients = recipients_for_rule(rule)

        if not recipients:
            missing_recipients.append(path)
            continue

        recipient_hosts, unresolved = hosts_for_recipients(
            recipients,
            identity_aliases,
        )

        if unresolved:
            unresolved_recipients.extend(
                f"{path}: {recipient}" for recipient in unresolved
            )

        nix_hosts = nix_allowlists.get(path)

        if nix_hosts is None:
            missing_nix_entries.append(path)
            continue

        if nix_hosts != recipient_hosts:
            missing_in_nix = sorted(recipient_hosts - nix_hosts)
            extra_in_nix = sorted(nix_hosts - recipient_hosts)

            details = []
            if missing_in_nix:
                details.append(
                    "missing from Nix allowlist: " + ", ".join(missing_in_nix)
                )

            if extra_in_nix:
                details.append(
                    "unexpected in Nix allowlist: " + ", ".join(extra_in_nix)
                )

            host_mismatches.append(f"{path}: {'; '.join(details)}")

    for rule in rules:
        pattern = rule.get("path_regex")

        if not pattern:
            unmatched_rules.append("<creation rule without path_regex>")
            continue

        matches = [
            path
            for path in encrypted_paths
            if re.fullmatch(pattern, path)
        ]

        if not matches:
            unmatched_rules.append(pattern)

    fail(
        "encrypted SOPS files without an explicit creation rule",
        unmatched_files,
    )
    fail(
        "encrypted SOPS files matched by multiple creation rules",
        ambiguous_files,
    )
    fail(
        "SOPS creation rules without age recipients",
        missing_recipients,
    )
    fail(
        "SOPS recipients that do not map to a declared identity alias",
        unresolved_recipients,
    )
    fail(
        "encrypted SOPS files missing from roles.security.sopsApprovedFiles",
        missing_nix_entries,
    )
    fail(
        "SOPS host allowlists do not match age recipients",
        host_mismatches,
    )
    fail(
        "SOPS creation rules that do not match an encrypted file",
        unmatched_rules,
    )

    print(
        f"OK: validated {len(encrypted_paths)} SOPS files and "
        f"{len(rules)} creation rules."
    )


if __name__ == "__main__":
    main()
