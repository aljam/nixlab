# Critical service test matrix

## Goal

Protect the highest-impact networking, database, monitoring, and media-service invariants with repeatable NixOS VM tests.

## Priority tests

| Area | Test | Expected result |
|---|---|---|
| PostgreSQL | Start PostgreSQL and connect locally | Service is active; local authenticated connections succeed |
| PostgreSQL | Verify database and role isolation | Each backend can access only its own database |
| PostgreSQL | Verify network exposure | PostgreSQL accepts connections only from intended addresses |
| HAProxy | Verify backend reachability | Backend ports are reachable from the configured proxy address |
| HAProxy | Verify isolation | Backend ports are not reachable from unrelated LAN clients |
| Prometheus | Verify exporter access | Prometheus can reach enabled exporters |
| Prometheus | Verify isolation | Other LAN clients cannot reach exporters unless explicitly allowed |
| Systemd | Boot a minimal server host | Critical service units are active after VM boot |
| Servarr | Verify shared media access | Servarr services can create and read files under the shared media group |
| Drift monitoring | Introduce controlled drift | The checker detects the drift and reports it |

## Implementation order

1. Add a minimal server-host VM test that boots and checks critical units.
2. Add PostgreSQL database, role, and network-exposure assertions.
3. Add HAProxy backend reachability and isolation assertions.
4. Add Prometheus exporter access assertions.
5. Add Servarr shared-media permission assertions.
6. Add drift-monitoring detection coverage after the checker exists.

## Acceptance criteria

- Every critical invariant has an automated test or an explicit documented exception.
- Tests fail when a service becomes unexpectedly exposed or inaccessible.
- Tests run through `nix flake check --no-build --print-build-logs`.
- Test failures identify the affected service and invariant.
