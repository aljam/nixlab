# Matrix recovery matrix

Use this matrix to decide what must be restored, verified, and rehearsed after a Matrix homeserver incident. It covers the Synapse database, local media, server identity, federation, RTC, and administrative access.

A Matrix homeserver recovery is not complete when the service starts. It is complete when users can authenticate, access expected room history, upload or retrieve media where applicable, and the server can participate in federation without impersonating or corrupting another homeserver.

## Recovery scope

| Recovery area | Primary artifacts | Failure impact | Restore priority |
|---|---|---|---|
| Database | PostgreSQL database, WAL/archive backups | Accounts, rooms, membership, event history, device/session data, and much of Matrix state are unavailable | P0 |
| Server identity | Synapse signing key, homeserver configuration | Federation identity and event signing may be broken; recovery becomes substantially harder | P0 |
| Local media | Media store, especially `local_content` | Locally uploaded files may be permanently unavailable; some may exist nowhere else in the federation | P0 |
| Reverse proxy and TLS | Reverse-proxy configuration, certificates, DNS/delegation records | Clients and federating servers cannot reach the homeserver reliably | P0 |
| Federation | Delegation records, server name resolution, firewall rules, federation configuration | Local chat may work while cross-server rooms and invites fail | P1 |
| RTC | TURN/STUN configuration, credentials, firewall rules, Coturn or equivalent | Calls may fail even when messaging is healthy | P1 |
| Administrator access | Admin accounts, recovery access, SSO/IdP configuration | Operators may be unable to manage users, rooms, media, or the incident | P1 |
| Bridges and integrations | Bridge state, credentials, application-service registrations | Bridged rooms, notifications, or external-service integrations may fail | P2 |

## Before an incident

- [ ] Maintain an encrypted, off-site backup of the Synapse PostgreSQL database.
- [ ] Maintain an encrypted, off-site backup of the Synapse configuration directory.
- [ ] Maintain an encrypted, off-site backup of the Synapse server signing key.
- [ ] Back up the local media store, especially `local_content`.
- [ ] Back up application-service registrations and bridge configuration where applicable.
- [ ] Document the server name, `server_name`, database name, media-store path, signing-key path, and reverse-proxy configuration.
- [ ] Document the PostgreSQL connection details without storing plaintext credentials in the runbook.
- [ ] Confirm that database, configuration, signing-key, and media backups are included in the Restic repository or another tested off-site backup system.
- [ ] Confirm that the backup retention period meets the recovery-point objective.
- [ ] Confirm that monitoring detects Synapse process failure, PostgreSQL failure, certificate expiry, disk exhaustion, and federation errors.
- [ ] Confirm that the recovery environment can be isolated from production and cannot accidentally federate as the production server name.

## Database recovery

The PostgreSQL database is the primary durable state store for Synapse: user accounts, rooms, room state, event history, device information, and related operational state. A database-only restore is therefore the core Matrix recovery path.

- [ ] Stop Synapse and prevent it from reconnecting to the target database.
- [ ] Identify the latest usable database recovery point and its timestamp.
- [ ] Confirm the recovery point is within the accepted recovery-point objective.
- [ ] Restore the PostgreSQL database into a clean database instance or a clean, empty database.
- [ ] Do not restore into a database that already contains Synapse tables; partial or overlapping restores can create inconsistency.
- [ ] Restore WAL archives or incremental backups if point-in-time recovery is required.
- [ ] Start Synapse against the restored database in an isolated recovery environment first.
- [ ] Confirm Synapse starts without fatal database-migration or schema errors.
- [ ] Confirm pending database migrations and background updates complete successfully.
- [ ] Confirm that an existing user can authenticate.
- [ ] Confirm that the user can access expected rooms and recent message history.
- [ ] Confirm that room membership, room state, and local user accounts are present.
- [ ] Confirm that device/session data is present where expected.
- [ ] Record the recovery point, restore duration, database size, and verification results.

## Server identity

The Synapse signing key is part of the homeserver’s long-term cryptographic identity. It signs federation traffic and events; losing it makes recovery materially harder, and it should not be casually regenerated.

- [ ] Locate the configured `signing_key_path`.
- [ ] Confirm the signing key is present in the recovery backup.
- [ ] Restore the signing key to the same path expected by Synapse configuration.
- [ ] Confirm file ownership and permissions are correct.
- [ ] Confirm the restored `server_name` matches the original production server name.
- [ ] Do not change `server_name` during a recovery unless the incident explicitly requires abandoning the old identity.
- [ ] Confirm that the signing key was not regenerated as part of routine recovery.
- [ ] Confirm that federation traffic is signed with the restored key.
- [ ] Record the signing-key backup location and recovery verification result without exposing key material.

## Media recovery

Local uploaded media may be the only copy of a file anywhere in the federation. Treat the media store as a first-class recovery artifact, not as disposable cache data.

- [ ] Identify the media-store path from Synapse configuration.
- [ ] Confirm that the selected backup includes the media store.
- [ ] Restore the media store to the expected path.
- [ ] Restore the database before or in a manner consistent with the media snapshot; avoid restoring a database that references media absent from the restored store.
- [ ] Confirm that local media URLs resolve successfully.
- [ ] Confirm that a representative locally uploaded file can be downloaded.
- [ ] Confirm that remote media caching behaves according to the configured retention policy.
- [ ] Confirm that media-store disk capacity is sufficient after restoration.
- [ ] Confirm that no media from another environment was accidentally exposed through the production server.
- [ ] Record the media-store snapshot, restored path, and verification result.

## Federation recovery

A homeserver can appear healthy to local users while federation is broken because of DNS, delegation, certificates, reverse-proxy routing, firewall rules, or federation configuration. Federation must therefore be tested explicitly.

- [ ] Confirm the public server name resolves correctly.
- [ ] Confirm `.well-known/matrix/server` delegation returns the expected homeserver target, if delegation is used.
- [ ] Confirm the federation API endpoint responds successfully.
- [ ] Confirm the TLS certificate is valid, not expired, and matches the expected hostname.
- [ ] Confirm the reverse proxy forwards Matrix client and federation traffic correctly.
- [ ] Confirm required federation ports are reachable from the internet or the approved federation network.
- [ ] Confirm the restored signing key is used for federation traffic.
- [ ] Join or message in a known federated room from a test account.
- [ ] Confirm that a remote user can see the local user’s presence or messages where privacy settings permit.
- [ ] Confirm that invites, joins, and message delivery work in at least one cross-server room.
- [ ] Confirm that the recovery environment does not federate using the production server name unless it is the intended production recovery.
- [ ] Record federation checks, remote homeservers tested, and any delegation or certificate changes.

## RTC recovery

RTC recovery covers voice and video call setup. A messaging-only recovery can be complete while calls remain broken.

- [ ] Identify the TURN/STUN service and its configuration.
- [ ] Confirm the TURN service is running after recovery.
- [ ] Confirm TURN credentials or shared secrets are restored or reissued safely.
- [ ] Confirm required TURN/STUN ports and relay ranges are open.
- [ ] Confirm the TURN public address resolves and is reachable.
- [ ] Confirm Synapse configuration references the correct TURN URIs and credentials.
- [ ] Place a test call between two local accounts.
- [ ] Place a test call involving at least one remote federated account where feasible.
- [ ] Confirm audio connects; test video and screen sharing where applicable.
- [ ] Confirm that call setup succeeds without exposing internal network topology.
- [ ] Record the RTC service, test participants, and result.

## Administrator access

Operators must retain a recovery path that does not depend on a compromised or unavailable normal authentication flow.

- [ ] Confirm at least one local administrator account can authenticate after recovery.
- [ ] Confirm the administrator account has the expected Synapse admin privileges.
- [ ] Confirm SSO/IdP configuration, if used, is restored or can be safely re-established.
- [ ] Confirm that recovery access does not rely solely on an external identity provider.
- [ ] Confirm that admin APIs can list users, rooms, media, and federation state where applicable.
- [ ] Confirm that administrative credentials are stored in the approved secret manager, not in the runbook.
- [ ] Confirm that break-glass access is protected by MFA or an equivalent control.
- [ ] Confirm that the recovery environment does not grant unintended admin access to production.
- [ ] Record the administrator recovery path and verification result.

## Bridges and integrations

Bridges and application services may have their own durable state, credentials, and registration files. Their recovery needs should be assessed separately from Synapse itself.

- [ ] Identify each active bridge, bot, application service, or integration.
- [ ] Confirm whether it maintains its own database or state directory.
- [ ] Confirm whether its credentials and registration files are backed up.
- [ ] Restore bridge state only after the core Synapse database and media recovery are stable.
- [ ] Confirm bridge rooms, memberships, and message delivery where applicable.
- [ ] Confirm that bridge credentials were not exposed during recovery.
- [ ] Confirm that a failed bridge does not block the core Matrix recovery.
- [ ] Record each bridge’s recovery status and required follow-up.

## Recovery sequence

Use this order for a full homeserver recovery:

1. Preserve evidence and establish an isolated recovery environment.
2. Restore the PostgreSQL database.
3. Restore Synapse configuration and the server signing key.
4. Restore the media store.
5. Start Synapse in isolation and complete database checks.
6. Restore and verify reverse-proxy, TLS, DNS, and delegation configuration.
7. Verify local authentication and room-history access.
8. Verify federation with a controlled remote homeserver.
9. Restore and verify RTC.
10. Restore and verify administrator access.
11. Restore and verify bridges and integrations.
12. Promote the recovered environment to production only after all P0 checks pass.
13. Record outcomes, gaps, and follow-up actions.

## Pass criteria

The Matrix recovery is successful when:

- The PostgreSQL database restores to a usable state.
- Synapse starts and completes required migrations or background updates.
- The server signing key and `server_name` are preserved.
- Local users can authenticate and access expected room history.
- Local media is available where the selected recovery point includes it.
- Federation works for at least one controlled cross-server room.
- RTC works for a representative local call, where RTC is in scope.
- Administrator access is available through a protected recovery path.
- Bridges and integrations are either restored or explicitly documented as deferred.
- The recovery point meets the accepted freshness objective.
- Results, gaps, and follow-up actions are recorded.

## If recovery fails

- Preserve the database dump, WAL/archive files, configuration, signing-key backup references, media-store snapshot, and all relevant logs.
- Do not delete backups or repository snapshots until the failure is understood.
- Determine whether the failure is in the database, configuration, signing key, media store, networking, federation, RTC, or administrator access.
- Treat inability to restore a usable homeserver as a recoverability incident.
- Follow `docs/runbooks/incident-severity.md` to assign severity and preserve evidence.
- Follow `docs/runbooks/incident-evidence.md` for evidence handling.

## Restore cautions

- Do not restore Synapse into a database that already contains tables; this can produce errors or subtle inconsistency.
- Exclude or truncate `e2e_one_time_keys_json` after restoring an older backup, because restored one-time keys can be issued twice and break decryption for messages encrypted with them.
- Restore the database before the media store, or ensure consistency between them, so the restored database does not reference media absent from the restored snapshot.
- Use an isolated recovery environment and prevent it from federating as the production server name until recovery is intentional and verified.

## Related documentation

- `docs/runbooks/service-recovery-matrix.md`
- `docs/runbooks/postgresql-restore-drill.md`
- `docs/runbooks/incident-severity.md`
- `docs/runbooks/incident-evidence.md`
- `docs/RECOVERY.md`
- `docs/BACKUPS.md`
- `docs/audits/incident-response-recovery.md`
