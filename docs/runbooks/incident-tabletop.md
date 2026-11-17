# Incident-response tabletop exercise

Use this tabletop exercise to practice detecting, escalating, containing, recovering from, and reviewing a material service incident without modifying production systems.

This exercise uses a PostgreSQL corruption and Restic recovery scenario. It is discussion-based: participants identify decisions, owners, evidence, communication, and recovery steps; they do not execute production recovery actions.

## Exercise objective

By the end of the exercise, participants should be able to:

- Detect and classify a material service incident.
- Assign an incident commander and accountable owners.
- Preserve evidence without exposing secrets or sensitive data.
- Select an appropriate recovery point and recovery procedure.
- Identify dependencies, risks, and decision points.
- Communicate status to operators and affected users where appropriate.
- Identify gaps in runbooks, monitoring, access, backups, and recovery procedures.
- Record follow-up actions and assign owners.

## Exercise scope

This exercise covers:

- PostgreSQL database corruption or failed recovery.
- Restic repository access and snapshot selection.
- Isolated PostgreSQL restore and validation.
- Service recovery sequencing.
- Incident severity, escalation, and communication.
- Evidence preservation and post-incident review.

This exercise does not require restoring production data or executing production recovery commands.

## Participants

| Role | Responsibility |
|---|---|
| Incident commander | Owns incident coordination, decisions, escalation, and status communication |
| Service owner | Provides service context, impact assessment, and recovery requirements |
| Database operator | Evaluates database state, recovery point, and restore procedure |
| Backup operator | Validates repository access, snapshot selection, and recovery-point freshness |
| Security owner | Preserves evidence, reviews credential exposure, and coordinates security actions |
| Communications owner | Prepares operator and user-facing status updates where appropriate |
| Observer | Records decisions, gaps, timelines, and follow-up actions |

A participant may hold multiple roles in a small team, but every role must have a named owner.

## Scenario

At 09:15, monitoring reports that a production PostgreSQL-backed service is returning errors. The service health check is failing, and the database operator observes signs of database corruption.

The incident commander must coordinate the response without allowing recovery actions to affect production. The team must determine whether the latest Restic recovery point is usable, identify the recovery procedure, and decide when the service can be restored.

## Inject 1: Detection and severity

**Inject:** Monitoring reports repeated PostgreSQL errors and service health-check failures.

Discuss and record:

- What evidence confirms this is an incident rather than a transient failure?
- What is the initial severity?
- Who is the incident commander?
- Which service owners and operators must be engaged?
- What production actions must be avoided?
- What evidence should be preserved immediately?
- What status should be recorded in the incident channel?

Expected outcome:

- The incident is classified using `docs/runbooks/incident-severity.md`.
- The incident commander and owners are named.
- Evidence preservation begins before recovery actions.
- Production recovery actions are explicitly deferred until the recovery plan is approved.

## Inject 2: Evidence preservation

**Inject:** The database operator reports possible corruption and suspects that recent changes or a failed backup may be relevant.

Discuss and record:

- Which logs, alerts, database errors, deployment records, and monitoring data must be preserved?
- Which credentials, tokens, private keys, or sensitive data must not be copied into incident records?
- Who owns evidence collection?
- Where is evidence stored?
- What access restrictions apply to the evidence?
- What information must be recorded without exposing secrets?

Expected outcome:

- Evidence sources are identified and preserved.
- Secrets and sensitive data are explicitly excluded from incident records.
- Evidence ownership and storage location are recorded.
- The team follows `docs/runbooks/incident-evidence.md`.

## Inject 3: Recovery-point selection

**Inject:** The backup operator identifies the latest Restic snapshot, but its age is near the recovery-point objective.

Discuss and record:

- Which snapshot is the best candidate for recovery?
- How is snapshot freshness evaluated?
- What repository-integrity checks are appropriate before restore?
- What risks exist if the snapshot is stale or incomplete?
- What is the recovery-point objective for the affected service?
- What decision is required if no snapshot meets the objective?

Expected outcome:

- The team selects a candidate recovery point and records its snapshot ID and timestamp.
- The team identifies the required Restic integrity check and restore procedure.
- The team identifies escalation and communication needs if the recovery point is stale.
- The team follows `docs/runbooks/restic-restore-drill.md`.

## Inject 4: Isolated recovery

**Inject:** The team decides to restore the selected snapshot into an isolated PostgreSQL environment.

Discuss and record:

- Which production systems must be isolated from the recovery environment?
- Which credentials and network access must be prevented?
- Which PostgreSQL restore steps are required?
- Which service-specific validation checks must pass before promotion?
- Which dependencies must be restored or verified?
- What rollback or cleanup plan is required?

Expected outcome:

- The team identifies an isolated recovery environment.
- The team prevents accidental production writes or credential access.
- The team identifies PostgreSQL restore, validation, and cleanup steps.
- The team follows `docs/runbooks/postgresql-restore-drill.md`.

## Inject 5: Service recovery

**Inject:** The restored database is available in isolation, but the affected service has not yet been restored.

Discuss and record:

- Which services must be restored first?
- Which dependencies must be verified before service recovery?
- Which health checks and functional checks are required?
- What monitoring must remain healthy after recovery?
- What criteria determine whether the recovered environment can be promoted?
- What risks remain after promotion?

Expected outcome:

- The team defines a recovery sequence and dependency checks.
- The team identifies health, functional, and monitoring validation requirements.
- The team defines promotion criteria and residual-risk handling.
- The team follows `docs/runbooks/service-recovery-matrix.md`.

## Inject 6: Communication

**Inject:** The incident commander must provide a status update after 45 minutes.

Discuss and record:

- What is known at this point?
- What is uncertain?
- What actions are underway?
- Who is affected?
- What is the next update time?
- What information must not be included in the update?

Expected outcome:

- The team produces a concise status update.
- The update distinguishes confirmed facts from assumptions.
- The update avoids secrets, credentials, internal topology, and unverified claims.
- The team assigns a communications owner and next update time.

## Inject 7: Post-incident review

**Inject:** The service is restored, but the team identifies that the latest backup was older than expected and that an alert did not reach the on-call owner.

Discuss and record:

- What worked well?
- What failed or created delay?
- Which monitoring, alert-routing, backup, access, or runbook gaps were identified?
- Which follow-up actions are required?
- Who owns each action?
- When will each action be completed?
- How will completion be verified?

Expected outcome:

- The team records strengths, gaps, and follow-up actions.
- Each action has an owner and deadline.
- Critical recovery gaps are linked to the incident-response and recovery audit.
- The team follows `docs/audits/incident-response-recovery.md`.

## Exercise record

Record:

- Exercise date and participants.
- Scenario and injects completed.
- Incident severity and commander.
- Recovery point selected.
- Recovery sequence and validation criteria.
- Communication decisions.
- Evidence-preservation decisions.
- Gaps and follow-up actions.
- Owners and deadlines.

Do not record database passwords, connection strings, Restic repository credentials, private keys, tokens, or the contents of sensitive files.

## Pass criteria

The exercise passes when:

- The incident is classified and an incident commander is named.
- Evidence preservation begins before recovery actions.
- A recovery point and recovery procedure are identified.
- Isolated recovery and service-validation steps are defined.
- Communication responsibilities and update timing are assigned.
- Gaps and follow-up actions are recorded with owners and deadlines.
- No production system is modified during the exercise.

## Related documentation

- `docs/runbooks/service-recovery-matrix.md`
- `docs/runbooks/incident-severity.md`
- `docs/runbooks/incident-evidence.md`
- `docs/runbooks/restic-restore-drill.md`
- `docs/runbooks/postgresql-restore-drill.md`
- `docs/runbooks/host-compromise-recovery.md`
- `docs/audits/incident-response-recovery.md`
- `docs/RECOVERY.md`
- `docs/BACKUPS.md`
