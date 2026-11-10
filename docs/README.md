# Documentation map

Use this map to find the canonical guide for each concern.

| Concern | Canonical document |
|---|---|
| Repository architecture | [Architecture](ARCHITECTURE.md) |
| Modules and features | [Modules](MODULES.md) |
| Planned updates and deployments | [Updates](UPDATES.md) |
| Unexpected failures and recovery | [Recovery](RECOVERY.md) |
| Routine health checks | [Runbook](RUNBOOK.md) |
| Disk health | [Disk health](DISK-HEALTH.md) |
| Recurring maintenance | [Maintenance](MAINTENANCE.md) |
| Monitoring and alerts | [Monitoring](MONITORING.md) |
| Backups and restoration | [Backups](BACKUPS.md) |
| Host onboarding | [Host onboarding](HOST-ONBOARDING.md) |
| Secret policy and SOPS procedures | [Secrets](SECRETS.md) |
| Security policy | [Security](SECURITY.md) |
| Recurring security review | [Security review](SECURITY-REVIEW.md) |
| Authentication | [Authentication](AUTHENTICATION.md) |
| User lifecycle | [User management](USER-MANAGEMENT.md) |
| Networking | [Networking](NETWORKING.md) |
| Public services | [Public services](PUBLIC_SERVICES.md) |
| Public endpoint inventory | [Public endpoints](public-endpoints.json) |
| Mail | [Mail](MAIL.md) |
| Contribution and review | [Code review](CODE_REVIEW.md) |
| Binary cache | [Cachix](../CACHIX.md) |
| Historical audits | [Audit history](audits/) |

## Reading order

1. Read the repository [README](../README.md).
2. Read [Architecture](ARCHITECTURE.md).
3. Read [Modules](MODULES.md) to understand reusable configuration.
4. Read [Secrets](SECRETS.md) before changing encrypted configuration.
5. Use [Updates](UPDATES.md) for planned deployments.
6. Use [Runbook](RUNBOOK.md) for routine checks and first response.
7. Use [Monitoring](MONITORING.md) for observability and alert response.
8. Use [Backups](BACKUPS.md) for backup and restore workflows.
9. Use [Recovery](RECOVERY.md) for failures and data restoration.
10. Use [Host onboarding](HOST-ONBOARDING.md) when adding or rebuilding a host.

## Keeping documentation current

Update the document that owns an affected topic in the same pull request.
At minimum, review this map and the relevant operational, security,
networking, recovery, or secrets guide.
