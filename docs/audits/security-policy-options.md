# Security policy option audit

## Scope

This audit maps the assertions in `modules/features/security-policy.nix` to the options they validate. It establishes a baseline for keeping security assertions aligned with the options they are intended to protect.

## Assertion inventory

| Policy area | Options validated | Required behavior |
|---|---|---|
| SOPS file source | `sops.secrets.<name>.sopsFile` | Every secret must explicitly declare its encrypted source file. |
| SOPS ownership | `sops.secrets.<name>.owner` | Every secret must explicitly declare its owning identity. |
| SOPS permissions | `sops.secrets.<name>.mode` | Every secret must explicitly declare its mode and use owner-only `0400`. |
| Root-owned secrets | `sops.secrets.<name>.owner`, `roles.security.sopsAllowedRootSecrets` | Root-owned secrets must be explicitly allowlisted. |
| Grafana access | `networking.proxyBackendPorts`, `services.grafana.settings.auth.anonymous.enabled`, `services.grafana.settings.users.allow_sign_up` | Exposed Grafana must disable anonymous access and self-registration. |
| PostgreSQL authentication | `services.postgresql.authentication`, `services.postgresql.settings.port`, `networking.proxyBackendPorts` | PostgreSQL must not use broad `host all all` rules, remote rules must use TLS, and its port must not be exposed through HAProxy. |
| Internal service exposure | `networking.proxyBackendPorts` | pgAdmin, Prometheus, Blackbox exporter, and Alertmanager ports must not be exposed through HAProxy. |
| Service binding | `networking.servicesBindAddress` | The shared service bind address must not bind to every interface. |
| HAProxy ports | `networking.proxyBackendPorts` | Backend ports must not contain duplicates. |
| Autobrr binding | `services.autobrr.enable`, `services.autobrr.settings.host` | Autobrr must not bind to every interface. |
| Recyclarr dependency | `modules.features.recyclarr.enable`, `servarr.enable` | Recyclarr requires the Servarr stack. |
| Server gaming | `roles.server.enable`, `programs.steam.enable`, `programs.gamescope.enable` | Gaming software must not be enabled on server hosts. |
| Sudo | `security.sudo.enable`, `security.sudo.wheelNeedsPassword` | Sudo must require a password when enabled. |
| SSH | `services.openssh.enable`, `services.openssh.settings.PasswordAuthentication` | SSH password authentication must remain disabled. |

## Findings

- The SOPS assertions correctly enforce explicit source files, owners, modes, owner-only permissions, and auditable root ownership.
- The Grafana assertions correctly apply only when port 3000 is present in the HAProxy backend allowlist.
- The PostgreSQL assertions distinguish loopback clients from remote clients and require `hostssl` for remote access.
- The internal-service exposure list includes pgAdmin, Prometheus, Blackbox exporter, and Alertmanager.
- The Recyclarr dependency correctly requires `servarr.enable`.
- The gaming assertion correctly applies only when the server role is enabled.

## Follow-up

- Keep this inventory synchronized whenever an assertion or relevant module option changes.
- When adding a new security assertion, add its option mapping to this document in the same change.
- When an option is renamed or its semantics change, update both the assertion and this audit before merging.

## Validation

Run:

```bash
nix flake check --show-trace
```

All assertions in `modules/features/security-policy.nix` must pass for every host configuration.