#!/usr/bin/env python3
"""Check repository security invariants that are cheap to verify statically."""

import json
import pathlib
import re
import subprocess
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent


class InvariantError(Exception):
    pass


def nix_eval_json(expression: str):
    result = subprocess.run(
        ["nix", "eval", "--json", expression],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def check_proxy_exposure():
    internal_only = nix_eval_json(
        ".#nixosConfigurations.r730xd.config.networking.internalOnlyPorts"
    )
    proxy_backends = nix_eval_json(
        ".#nixosConfigurations.r730xd.config.networking.proxyBackendPorts"
    )

    exposed_internal = sorted(set(internal_only) & set(proxy_backends))
    if exposed_internal:
        ports = ", ".join(str(port) for port in exposed_internal)
        raise InvariantError(
            f"Internal-only ports must not be exposed through the HAProxy backend allowlist: {ports}"
        )

    duplicates = sorted(
        {port for port in proxy_backends if proxy_backends.count(port) > 1}
    )
    if duplicates:
        ports = ", ".join(str(port) for port in duplicates)
        raise InvariantError(
            f"HAProxy backend ports must not contain duplicates: {ports}"
        )


def check_sops_owners():
    expected_owners = nix_eval_json(
        ".#nixosConfigurations.r730xd.config.roles.security.sopsExpectedOwners"
    )
    secrets = nix_eval_json(
        ".#nixosConfigurations.r730xd.config.sops.secrets"
    )

    mismatches = []
    for name, expected_owner in expected_owners.items():
        secret = secrets.get(name)
        if secret is None:
            continue

        actual_owner = secret.get("owner")
        if actual_owner != expected_owner:
            mismatches.append(
                f"{name}: expected {expected_owner}, got {actual_owner}"
            )

    if mismatches:
        raise InvariantError(
            "SOPS secrets must be owned by their expected consuming service:\n"
            + "\n".join(f"- {mismatch}" for mismatch in mismatches)
        )


def check_deploy_command_boundary():
    deploy_module = (REPO_ROOT / "modules/features/deploy-user.nix").read_text()

    permitted_pattern = re.compile(
        r"\^deploy-rebuild\\\\ switch\\\\ \(\[0-9a-f\]\{40\}\)\$"
    )

    if not permitted_pattern.search(deploy_module):
        raise InvariantError(
            "The deployment SSH wrapper must permit only "
            "'deploy-rebuild switch <full 40-character commit hash>'."
        )


def main() -> int:
    checks = [
        ("proxy exposure", check_proxy_exposure),
        ("SOPS ownership", check_sops_owners),
        ("deployment command boundary", check_deploy_command_boundary),
    ]

    failures = []
    for name, check in checks:
        try:
            check()
        except InvariantError as error:
            failures.append(f"{name}: {error}")
        except Exception as error:
            failures.append(f"{name}: unexpected error: {error}")

    if failures:
        print("Security invariant check failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("Security invariants passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
