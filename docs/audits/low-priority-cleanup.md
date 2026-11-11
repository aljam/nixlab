# Low-priority cleanup backlog

## gen1recomp.desktop

- Review and clean up `gen1recomp.desktop`.
- Remove unused entries, clarify metadata, and ensure the desktop entry follows the intended conventions.
- Validate that the resulting desktop entry remains functional.

## Supported-system centralization

- Centralize the list of supported systems in one shared Nix location.
- Replace duplicated system lists across modules, hosts, and checks where appropriate.
- Ensure all consumers import the shared definition rather than maintaining separate copies.

## flake.lock update policy

- Treat `flake.lock` updates as deliberate, reviewable changes rather than incidental edits.
- Update the lock file in a dedicated commit or PR when dependency changes are intended.
- Document the reason for the update in the commit message or PR description.
- Validate the updated lock with `nix flake check --no-build --print-build-logs` before merging.

## Acceptance criteria

- No duplicated supported-system definitions remain.
- `gen1recomp.desktop` is clean and functional.
- `flake.lock` changes are intentional, documented, and validated.
