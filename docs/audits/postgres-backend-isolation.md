# PostgreSQL and backend isolation audit

## Goal

Ensure that PostgreSQL-backed applications use isolated databases and credentials, while keeping the operational model simple enough to maintain.

## Current model

The repository uses a shared PostgreSQL service with per-application databases and credentials. The intended boundary is:

- One PostgreSQL server per host or service group.
- One database per backend application.
- One dedicated PostgreSQL role per application.
- Application secrets stored through SOPS and supplied through systemd `EnvironmentFile` files.
- No application receives broad PostgreSQL superuser privileges.

## Isolation invariants

For every PostgreSQL-backed backend:

- It has a dedicated database.
- It has a dedicated role with privileges limited to its own database.
- It does not share a database or role with another application.
- Its connection URL is supplied through a secret-managed environment file.
- Its service runs as a non-root system user.
- Its state is persisted through the host persistence policy.

## Audit checklist

For each backend that uses PostgreSQL, verify:

- The database name is application-specific.
- The PostgreSQL role is application-specific.
- The role owns or has the minimum required privileges on its database.
- The connection URL does not use the PostgreSQL administrator account.
- The secret is referenced through SOPS rather than committed in plain text.
- The systemd unit has `LoadCredential` or an `EnvironmentFile` with appropriate permissions.
- The service user cannot read unrelated application secrets.
- Persistence includes the PostgreSQL data directory and application state where required.

## Proposed test coverage

Add a NixOS VM test that verifies:

1. PostgreSQL starts and accepts local connections.
2. Each backend has its own database and role.
3. A backend can connect using its dedicated credentials.
4. One backend cannot access another backend's database.
5. Secrets are available to the intended service but are not broadly readable.
6. Services restart successfully after a PostgreSQL restart.

## Acceptance criteria

- No backend shares a database or PostgreSQL role with another backend.
- No backend uses the PostgreSQL administrator account.
- Secrets remain SOPS-managed and least-privilege.
- The VM test proves cross-database access is denied.
- `nix flake check --no-build --print-build-logs` passes.
