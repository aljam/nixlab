# Root-owned SOPS secrets

SOPS secrets are normally owned by the unprivileged service identity that
consumes them. Root ownership is an exception because it increases the impact
of a compromise or configuration error.

The SOPS module enforces this boundary:

- Every secret must declare an explicit `sopsFile`, owner, and group.
- Every secret must use owner-only mode `0400`.
- A secret owned by `root` must appear in
  `roles.security.sopsAllowedRootSecrets`.
- Secret owners and groups must be declared system identities.

## Current exceptions

| Secret | Why root ownership is required | Consumer | Review rule |
|---|---|---|---|
| `nas-credentials` | Used by a system-level mount or storage integration that runs before a dedicated service identity is available. | Root-managed mount/storage process | Keep root ownership only while no dedicated unprivileged mount identity exists; revisit when the mount is service-scoped. |
| `smtp_relay_password` | Used by system-level mail relay configuration that must be readable before a dedicated mail service identity is established. | Root-managed mail relay configuration | Prefer a dedicated mail service identity when the relay consumer is service-scoped. |
| `mail_password_aljam` | Used by system-level mail configuration tied to the administrative mail account. | Root-managed mail configuration | Prefer a dedicated mail service identity when the consumer is service-scoped. |
| `livekit-jwt-env` | Used by a system-level service environment that requires credentials before a dedicated service identity is established. | Root-managed LiveKit environment | Prefer a dedicated LiveKit service identity when the consumer is service-scoped. |

## Review rule

Do not add a root-owned SOPS secret merely because it is convenient.

A new root-owned secret is justified only when all of the following are true:

- The consuming process is genuinely system-level or must run before a
  dedicated service identity is available.
- A dedicated unprivileged owner and group cannot safely consume the secret.
- The secret is explicitly listed in
  `roles.security.sopsAllowedRootSecrets`.
- The exception and its consumer are documented in this file.

When adding an exception:

1. Add the secret name to `roles.security.sopsAllowedRootSecrets`.
2. Declare the secret with explicit `owner`, `group`, `sopsFile`, and
   `mode = "0400"`.
3. Add a row to the table above.
4. State the concrete consumer and the condition under which root ownership
   can be removed.

## Removal path

Prefer migrating a root-owned secret to a dedicated service identity when:

- The consumer is a long-running service.
- The service can be configured with a dedicated system user and group.
- The service can read the secret after activation rather than during early
  system startup.
- The migration does not create a broader permission boundary than root
  ownership.

Root ownership should be treated as a temporary, documented exception—not a
default security posture.
