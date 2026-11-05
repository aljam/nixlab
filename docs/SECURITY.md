# Security posture

## Container images

OCI container images intentionally use floating version tags such as
`:latest` so security hotfixes can be adopted quickly on the next host
rebuild.

This favors timely patching over bit-for-bit reproducibility. Before a major
container upgrade, inspect upstream release notes and verify service health
after deployment.

## Dependency vulnerabilities

The `Vulnerability scanning` workflow runs OSV-Scanner weekly and whenever
`flake.lock` or the scanning workflow changes.

It uploads a JSON report as a workflow artifact and fails when it identifies
actionable CVE or GitHub Security Advisory findings. Review the artifact,
determine whether the affected package is present in a deployed host closure,
and prioritize a Nixpkgs or flake-input update when it is.

A finding is not automatically exploitable. Record the decision to patch,
mitigate, or accept the risk, including the affected service and compensating
control.

### Triage a finding

For each OSV finding:

1. Identify the affected package and version.
2. Determine whether that package is present in a deployed host closure:

   ```bash
   nix why-depends .#nixosConfigurations.HOSTNAME.config.system.build.toplevel \\
     nixpkgs#PACKAGE_NAME
   ```

   Replace `HOSTNAME` and `PACKAGE_NAME` with the affected host and package.

3. If the package is deployed, identify the exposed service or attack surface.
4. Choose one outcome:

   - **Patch**: update Nixpkgs, a flake input, or the affected container image.
   - **Mitigate**: restrict exposure, disable an affected feature, or apply a
     compensating control.
   - **Accept**: document why the finding does not apply, including the
     affected host, service, and review date.

5. Record the CVE/GHSA, affected hosts, decision, owner, and follow-up date in
   the security review notes.

Do not paste secret values, tokens, private keys, or decrypted secret contents
into review notes or issues.

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
- Changes to the SSH daemon configuration.
- Changes to audit logging.

Review recent security-relevant activity with:

```bash
sudo journalctl --since "24 hours ago" -u sshd -u sudo
sudo ausearch -k sudo-execution --start recent
sudo ausearch -k identity-change --start recent
sudo aureport --auth
```

For an incident, preserve logs before rebuilding or replacing the affected
host. Journal and audit logs are local by design; do not rely on them as the
only copy during a compromise.

To preserve evidence from a host before a rebuild or replacement, copy the
journals and audit logs to trusted administrative storage:

```bash
sudo journalctl --export > journal-HOSTNAME-YYYY-MM-DD.export
sudo tar -C /var/lib -czf audit-HOSTNAME-YYYY-MM-DD.tar.gz audit
```

Store exports only in an access-controlled administrative location.

## Alertmanager

Alertmanager listens only on loopback and is intentionally excluded from
`networking.proxyBackendPorts`. Prometheus reaches it locally at
`127.0.0.1:9093`.

Critical and warning alerts are relayed to the Ntfy topic configured by the
SOPS-managed `nfty-url` secret. A dedicated loopback relay service receives
Alertmanager webhooks on `127.0.0.1:9094`, formats the notification, and
forwards it to Ntfy.

Alerts are grouped by alert name and instance; unresolved alerts repeat every
four hours, and recovery notifications are sent.

The Ntfy URL is never committed to the repository. To change the destination,
update `nfty-url` in `secrets/monitoring.yaml` with SOPS and redeploy the
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
