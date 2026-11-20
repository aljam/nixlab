# Backup integrity and retention audit

Use this audit to periodically verify that backups are fresh, complete, protected, and recoverable. It complements restore drills by checking the ongoing health and governance of the backup system.

This audit must not expose repository credentials, backup contents, or sensitive file paths. Record repository references, snapshot IDs, policy outcomes, and follow-up actions only.

## Audit objective

For every protected service and data set, verify that:

- A recent successful backup exists within the recovery-point objective.
- The backup repository is accessible with least-privileged credentials.
- Repository integrity checks pass at the required cadence.
- Retention policies retain an appropriate recovery history.
- Backup failures, missed schedules, and integrity failures are detected and remediated.
- Repository credentials and backup artifacts are protected from unauthorized access.
- Restore readiness is validated through the applicable restore drill.

## Audit cadence

| Check | Minimum cadence | Owner | Evidence to retain |
|---|---|---|---|
| Backup job success and freshness | Daily | Backup operator | Job status, snapshot ID, timestamp, and alert status |
| Repository accessibility | Weekly | Backup operator | Repository type, access result, and timestamp |
| Repository integrity check | Monthly | Backup operator | Check scope, result, duration, and snapshot ID |
| Retention-policy review | Monthly | Backup operator | Policy, retained snapshots, and exceptions |
| Credential and access review | Quarterly | Security owner | Access list, credential rotation status, and exceptions |
| Restore drill | Quarterly, or after material backup changes | Recovery owner | Restore drill record and service validation result |
| Full audit review | Quarterly | Backup and security owners | Completed checklist, findings, and remediation plan |

## Before the audit

- [ ] Identify every service and data set covered by backups.
- [ ] Identify the Restic repository or other backup repository used for each data set.
- [ ] Identify the recovery-point objective for each service.
- [ ] Identify the retention policy for each repository.
- [ ] Confirm the audit environment cannot modify production backups or production service state.
- [ ] Confirm audit credentials use least privilege and are available through the approved secret manager.
- [ ] Confirm monitoring and alerting are active for backup failures and repository issues.

## Backup freshness

For each protected service or data set:

- [ ] Identify the latest successful backup snapshot.
- [ ] Record the snapshot ID and snapshot time.
- [ ] Confirm the snapshot age is within the recovery-point objective.
- [ ] Confirm the backup job completed successfully.
- [ ] Confirm the backup included the expected paths, databases, or artifacts.
- [ ] Confirm no expected backup is missing, failed, or stale.
- [ ] Confirm backup failures generated an alert or incident record.
- [ ] Confirm any stale or failed backup has an owner and remediation deadline.

## Repository access

For each backup repository:

- [ ] Confirm the repository is reachable using the expected credentials.
- [ ] Confirm the repository type and location are documented without exposing credentials.
- [ ] Confirm the credentials used for the audit are read-only where possible.
- [ ] Confirm credentials are stored in the approved secret manager.
- [ ] Confirm credentials are not embedded in repository configuration, scripts, logs, or documentation.
- [ ] Confirm access is limited to the operators and services that require it.
- [ ] Confirm access reviews identify unused or excessive permissions.
- [ ] Confirm credential rotation or replacement plans exist for exposed or aging credentials.

## Repository integrity

For each Restic repository:

- [ ] Run the scheduled repository integrity check:

  ```console
  restic check
  ```

- [ ] Use `--read-data` only when a full data verification is scheduled and the repository and environment can support it.
- [ ] Record the check scope, result, duration, and timestamp.
- [ ] Confirm the check completed without missing packs, corruption, or fatal errors.
- [ ] Confirm integrity failures generated an alert or incident record.
- [ ] Confirm repository repair or cleanup actions are documented and approved before execution.
- [ ] Confirm that no repository data is deleted until the cause and recovery impact are understood.

## Retention policy

For each repository:

- [ ] Confirm the retention policy is documented.
- [ ] Confirm the policy retains enough recovery points to meet the recovery-point objective.
- [ ] Confirm the policy retains an appropriate long-term recovery history.
- [ ] Confirm retention rules do not delete the only usable recovery point.
- [ ] Confirm expired snapshots are removed only through the approved retention process.
- [ ] Confirm retention jobs complete successfully.
- [ ] Confirm retention failures generate an alert or incident record.
- [ ] Confirm storage capacity remains sufficient for current and projected retention needs.
- [ ] Confirm retention exceptions have an owner, justification, and expiration date.

## Recovery readiness

For each protected service or data set:

- [ ] Confirm the applicable restore drill has been completed within its required cadence.
- [ ] Confirm the latest restore drill used a recovery point within the recovery-point objective.
- [ ] Confirm the restore drill validated repository access, integrity, restoration, and service usability.
- [ ] Confirm any restore-drill failures have an owner and remediation plan.
- [ ] Confirm recovery documentation is current and linked from the service recovery matrix.
- [ ] Confirm recovery roles and escalation paths are documented.

## Monitoring and alerting

- [ ] Confirm monitoring detects backup-job failure.
- [ ] Confirm monitoring detects missed or stale backups.
- [ ] Confirm monitoring detects repository-access failure.
- [ ] Confirm monitoring detects repository-integrity failure.
- [ ] Confirm monitoring detects retention-job failure.
- [ ] Confirm monitoring detects insufficient repository or local storage capacity.
- [ ] Confirm alerts route to an accountable owner.
- [ ] Confirm alert severity matches the potential recovery impact.
- [ ] Confirm alert acknowledgements and remediation actions are recorded.

## Security review

- [ ] Confirm backup repositories are encrypted at rest where supported.
- [ ] Confirm backup credentials use least privilege.
- [ ] Confirm repository access is limited to approved operators and services.
- [ ] Confirm backup artifacts are not publicly accessible.
- [ ] Confirm repository URLs, credentials, and connection strings are not committed to the repository.
- [ ] Confirm audit logs do not contain secrets or sensitive backup contents.
- [ ] Confirm access changes are reviewed and approved.
- [ ] Confirm break-glass access is protected and documented.
- [ ] Confirm backup deletion or retention changes require appropriate approval.

## Findings and remediation

Classify each finding as:

- **Critical:** A backup is missing, stale beyond the recovery-point objective, corrupted, inaccessible, or cannot be restored.
- **High:** Retention, monitoring, access, or integrity controls create a material recovery risk.
- **Medium:** A control is incomplete, undocumented, or inconsistently applied.
- **Low:** Documentation, hygiene, or reporting improvement is needed.

For every finding:

- [ ] Record the affected service, repository, snapshot, and control.
- [ ] Record the severity and business impact.
- [ ] Assign an owner and remediation deadline.
- [ ] Record the remediation plan and verification method.
- [ ] Confirm critical findings are treated as recoverability incidents.
- [ ] Confirm remediation is verified before the finding is closed.

## Pass criteria

The audit passes only when:

- Every protected service has a recent successful backup within its recovery-point objective.
- Every repository is accessible with least-privileged credentials.
- Required integrity checks pass.
- Retention policies retain adequate recovery history.
- Monitoring detects backup, access, integrity, retention, and capacity failures.
- Restore drills are current and successful.
- No critical or high finding remains unowned or unremediated.
- Results, findings, and follow-up actions are recorded.

## Related documentation

- `docs/runbooks/service-recovery-matrix.md`
- `docs/runbooks/restic-restore-drill.md`
- `docs/runbooks/postgresql-restore-drill.md`
- `docs/runbooks/matrix-recovery-matrix.md`
- `docs/runbooks/incident-severity.md`
- `docs/runbooks/incident-evidence.md`
- `docs/RECOVERY.md`
- `docs/BACKUPS.md`
- `docs/audits/incident-response-recovery.md`
