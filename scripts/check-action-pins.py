#!/usr/bin/env python3
"""Require third-party GitHub Actions to be pinned to full commit SHAs."""

from __future__ import annotations

import pathlib
import re
import sys

WORKFLOW_DIR = pathlib.Path(".github/workflows")

# Temporary exceptions for existing mutable action references. Remove each
# entry after resolving its full commit SHA and updating the workflow.
ALLOWED_MUTABLE_REFS = {
    "gitleaks/gitleaks-action@v3",
    "DeterminateSystems/nix-installer-action@v23",
}

USES_RE = re.compile(r"^\s*-?\s*uses:\s*['\"]?([^'\"\s]+)['\"]?\s*$", re.MULTILINE)
FULL_SHA_RE = re.compile(r"^[0-9a-f]{40}$")


def main() -> int:
    failures: list[str] = []

    for workflow in sorted(WORKFLOW_DIR.glob("*.yml")):
        for match in USES_RE.finditer(workflow.read_text(encoding="utf-8")):
            action = match.group(1)

            # Local composite actions and reusable workflows are repository
            # content and do not require an external commit pin.
            if action.startswith("./"):
                continue

            if "@" not in action:
                failures.append(f"{workflow}: action reference has no version or SHA: {action}")
                continue

            owner_repo, ref = action.rsplit("@", 1)

            if FULL_SHA_RE.fullmatch(ref):
                continue

            if action in ALLOWED_MUTABLE_REFS:
                continue

            failures.append(
                f"{workflow}: third-party action must use a full 40-character commit SHA: {action}"
            )

    if failures:
        print("GitHub Actions must be pinned to full commit SHAs:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("All third-party GitHub Actions use approved commit SHAs or explicit exceptions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
