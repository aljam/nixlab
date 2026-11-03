# Security posture

## Container images

OCI container images intentionally use floating version tags such as
`:latest` so security hotfixes can be adopted quickly on the next host
rebuild.

This favors timely patching over bit-for-bit reproducibility. Before a major
container upgrade, inspect upstream release notes and verify service health
after deployment.

## SOPS secrets

Secrets are service-scoped to reduce blast radius. NAS credentials are
available only to `aljam`, `navi`, and `oryx`; servers do not receive NAS
credentials.

Every secret file must have an explicit SOPS creation rule. There is no
fleet-wide fallback rule.

## Audit logging

Hosts retain persistent systemd journal logs for up to 30 days, with a 2 GiB
per-host journal cap. Audit records are stored in `/var/lib/audit` and are
restricted to `root`.

Audit rules record:

- `sudo` execution and changes to sudo policy.
- Changes to users, groups, passwords, and shadow files.
- Changes to SSH configuration and SSH-related files.
- Changes to audit configuration or audit logs.

Review recent security-relevant activity with:

```bash
sudo journalctl --since "24 hours ago" -u sshd -u sudo
sudo ausearch -k sudo-execution --start recent
sudo ausearch -k identity-change --start recent
sudo ausearch -k sshd-config-change --start recent
sudo aureport --auth
```

For an incident, preserve logs before rebuilding or replacing the affected
host. Journal and audit logs are local by design; do not rely on them as the
only copy during a compromise.

## Alertmanager

Alertmanager listens only on loopback and is intentionally excluded from
`networking.proxyBackendPorts`. Prometheus reaches it locally at
`127.0.0.1:9093`.

Critical and warning alerts are delivered to the Ntfy topic configured by the
SOPS-managed `ntfy-url` secret. Alerts are grouped by alert name and instance;
unresolved alerts repeat every four hours, and recovery notifications are
sent.

The Ntfy URL is never committed to the repository. To change the destination,
update `ntfy-url` in `secrets/monitoring.yaml` with SOPS and redeploy the
monitoring host.

## CI

CI workflows use least-privilege GitHub token permissions. Cachix uploads are
restricted to `main` pushes and manual workflow dispatches; pull requests
validate builds without performing cache uploads.

## Enforced policies

The repository enforces these invariants at evaluation time:

- Every SOPS secret declares an explicit `sopsFile`.
- PostgreSQL does not use broad `host all all` authentication rules.
- pgAdmin and PostgreSQL are not exposed through the HAProxy backend
  allowlist.
- Alertmanager is not exposed through the HAProxy backend allowlist.
- Services using `servicesBindAddress` do not bind to every interface.
- HAProxy backend ports are unique.
- Autobrr does not bind to `0.0.0.0`.
- Recyclarr requires the Servarr stack.
- Server hosts do not enable Steam or GameScope.
- SSH password authentication, interactive authentication, and direct root
  login remain disabled.
- Audit logging remains enabled.
