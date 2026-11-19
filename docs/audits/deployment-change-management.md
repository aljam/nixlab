# Deployment and change-management audit

Use this audit to periodically verify that production changes are authorized, traceable, tested, deployable, and recoverable.

This audit must not expose secrets, tokens, passwords, private keys, or sensitive deployment data. Record deployment targets, commit SHAs, workflow results, rollback procedures, findings, and remediation actions only.

## Audit objective

For every production deployment path, verify that:

- Changes are reviewed, approved, and traceable to a source revision.
- Deployments use a clean working tree and an explicit, full commit SHA.
- CI validates the intended change before deployment.
- Deployment credentials use least privilege and are not exposed.
- Rollback procedures are documented and tested where feasible.
- Post-deployment verification confirms service health and intended behavior.
- Failed or unauthorized deployments are detected, investigated, and remediated.

## Audit cadence

| Check | Minimum cadence | Owner | Evidence to retain |
|---|---|---|---|
| Deployment authorization review | Monthly | Platform owner | Deployment paths, approvals, and exceptions |
| Deployment traceability review | Monthly | Platform owner | Commit SHAs, workflow runs, and deployment records |
| CI and test coverage review | Monthly | Service owner | Workflow results, test coverage, and exceptions |
| Secret and credential review | Monthly | Security owner | Credential scope, storage, and exposure findings |
| Rollback readiness review | Quarterly | Platform owner | Rollback procedure, test result, and exceptions |
| Deployment drill | Quarterly, or after material deployment changes | Platform owner | Deployment record, verification result, and rollback result |
| Full audit review | Quarterly | Platform, service, and security owners | Completed checklist, findings, and remediation plan |

## Before the audit

- [ ] Identify every production deployment path and target host.
- [ ] Identify the deployment tool, workflow, and authorization mechanism.
- [ ] Identify the source repository, branch, and commit-SHA policy.
- [ ] Identify the CI workflows required before deployment.
- [ ] Identify the rollback procedure for each deployment target.
- [ ] Identify the post-deployment verification checks.
- [ ] Confirm the audit environment cannot modify production deployment configuration or trigger production deployments.
- [ ] Confirm audit credentials use least privilege and are available through the approved secret manager.
- [ ] Confirm recent deployments, workflow runs, incidents, and rollbacks are available for review.

## Deployment authorization

For each deployment path:

- [ ] Confirm the deployment target and authorized operators are documented.
- [ ] Confirm deployment requires an approved pull request or change record.
- [ ] Confirm production deployments cannot be triggered by unapproved identities.
- [ ] Confirm deployment credentials use least privilege.
- [ ] Confirm deployment credentials are stored in the approved secret manager.
- [ ] Confirm deployment credentials are not embedded in code, configuration, logs, or documentation.
- [ ] Confirm deployment actions are logged or auditable.
- [ ] Confirm unauthorized deployment attempts generate an alert where supported.
- [ ] Confirm deployment approvals are recorded.

## Clean working tree

For each deployment path:

- [ ] Confirm the deployment procedure refuses to deploy from a dirty working tree.
- [ ] Confirm the guard exits with a clear error and a non-zero status.
- [ ] Confirm uncommitted changes, untracked files, and staged changes are detected.
- [ ] Confirm the guard cannot be bypassed through an undocumented deployment path.
- [ ] Confirm the guard is covered by an automated test where feasible.
- [ ] Confirm deployment failures preserve sufficient output for investigation.
- [ ] Confirm the guard does not expose secrets or sensitive file contents.
- [ ] Confirm guard changes are reviewed and tested.

## Commit traceability

For each production deployment:

- [ ] Confirm the deployment records the exact full commit SHA.
- [ ] Confirm abbreviated SHAs are not accepted as deployment identifiers.
- [ ] Confirm the deployed commit exists in the intended source repository.
- [ ] Confirm the deployed commit is associated with an approved pull request or change record.
- [ ] Confirm the deployed commit has passed the required CI checks.
- [ ] Confirm the deployed revision matches the intended target host or service.
- [ ] Confirm deployment records include the operator, timestamp, target, and result.
- [ ] Confirm deployment history is retained and discoverable.
- [ ] Confirm unapproved or unexpected deployments are investigated.

## CI and testing

For each deployment path:

- [ ] Confirm required CI workflows run before deployment.
- [ ] Confirm CI checks include build, lint, formatting, and tests where applicable.
- [ ] Confirm deployment-specific tests validate critical guard behavior.
- [ ] Confirm CI failures block deployment.
- [ ] Confirm CI workflow permissions use least privilege.
- [ ] Confirm CI secrets are stored in the approved secret manager.
- [ ] Confirm CI logs do not expose secrets, tokens, private keys, or sensitive deployment data.
- [ ] Confirm workflow changes are reviewed and tested.
- [ ] Confirm skipped or failed checks have an owner and remediation plan.

## Rollback readiness

For each deployment target:

- [ ] Confirm a documented rollback procedure exists.
- [ ] Confirm the rollback procedure identifies the prior known-good revision or generation.
- [ ] Confirm rollback can be performed without exposing secrets or modifying unrelated systems.
- [ ] Confirm rollback authorization and execution steps are documented.
- [ ] Confirm rollback has been tested where feasible.
- [ ] Confirm rollback tests verify service health and intended behavior.
- [ ] Confirm rollback failures have an owner and remediation plan.
- [ ] Confirm rollback procedures are linked to the service recovery matrix.

## Post-deployment verification

For each production deployment:

- [ ] Confirm the deployment completes successfully.
- [ ] Confirm the target service starts or reloads successfully.
- [ ] Confirm service health checks pass.
- [ ] Confirm monitoring remains healthy after deployment.
- [ ] Confirm a representative functional check succeeds.
- [ ] Confirm the deployed revision is recorded in the deployment record.
- [ ] Confirm deployment failures generate an alert or incident record.
- [ ] Confirm post-deployment failures have an owner and remediation plan.
- [ ] Confirm verification results are recorded.

## Secret handling

For each deployment path:

- [ ] Confirm deployment credentials use least privilege.
- [ ] Confirm credentials are stored in the approved secret manager.
- [ ] Confirm credentials are not committed to the Git repository.
- [ ] Confirm credentials are not present in Nix store paths, build outputs, logs, or workflow output.
- [ ] Confirm deployment commands do not echo secrets or sensitive connection strings.
- [ ] Confirm secret rotation or replacement plans exist.
- [ ] Confirm exposed or compromised credentials are revoked and replaced promptly.
- [ ] Confirm credential access is limited to approved operators and workflows.

## Change records

For each production change:

- [ ] Confirm the change has a documented purpose and scope.
- [ ] Confirm the change identifies affected services and hosts.
- [ ] Confirm the change identifies risks, rollback steps, and verification checks.
- [ ] Confirm the change is reviewed and approved.
- [ ] Confirm the change is traceable to a commit SHA or deployment record.
- [ ] Confirm the change outcome and verification result are recorded.
- [ ] Confirm failed changes have an owner and remediation plan.
- [ ] Confirm change records do not contain secrets or sensitive deployment data.

## Findings and remediation

Classify each finding as:

- **Critical:** Production can be deployed from an unapproved, untraceable, or unsafe revision; deployment credentials are exposed; or rollback is unavailable during a material recovery scenario.
- **High:** Authorization, traceability, CI, rollback, or verification controls create a material deployment or recovery risk.
- **Medium:** A control is incomplete, undocumented, or inconsistently applied.
- **Low:** Documentation, hygiene, or reporting improvement is needed.

For every finding:

- [ ] Record the affected deployment path, target, workflow, commit, or control.
- [ ] Record the severity and potential impact.
- [ ] Assign an owner and remediation deadline.
- [ ] Record the remediation plan and verification method.
- [ ] Confirm critical findings are treated as operational or security incidents.
- [ ] Confirm remediation is verified before the finding is closed.

## Pass criteria

The audit passes only when:

- Every production deployment path is authorized and documented.
- Deployments use a clean working tree and an explicit full commit SHA.
- Required CI checks pass before deployment.
- Deployment credentials use least privilege and remain protected.
- Rollback procedures are documented and tested where feasible.
- Post-deployment verification confirms service health and intended behavior.
- No critical or high finding remains unowned or unremediated.
- Results, findings, and follow-up actions are recorded.

## Related documentation

- `docs/runbooks/service-recovery-matrix.md`
- `docs/runbooks/incident-severity.md`
- `docs/runbooks/incident-evidence.md`
- `docs/audits/access-control-secrets.md`
- `docs/audits/host-hardening-patching.md`
- `docs/audits/network-exposure-firewall.md`
- `docs/audits/monitoring-alerting.md`
- `docs/audits/backup-integrity.md`
- `docs/RECOVERY.md`
- `docs/audits/incident-response-recovery.md`
