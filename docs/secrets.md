# SOPS secret inventory

This inventory records every SOPS-encrypted secret, the host or service that consumes it, and its expected ownership and permissions.

NixOS policy requires every `sops.secrets` entry to declare an explicit `sopsFile`, `owner`, and `mode`; decrypted files must use owner-only mode `0400`.

## Inventory

| Secret | SOPS file | Host | Consuming service | Owner | Mode | Rotation |
|---|---|---|---|---|---|---|
| Example API token | `secrets/hosts/example/example.yaml` | `example` | `example.service` | `example` | `0400` | Every 90 days |

## Adding a secret

1. Create or update the host-scoped SOPS file under `secrets/hosts/<host>/`.
2. Encrypt it with the intended host key only; avoid granting unrelated hosts decryption access.
3. Declare the secret in the consuming NixOS module with explicit `sopsFile`, `owner`, and `mode = "0400"`.
4. Add a row to this inventory, including the consumer and rotation interval.
5. Run `nix flake check` before committing.

## Rotating a secret

1. Generate the replacement credential.
2. Update the SOPS file with `sops`.
3. Update the consuming service configuration if its secret name or format changes.
4. Deploy the affected host.
5. Verify the service health and update the rotation date in this inventory.
