# Configuration drift monitoring

## Goal

Detect meaningful differences between the intended NixOS configuration and the running state of fleet hosts, without allowing an automated process to mutate production systems.

## What counts as drift

Treat the following as drift when they differ from the declared configuration or expected operational baseline:

- The active system generation is not the latest successfully activated generation.
- Files under `/etc` differ from the configuration-managed expected state.
- A systemd unit is enabled, disabled, failed, or restarted in a way not represented by the configuration.
- A listening port, firewall rule, container, user, or enabled service is unexpected.
- A host's hostname, IP address, role, zpool, or other fleet metadata differs from `networking.fleet`.
- A SOPS secret is missing, unreadable by its intended service, or has not been rotated according to policy.
- A package, kernel, or overlay divergence was not intentionally selected.

## Initial detection checks

Start with read-only checks that can run locally on each host:

1. Compare `boot.systemd.configurationGeneration` with the newest generation available in `/nix/var/nix/profiles/system*`.
2. Inspect failed or unexpectedly enabled systemd units.
3. Inventory listening sockets and compare them with the expected service and firewall model.
4. Inventory nftables rules and compare them with the generated firewall configuration.
5. Inventory containers and compare them with enabled feature modules.
6. Validate fleet metadata against the running hostname, primary address, and declared roles.
7. Check that required SOPS secrets exist, are readable by the intended service user, and have not expired.
8. Report unexpected modifications under configuration-managed `/etc` paths.

## Reporting design

Produce a structured JSON report containing:

- Hostname and fleet role.
- Current and expected system generation.
- A list of drift findings, each with severity, category, expected value, observed value, and remediation hint.
- A timestamp and check version.
- An overall `clean`, `warning`, or `critical` status.

The checker must be read-only. It may recommend a remediation command, but it must not automatically reload, restart, redeploy, or modify host state.

## Alerting

Use the existing monitoring stack:

- Emit findings as Prometheus metrics or structured logs.
- Alert on `critical` findings immediately.
- Alert on repeated `warning` findings after a defined grace period.
- Include the host, category, and a stable finding identifier in every alert.
- Suppress known, explicitly accepted exceptions through configuration rather than manual alert silences.

## Implementation phases

1. Add a read-only drift-report command or systemd service.
2. Implement generation, systemd, listening-port, firewall, and fleet-metadata checks.
3. Add SOPS secret presence and readability checks.
4. Export results to Prometheus or structured logs.
5. Add alerts for critical and repeated warning findings.
6. Add a VM test that introduces a controlled drift condition and verifies detection.

## Acceptance criteria

- The checker never modifies host state.
- Drift findings include enough context to identify the host, category, and remediation.
- Critical findings are alertable.
- The VM test detects an intentionally introduced drift condition.
- `nix flake check --no-build --print-build-logs` passes.
