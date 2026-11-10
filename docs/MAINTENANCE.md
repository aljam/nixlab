# Fleet maintenance

Run these checks regularly. They complement CI, security assertions, Prometheus alerts, and the recovery runbook.

## Routine cadence

| Frequency | Task |
|---|---|
| Weekly | Review Prometheus and Alertmanager alerts. |
| Weekly | Check failed systemd units and disk-capacity trends. |
| Monthly | Review and merge the `updates` workflow PR after validation. |
| Monthly | Trigger the full-host CI workflow manually. |
| Quarterly | Complete the SOPS recipient audit in [Secrets](SECRETS.md#recipient-audit). |
| Quarterly | Complete the [security review checklist](SECURITY-REVIEW.md). |
| Quarterly | Review architecture, networking, secrets, update, and recovery docs. |

## Update flake inputs

Follow the controlled update process in [Updates](UPDATES.md).

## Validate all hosts

After merging to `main`, run **Actions -> CI -> Run workflow** on `main` to build all hosts and upload closures to Cachix.

## Review monitoring

Use [Service health checks](RUNBOOK.md#service-health-checks).

## Audit SOPS recipients

Quarterly, complete the recipient audit in [Secrets](SECRETS.md#recipient-audit).

Remove access for retired hosts, replaced SSH keys, and users without administrative needs.

## Check disk and certificates

Review filesystem usage with `df -h`. Check PostgreSQL certificate-expiry alerts; warnings begin at 14 days and become critical at 7 days.

## Keep documentation current

Update the document owning an affected topic in the same PR. See [the documentation map](README.md).