# SOPS secret consumer audit

## Scope

This audit verifies that every `sops.secrets` declaration has:

- An explicit `sopsFile`.
- An explicit `owner`.
- Owner-only permissions (`mode = "0400"`) unless a service requires otherwise.
- A `restartUnits` or `reloadUnits` consumer, or an explicit rotation exemption.

## Policy

`modules/features/sops.nix` establishes the shared SOPS defaults. Each feature module must declare the specific encrypted file it consumes, preventing a host from implicitly receiving access to unrelated secrets.

`modules/features/security-policy.nix` enforces the following:

- Every secret declares an explicit `sopsFile`.
- Every secret declares an explicit `owner`.
- Every secret declares an explicit `mode`.
- Secrets use owner-only mode `0400`.
- Root-owned secrets must be explicitly allowlisted.
- Long-lived secrets must declare a restart or reload consumer, or be explicitly exempt.

## Inventory

The following secret areas were identified:

| Area | Secrets / consumers | Rotation follow-up |
|---|---|---|
| User passwords | `aljam_password` is consumed through `hashedPasswordFile`. | Confirm whether a password change requires a consumer restart or qualifies for an exemption. |
| Mail | `smtp_relay_password` and `mail_password_aljam` are root-owned mail credentials. | Identify the exact mail service units that consume them and add restart/reload consumers or exemptions. |
| Monitoring | `grafana-admin-password`, `grafana-secret-key`, and `ntfy-url` are consumed by Grafana and alerting. | Add the appropriate Grafana/alerting restart or reload units. |
| Database | `pgadmin_password` is consumed by pgAdmin. | Add the pgAdmin consumer unit or an exemption if it is provisioned only during initialization. |
| NAS | `nas-credentials` is consumed by the NAS mount. | Add the mount unit as a restart consumer or exempt it as a one-shot mount credential. |
| Servarr | `radarr_api_key` is consumed by Recyclarr. | Add the Recyclarr consumer unit. |
| Matrix | `livekit-jwt-env`, Matrix registration shared secret, database configuration, and `pfsense-root-ca` are consumed by Matrix/LiveKit/Prometheus. | Add the corresponding service units or exemptions. |
| Vaultwarden | `vaultwarden-admin-token` is consumed by Vaultwarden. | Add the Vaultwarden consumer unit. |
| Radio | Icecast credentials are consumed by the radio stack. | Add the relevant Icecast/Liquidsoap units or exemptions. |

## Required follow-up

For every secret without a consumer, either:

1. Add the correct `restartUnits` or `reloadUnits` value; or
2. Add it to `roles.security.sopsRotationExemptions` with a comment explaining why rotation does not require a service restart.

Do not add a consumer merely to satisfy the assertion. The consumer must be the service that actually reads or uses the decrypted credential.

## Validation

Run:

```bash
nix flake check --show-trace
```

The SOPS assertions in `modules/features/security-policy.nix` must pass for every host configuration.