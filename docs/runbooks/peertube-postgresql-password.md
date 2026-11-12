# PeerTube PostgreSQL password lifecycle

## Context

The `peertube` PostgreSQL role on `r820` is used by PeerTube running on `r730xd`. Its password is intentionally managed out of band because `secrets/peertube.yaml` is not encrypted for `r820`.

The role and database are created declaratively by `modules/features/postgres.nix`, but the password must be set manually after the role exists.

## Initial setup

Run the following on `r820` as an administrator with local PostgreSQL access:

```sh
sudo -u postgres psql
```

Then set a strong, unique password:

```sql
ALTER ROLE peertube PASSWORD 'REPLACE_WITH_GENERATED_PASSWORD';
```

Store the generated password in the appropriate PeerTube secret store on `r730xd`. Do not commit it to Git.

## Rotation

1. Generate a new strong password.
2. Update the PeerTube secret consumed by the PeerTube service on `r730xd`.
3. Run:

   ```sql
   ALTER ROLE peertube PASSWORD 'REPLACE_WITH_NEW_PASSWORD';
   ```

4. Restart or reload the PeerTube service only if it caches database credentials in a way that prevents it from using the new password.
5. Verify that PeerTube can connect to `r820` and that the PostgreSQL logs contain no repeated authentication failures.

## Recovery

If the PeerTube role password is lost:

1. Connect to PostgreSQL locally on `r820` as the `postgres` operating-system user.
2. Set a new password with `ALTER ROLE peertube PASSWORD '…'`.
3. Update the PeerTube secret on `r730xd` to match.
4. Restart PeerTube if required.
5. Verify application functionality and monitor for authentication failures.

## Current limitation

The password is not currently represented as a SOPS secret for `r820`. This means password rotation requires coordinated manual action on both `r820` and `r730xd`.

A future improvement should move the password into SOPS with `r820` as a recipient and provide a declarative mechanism for applying it to the PostgreSQL role.
