# Flake lock update policy

## Goal

Treat `flake.lock` updates as deliberate, reviewable changes rather than incidental edits.

## Policy

- Update `flake.lock` in a dedicated commit or pull request.
- Do not mix unrelated code changes with a lock-file update.
- Document the reason for the update in the commit message or pull-request description.
- Identify the inputs being updated and the expected effect.
- Validate the updated lock before merging.
- Do not update a lock file solely to silence a stale-dependency warning.

## Validation

Run:

```console
nix flake check --no-build --print-build-logs
```

For broader changes, run:

```console
nix flake check --show-trace
```

## Acceptance criteria

- Every `flake.lock` update is intentional and documented.
- The reason for the update is visible in the commit message or pull-request description.
- The updated lock passes validation before merge.
