# Tests

## Flake checks

Run by `nix flake check`, on every pull request (job "Evaluate Nix checks" in
`.github/workflows/security.yml`) and by `nix run .#deploy` before it deploys.

| Check | Kind | What it covers |
| --- | --- | --- |
| `nftables-input-rules` | evaluation | Custom nftables input rules of every host; rejects rules that accept traffic without a meaningful match. |
| `service-exposure` | evaluation | Service exposure and security invariants across the composed fleet. |
| `public-service-hardening` | evaluation | Security baseline of the services published through the HAProxy gateway. |
| `public-endpoint-inventory` | evaluation | Consistency of `docs/public-endpoints.json`. |
| `monitoring-health` | VM | Prometheus starts, loads its alert rules and scrapes the exporters; monitoring ports stay unreachable from other hosts. |
| `postgresql-auth` | VM | Password authentication over TCP on a reference PostgreSQL configuration (it does not import `modules/features/postgres.nix`). |

Run one check:

```bash
nix build .#checks.x86_64-linux.nftables-input-rules
```

## VM tests outside `nix flake check`

These are slower and are exposed as flake packages instead. They run nightly
and on demand in `.github/workflows/vm-tests.yml`, which is the only place
that runs them.

| Package | File | What it covers |
| --- | --- | --- |
| `firewall-isolation` | `firewall.nix` | Only the HAProxy gateway reaches a backend port; only the Prometheus host reaches node_exporter. |
| `admin-isolation` | `runtime-isolation.nix` | Administrative services stay unreachable from the LAN even when they listen on all interfaces. |

Run one locally (needs KVM):

```bash
nix build --print-build-logs .#firewall-isolation
```

`runtime-isolation.nix` also contains `postgresql-reachability`, which is not
wired into the flake.

## Removed tests

`default.nix`, `postgresql-remote-tls.nix`, `sops-rotation.nix` and
`runtime-security.nix` were removed because nothing referenced them and the
first three could not run.

The former service-health, service-isolation, backup, and standalone security
assertion tests were removed because they were unused or invalid. Their useful
sudo and SSH checks are now enforced by `modules/features/security-policy.nix`.
