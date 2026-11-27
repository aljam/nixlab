# nixlab agent instructions

## Scope

This repository manages multiple NixOS hosts with a shared flake.
Treat host-specific configuration as production infrastructure.

## Required workflow

1. Read the relevant module(s), host configuration, and flake inputs before proposing changes.
2. Make the smallest change that fixes the stated problem.
3. Prefer reusable modules over duplicating configuration across hosts.
4. Do not enable new services, open firewall ports, or change secrets without explicit approval.
5. Never commit, print, or move secret material.
6. Run `nix fmt` before proposing a final patch.
7. Run `nix flake check --no-build` before proposing a final patch.
8. Do not run `nixos-rebuild switch` unless explicitly instructed.
9. Return a unified diff when practical; otherwise identify exact files and changes.

## Conventions

- Use Nix module options rather than inline configuration where practical.
- Keep host modules thin; put reusable behavior in shared modules.
- Preserve existing formatting and module structure.
- Secrets are managed with sops-nix; do not add plaintext credentials.
- Do not modify generated files, lock files, or `.sops.yaml` unless explicitly requested.

## Secrets

Never read, display, modify, copy, or commit:

- `/run/secrets/**`
- `*.age`
- `secrets/**`
- `.sops.yaml`

If a task appears to require a secret, stop and ask the user.

## Deployment

- Do not assume a host is available.
- Ask which host a change targets before proposing deployment commands.
- Use `nixos-rebuild test` for a non-persistent trial only when explicitly requested.
- Use `nixos-rebuild switch` only after explicit approval.
