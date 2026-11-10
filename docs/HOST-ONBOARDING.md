# Host onboarding

Use this checklist when adding or rebuilding a NixOS host.

## Before deployment

1. Add or update the host configuration under the host directory.
2. Add or update hardware-specific configuration when needed.
3. Assign the appropriate role or roles.
4. Enable only the feature modules the host needs.
5. Add the host to the fleet networking configuration.
6. Add or update SOPS recipients and secret files.
7. Run nix flake check.

## Deploy

For a local host:

```bash
sudo nixos-rebuild switch --flake .#navi
```

For a remote host:

```bash
nixos-rebuild switch --flake .#r730xd --target-host root@r730xd
```

## Verify

Use the shared service-health checks in the runbook after deployment.

- Confirm the host appears in monitoring.
- Confirm required services are active.
- Confirm SOPS secrets decrypt successfully.
- Confirm firewall and service-exposure checks pass.
- Confirm backups and snapshots are configured where applicable.

## Recovery

If the host cannot boot normally, follow the recovery runbook.

If SSH host keys change, follow the SOPS recipient-change procedure.
