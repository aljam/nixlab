# PostgreSQL restore drill

Use this drill to validate that a recent PostgreSQL backup can be restored into a clean, isolated PostgreSQL environment and used by an application-equivalent client.

This drill must not restore into the production PostgreSQL instance. Use a disposable VM, container, or separate PostgreSQL data directory.

## Objective

For every database declared for PostgreSQL backup, verify that:

- A recent Restic recovery point contains a valid custom-format dump.
- The dump restores into a clean PostgreSQL instance.
- Expected databases, schemas, tables, roles, and data are present.
- An application-equivalent connection can authenticate and run a representative query.
- The recovery point is fresh enough to meet the recovery objective.

The production PostgreSQL backup job creates one custom-format dump per declared database under `/var/lib/restic-backup/postgresql` and includes that directory in the Restic repository.

## Safety rules

- Never run `pg_restore` against the production PostgreSQL instance.
- Run the drill in an isolated environment with no access to production credentials or production network services.
- Bind the drill PostgreSQL instance to loopback or an isolated test network only.
- Use a temporary database password and remove it after the drill.
- Do not expose the drill database through the LAN, HAProxy, or a public endpoint.
- Do not paste database passwords, connection strings, or dump contents into incident records.
- Record the Restic snapshot ID, dump filename, database name, restore duration, and verification results.

## Before the drill

- [ ] Identify the target database and its expected application owner.
- [ ] Identify the latest successful Restic snapshot and its timestamp.
- [ ] Confirm the snapshot is within the accepted recovery-point objective.
- [ ] Confirm sufficient temporary disk space for the dump, restored cluster, and WAL.
- [ ] Confirm the drill PostgreSQL version is compatible with the production dump.
- [ ] Confirm the drill environment cannot reach production PostgreSQL or production credentials.
- [ ] Confirm the drill PostgreSQL instance listens only on loopback or an isolated test network.
- [ ] Confirm a cleanup plan exists for the temporary environment.

## Restore the backup

- [ ] Restore the selected Restic snapshot to an isolated staging directory.
- [ ] Locate the expected `<database>.dump` file for each declared database.
- [ ] Verify each archive is readable:

  ```console
  pg_restore --list /path/to/<database>.dump
  ```

- [ ] Create a clean temporary PostgreSQL cluster or container.
- [ ] Create the target drill database and an application role with a temporary password.
- [ ] Restore each dump into its own drill database:

  ```console
  pg_restore \
    --dbname=<drill-database> \
    --no-owner \
    --no-privileges \
    /path/to/<database>.dump
  ```

- [ ] Capture restore warnings, errors, and duration.
- [ ] Repeat for every database included in the selected snapshot.

## Verify the restore

- [ ] Confirm each expected database exists.
- [ ] Confirm expected schemas and tables are present.
- [ ] Confirm expected roles own or can access the expected objects.
- [ ] Confirm row counts are plausible for the recovery point; compare against production only when safe.
- [ ] Run a representative application query or integration check.
- [ ] Confirm the application role can authenticate with its temporary drill credential.
- [ ] Confirm unrelated databases and roles were not restored unintentionally.
- [ ] Confirm no production data was overwritten or exposed.
- [ ] Confirm monitoring and alerts remain healthy after the drill.

If the drill is intended to validate the production client path, connect with TLS and verify the certificate chain. Otherwise, record that TLS was not exercised in this drill.

## Pass criteria

The drill passes only when:

- Every declared database restores without a fatal error.
- Expected schemas, tables, and ownership are present.
- A representative application query succeeds.
- The recovery point is within the accepted freshness threshold.
- The drill environment is removed or securely retained as incident evidence.
- Results are recorded with the Restic snapshot ID and database-level outcomes.

## If the drill fails

- Preserve the Restic snapshot ID, dump filename, `pg_restore` output, PostgreSQL logs, and verification results.
- Do not delete the dump or repository snapshot until the cause is understood.
- Determine whether the failure is in backup creation, repository integrity, restore compatibility, role or ownership handling, or application validation.
- Treat a failure that prevents a usable recovery point as a recoverability incident.
- Follow `docs/runbooks/incident-severity.md` to assign severity and preserve evidence.

## Record the drill

Record:

- Drill date and operator.
- Restic snapshot ID and snapshot time.
- Database name and dump filename.
- Restore duration and result.
- Verification results.
- Cleanup completion time.
- Follow-up actions, if any.

Do not record database passwords, connection strings, or the contents of a dump.

## Related documentation

- `docs/runbooks/service-recovery-matrix.md`
- `docs/runbooks/incident-severity.md`
- `docs/runbooks/incident-evidence.md`
- `docs/RECOVERY.md`
- `docs/BACKUPS.md`
- `docs/audits/incident-response-recovery.md`
