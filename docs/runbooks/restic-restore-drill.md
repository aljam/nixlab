# Restic restore drill

Use this drill to validate that a Restic recovery point can be selected, restored into an isolated environment, and used to recover representative service data.

This drill must not restore into the production filesystem, production database, or production service state. Use a disposable VM, container, separate mount point, or staging directory.

## Objective

For each selected recovery point, verify that:

- The Restic repository is accessible with the expected credentials.
- The selected snapshot is fresh enough to meet the recovery-point objective.
- The repository metadata and selected snapshot can be listed successfully.
- The required paths can be restored without fatal errors.
- Restored files are readable and have plausible sizes and timestamps.
- A representative service-specific restore procedure succeeds.
- The recovery environment is cleaned up or securely retained as incident evidence.

## Safety rules

- Never restore directly into the production filesystem or production service state.
- Run the drill in an isolated environment with no access to production credentials or production network services.
- Use a temporary restore directory with sufficient disk space.
- Do not expose the Restic repository password, repository ID, access keys, or connection strings in incident records or command output.
- Do not paste backup contents, file listings containing sensitive paths, or credentials into incident records.
- Record the repository type, snapshot ID, snapshot time, selected paths, restore duration, and verification results.
- Use the least-privileged credentials that can read the required repository data.

## Before the drill

- [ ] Identify the service or data set to validate.
- [ ] Identify the expected Restic repository and backup paths.
- [ ] Identify the latest successful snapshot and its timestamp.
- [ ] Confirm the snapshot is within the accepted recovery-point objective.
- [ ] Confirm sufficient temporary disk space for the restored data.
- [ ] Confirm the drill environment cannot reach production services or production credentials.
- [ ] Confirm the drill environment cannot write to production storage.
- [ ] Confirm the Restic repository credentials are available through the approved secret manager.
- [ ] Confirm a cleanup plan exists for the temporary environment.
- [ ] Confirm monitoring and alerting remain healthy during the drill.

## Select the recovery point

- [ ] List available snapshots without exposing credentials:

  ```console
  restic snapshots
  ```

- [ ] Select the latest successful snapshot that meets the recovery-point objective.
- [ ] Record the snapshot ID, snapshot time, host, tags, and paths included in the snapshot.
- [ ] Confirm the snapshot includes the required service data.
- [ ] Confirm the snapshot is not incomplete or marked as failed.
- [ ] Confirm the repository is reachable and readable.

## Verify repository integrity

- [ ] Run a repository integrity check appropriate for the drill scope:

  ```console
  restic check
  ```

- [ ] Use `--read-data` only when the drill explicitly requires full data verification and the repository and environment can support it.
- [ ] Capture warnings, errors, and duration.
- [ ] Treat repository corruption, missing packs, or integrity failures as a recoverability incident.
- [ ] Do not delete or rewrite repository data until the cause is understood.
- [ ] Record the integrity-check result and snapshot ID.

## Restore the recovery point

- [ ] Create a clean, isolated restore directory.
- [ ] Restore the required paths from the selected snapshot:

  ```console
  restic restore <snapshot-id> \
    --target /path/to/staging \
    --include <required-path>
  ```

- [ ] Restore only the paths required for the drill; avoid restoring unrelated sensitive data.
- [ ] Capture restore warnings, errors, and duration.
- [ ] Confirm restored files exist at the expected paths.
- [ ] Confirm restored file sizes are plausible.
- [ ] Confirm restored timestamps are plausible for the selected recovery point.
- [ ] Confirm restored files are readable by the drill service account.
- [ ] Confirm no production files were overwritten.

## Validate the restore

- [ ] Open or inspect a representative restored file.
- [ ] Confirm file content is readable and not truncated.
- [ ] Confirm expected directories, files, or database artifacts are present.
- [ ] Confirm file ownership and permissions are appropriate for the drill environment.
- [ ] Run the applicable service-specific restore procedure.
- [ ] Confirm the service starts or the data can be consumed by its expected consumer.
- [ ] Confirm the restored data is usable for the recovery scenario being tested.
- [ ] Confirm no production data was exposed or overwritten.
- [ ] Record the validation method and result.

## Service-specific validation

Use the applicable recovery matrix or restore drill for the service being tested.

- [ ] PostgreSQL: follow `docs/runbooks/postgresql-restore-drill.md`.
- [ ] Matrix: follow `docs/runbooks/matrix-recovery-matrix.md`.
- [ ] Other services: follow the service-specific recovery matrix or restore procedure.
- [ ] If no service-specific procedure exists, validate at least one representative file or artifact and record the limitation.

## Pass criteria

The drill passes only when:

- The Restic repository is accessible.
- The selected snapshot is within the accepted recovery-point objective.
- The required repository integrity check succeeds.
- The required paths restore without a fatal error.
- Restored files are readable and plausible for the selected recovery point.
- The applicable service-specific validation succeeds.
- The drill environment is removed or securely retained as incident evidence.
- Results are recorded with the snapshot ID and service-level outcomes.

## If the drill fails

- Preserve the snapshot ID, repository configuration reference, `restic` command output, restore logs, and validation results.
- Do not delete the snapshot, repository data, or restored files until the cause is understood.
- Determine whether the failure is in repository access, repository integrity, snapshot selection, restore compatibility, service-specific restore, or validation.
- Treat a failure that prevents a usable recovery point as a recoverability incident.
- Follow `docs/runbooks/incident-severity.md` to assign severity and preserve evidence.
- Follow `docs/runbooks/incident-evidence.md` for evidence handling.

## Record the drill

Record:

- Drill date and operator.
- Restic repository type and repository reference without credentials.
- Snapshot ID and snapshot time.
- Selected paths and restore target.
- Restore duration and result.
- Integrity-check result.
- Service-specific validation result.
- Cleanup completion time.
- Follow-up actions, if any.

Do not record repository passwords, access keys, connection strings, or the contents of restored sensitive files.

## Related documentation

- `docs/runbooks/service-recovery-matrix.md`
- `docs/runbooks/postgresql-restore-drill.md`
- `docs/runbooks/matrix-recovery-matrix.md`
- `docs/runbooks/incident-severity.md`
- `docs/runbooks/incident-evidence.md`
- `docs/RECOVERY.md`
- `docs/BACKUPS.md`
- `docs/audits/incident-response-recovery.md`
