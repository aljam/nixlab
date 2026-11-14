# SSH key audit

This document is a dry-run inventory of SSH identities authorized to access
nixlab hosts. It records the intended purpose, access scope, and rotation
status of each key.

SSH access is key-only. Root login is disabled, and interactive forwarding is
disabled. Members of `wheel` may log in with public keys. When the deploy
feature is enabled, members of `deploy` may also log in.

## Inventory

| Identity | Key type | Authorized user | Access scope | Purpose | Rotation status | Review rule |
|---|---|---|---|---|---|---|
| `aljam@navi` | Ed25519 | `aljam` | `wheel` on managed hosts | Interactive administration | Current | Remove when the device or key is retired. |
| Deployment key | Ed25519 | `deploy` | Forced `deploy-rebuild-ssh` command | Trigger host rebuilds from `main` | Current | Rotate if exposed, replaced, or no longer needed. |
| Nix build-client key | Ed25519 | `nix-builder` | Restricted builder access | Remote Nix builds | Current | Remove when the builder client is retired. |

## Access boundaries

| Identity | Shell | Forwarding | Root login | Command restriction |
|---|---|---|---|---|
| `aljam` | Interactive shell | Disabled | Disabled | Normal user and wheel permissions |
| `deploy` | Forced deployment wrapper | Disabled | Disabled | `deploy-rebuild switch <40-character commit hash>` only |
| `nix-builder` | Restricted builder access | Disabled | Disabled | Builder-specific restrictions |

## Current administrative key

`aljam` is authorized with one Ed25519 public key:

```text
aljam@navi
```

The key is associated with the `navi` desktop. It grants membership in
`wheel`, which permits administrative access according to the shared SSH and
sudo policy.

## Review rule

Before adding an SSH key:

1. Identify the human or service identity that owns it.
2. State the minimum access scope required.
3. Use a descriptive key comment.
4. Prefer a dedicated service identity over sharing an administrative key.
5. Add the key to the inventory above.
6. State when the key should be removed or rotated.

## Removal path

Remove an SSH key when:

- Its owning device is retired or replaced.
- Its owner no longer needs access.
- The key is suspected compromised.
- The service identity is no longer used.
- A narrower access boundary can replace broad administrative access.

## Related documentation

- [Security overview](../SECURITY.md)
- [User management](../USER-MANAGEMENT.md)
- [Deployment authorization boundary](deploy-authorization.md)
