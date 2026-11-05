# Service enable flag audit

## Scope

This audit establishes a consistent convention for feature-module enable flags. It covers Grafana, Prometheus, PostgreSQL, Vaultwarden, and Homepage.

## Convention

Every optional service feature module should expose:

```nix
options.modules.features.<name>.enable =
  lib.mkEnableOption "<human-readable service name>";
```

Service configuration must be gated on that option:

```nix
config = lib.mkIf cfg.enable {
  # service configuration
};
```

## Inventory

| Feature | Expected option | Current follow-up |
|---|---|---|
| Grafana | `modules.features.grafana.enable` | Verify that all Grafana configuration is gated by the enable flag. |
| Prometheus server | `modules.features.prometheus-server.enable` | Verify that scrape jobs, exporters, and related configuration respect the flag. |
| PostgreSQL | `modules.features.postgres.enable` | Verify that PostgreSQL, pgAdmin, and database-related configuration respect the flag. |
| Vaultwarden | `modules.features.vaultwarden.enable` | Verify that Vaultwarden and its SOPS secret configuration respect the flag. |
| Homepage | `modules.features.homepage.enable` | Verify that Homepage and its dashboard configuration respect the flag. |

## Rules

- Do not enable a service implicitly by importing its module.
- Keep feature-specific options namespaced beneath `modules.features.<name>`.
- Use `lib.mkIf cfg.enable` for all service-specific configuration.
- Avoid unconditional `sops.secrets`, systemd units, users, groups, firewall rules, or reverse-proxy backends in optional service modules.
- Ensure dependent features declare their dependency explicitly, such as Recyclarr requiring the Servarr stack.

## Follow-up

For each service above:

1. Confirm that its enable option exists and uses `mkEnableOption`.
2. Confirm that every service-specific setting is gated by `cfg.enable`.
3. Move any unconditional service configuration behind the enable gate.
4. Add or update a NixOS test that evaluates both the disabled and enabled configurations.

## Validation

Run:

```bash
nix flake check --show-trace
```

All host configurations and service tests must evaluate successfully with the updated enable-flag conventions.