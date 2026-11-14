# Root-owned SOPS secrets

A SOPS secret may be owned by `root` only when it is consumed by a
system-level component that cannot yet use a dedicated unprivileged identity.

Root ownership is an exception, not a default. Every root-owned secret must
be listed in `roles.security.sopsAllowedRootSecrets` and must have a
documented consumer, justification, and migration target.

## Policy

New secrets should default to a dedicated service user and group.

A root-owned secret requires:

- An explicit entry in `roles.security.sopsAllowedRootSecrets`.
- A documented consumer and reason root ownership is required.
- A migration target, even if migration is not immediately practical.
- Explicit `owner`, `group`, and `mode = "0400"` in its SOPS declaration.

## Audit template

| Secret | Consumer | Why root is required | Migration target |
|---|---|---|---|
| Example | Example systemd service | Reads a mount credential before dropping privileges | Dedicated `example` user/group |

## Migration guidance

When migrating a root-owned secret:

1. Create or identify a dedicated system user and group for the consumer.
2. Change the secret's `owner` and `group` to that identity.
3. Ensure the service can read the secret after the change.
4. Remove the secret from `roles.security.sopsAllowedRootSecrets`.
5. Verify the service starts, reads only its intended secrets, and retains
   its expected functionality.

Do not broaden file permissions, add the service user to `root`, or grant
unnecessary capabilities merely to avoid migrating a secret to a dedicated
identity.
