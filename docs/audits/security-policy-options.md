# Security policy option audit

## Scope

This audit maps the repository's security assertions to the options they validate and to the module that owns each one. The policy modules are imported on every host through `modules/roles/common.nix`: `modules/features/security-policy.nix`, `modules/features/sops.nix` for SOPS, and `modules/features/ssh.nix` for SSH. Each assertion is declared once; service modules do not repeat them.

## Assertion inventory

| Policy area | Owner | Options validated | Required behavior |
|---|---|---|---|
| SOPS file source | `sops.nix` | `sops.secrets.<name>.sopsFile` | Every secret must explicitly declare its encrypted source file. |
| SOPS ownership | `sops.nix` | `sops.secrets.<name>.owner` | Every secret must explicitly declare its owning identity. |
| SOPS permissions | `sops.nix` | `sops.secrets.<name>.mode` | Every secret must explicitly declare its mode and use owner-only `0400`. |
| Root-owned secrets | `sops.nix` | `sops.secrets.<name>.owner`, `roles.security.sopsAllowedRootSecrets` | Root-owned secrets must be explicitly allowlisted. |
| Expected secret owners | `security-policy.nix` | `sops.secrets.<name>.owner`, `roles.security.sopsExpectedOwners` | A mapped secret must be owned by its consuming service. |
| Grafana access | `security-policy.nix` | `networking.proxyBackendPorts`, `services.grafana.settings."auth.anonymous".enabled`, `services.grafana.settings.users.allow_sign_up` | Exposed Grafana must disable anonymous access and self-registration. |
| PostgreSQL authentication | `security-policy.nix` | `services.postgresql.authentication`, `services.postgresql.settings.port`, `networking.proxyBackendPorts` | PostgreSQL must not use broad `host all all` rules, remote rules must use TLS, and its port must not be exposed through HAProxy. |
| Internal service exposure | `security-policy.nix` | `networking.proxyBackendPorts` | pgAdmin, Prometheus, Blackbox exporter, and Alertmanager ports must not be exposed through HAProxy. |
| Service binding | `security-policy.nix` | `networking.servicesBindAddress` | The shared service bind address must not bind to every interface. |
| HAProxy ports | `security-policy.nix` | `networking.proxyBackendPorts` | Backend ports must not contain duplicates. |
| Autobrr binding | `security-policy.nix` | `services.autobrr.enable`, `services.autobrr.settings.host` | Autobrr must not bind to every interface. |
| Recyclarr dependency | `security-policy.nix` | `modules.features.recyclarr.enable`, `servarr.enable` | Recyclarr requires the Servarr stack. |
| Server gaming | `security-policy.nix` | `roles.server.enable`, `programs.steam.enable`, `programs.gamescope.enable` | Gaming software must not be enabled on server hosts. |
| Sudo | `security-policy.nix` | `security.sudo.enable`, `security.sudo.wheelNeedsPassword` | Sudo must require a password when enabled. |
| SSH | `ssh.nix` | `services.openssh.settings.PasswordAuthentication`, `PermitRootLogin`, `KbdInteractiveAuthentication` | SSH must stay key-only with root login disabled. |

## Findings

- The SOPS assertions correctly enforce explicit source files, owners, modes, owner-only permissions, and auditable root ownership.
- The Grafana assertions correctly apply only when port 3000 is present in the HAProxy backend allowlist. Grafana's anonymous-access section is the single attribute `"auth.anonymous"`; the nested path `auth.anonymous` does not exist, so an assertion reading it with an `or false` fallback can never fail.
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

All assertions must pass for every host configuration.