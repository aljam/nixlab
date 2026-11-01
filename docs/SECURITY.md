# Security policies and automated checks

This repository uses evaluation-time assertions, NixOS tests, and Gitleaks to enforce its security model.

## Enforced policies

The policies in `modules/features/security-policy.nix` are evaluated for every host:

| Policy | Reason |
|---|---|
| Every SOPS secret must declare `sopsFile` | Keeps secret access scoped to the intended service or trust boundary. |
| PostgreSQL must not contain `host all all` rules | Prevents broad database authentication access. |
| pgAdmin port 5050 must not be proxy-exposed | Keeps the administrative interface off the HAProxy backend allowlist. |
| Autobrr must not bind to `0.0.0.0` | Limits its network exposure to the host service address. |
| Recyclarr requires Servarr | Recyclarr connects to local Radarr and Sonarr instances. |
| SSH password authentication must be disabled | Enforces key-based SSH authentication. |
| Sudo must require a password when enabled | Prevents passwordless privilege escalation. |

## Secret scanning

Gitleaks scans tracked files and full Git history on pull requests, pushes to `main`, and a weekly schedule. There is intentionally no allowlist for encrypted SOPS files; investigate any finding rather than broadly excluding secret paths.

## Firewall and isolation tests

- `tests/nftables-input-rules.nix` performs fast validation of generated nftables input rules.
- `tests/firewall.nix` runs an end-to-end NixOS VM test for network isolation.

## Deferred policies

### Container image pinning

OCI container images must eventually be pinned to a version tag or SHA256 digest. A `:latest` prohibition is intentionally not enforced yet because the LiveKit, `lk-jwt-service`, and bgutil POT provider images still use floating tags.

Once those images are pinned, add this policy to `security-policy.nix`:

```nix
{
  assertion = lib.allAttrs (
    _: container: !lib.hasSuffix ":latest" container.image
  ) config.virtualisation.oci-containers.containers;
  message = "OCI container images must be pinned to a version or digest.";
}
```

### SOPS recipient audit

A future check should validate that each `secrets/*.yaml` file has a matching `.sops.yaml` creation rule and that its recipient set matches its documented trust boundary.
