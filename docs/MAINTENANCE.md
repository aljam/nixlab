# Fleet maintenance

Run these checks regularly to keep the fleet healthy. They complement the
automated CI, security-policy assertions, Prometheus alerts, and recovery
runbook.

## Routine cadence

| Frequency | Task |
|---|---|
| Weekly | Review Prometheus and Alertmanager alerts. |
| Weekly | Check for failed systemd units and disk-capacity trends. |
| Monthly | Update flake inputs, review the lockfile diff, and run full validation. |
| Monthly | Trigger the full-host CI workflow manually. |
| Quarterly | Audit SOPS recipients and remove access for retired hosts or users. |
| Quarterly | Review architecture, networking, secrets, update, and recovery documentation. |

## Update flake inputs

Floating OCI image tags receive upstream updates when containers are restarted
or recreated. NixOS and other flake inputs are pinned by `flake.lock` and
should be updated deliberately.

```bash
git checkout main
git pull
nix flake update
git diff flake.lock
nix flake check --show-trace
```

Review the lockfile diff before committing. Pay particular attention to:

- NixOS/nixpkgs version changes.
- Home Manager changes.
- sops-nix changes.
- Hardware or desktop-environment input changes.

Commit the updated lockfile only after evaluation and host builds succeed.

## Validate all hosts

Pull requests build a representative host for fast feedback. After merging
changes to `main`, trigger the manual CI workflow to build all hosts and
upload their closures to Cachix.

In GitHub, go to **Actions → CI → Run workflow**, select `main`, and run the
workflow.

## Review monitoring

Check the Prometheus **Alerts** page and Alertmanager UI for active or pending
alerts.

Important signals include:

- Node exporter targets being down.
- Filesystems approaching capacity.
- Failed systemd units.
- Memory pressure.
- PostgreSQL TCP reachability.
- PostgreSQL TLS certificate expiry.

## Check service health

On each host:

```bash
systemctl --failed
systemctl --user --failed
```

For PostgreSQL on r820, also verify that the database is listening and that
the TLS certificate probe remains healthy.

## Audit SOPS recipients

SOPS access is granted through age recipients derived from host SSH keys and
configured user identities.

Periodically compare the recipients in `.sops.yaml` with the hosts and users
that should retain access.

Remove recipients for:

- Retired hosts.
- Replaced SSH host keys.
- Users who no longer require administrative access.

After changing recipients, re-encrypt every affected secret file and verify
that a representative host can still decrypt its required secrets.

## Check disk and certificates

Review filesystem usage on all hosts, especially hosts storing media, build
outputs, databases, or container layers.

```bash
df -h
```

Check the PostgreSQL certificate-expiry metric in Prometheus. The configured
alerts warn at 14 days and become critical at 7 days.

## Keep documentation current

After changing host roles, network exposure, secrets, backup plans, or
recovery procedures, update the relevant documents:

- `docs/ARCHITECTURE.md`
- `docs/NETWORKING.md`
- `docs/SECRETS.md`
- `docs/SECURITY.md`
- `docs/UPDATE.md`
- `docs/RECOVERY.md`
- `docs/USER-MANAGEMENT.md`
