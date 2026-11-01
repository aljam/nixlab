# Public service authentication inventory

This document tracks the authentication and administrative-exposure posture of
every service reachable through the public HAProxy gateway.

Review this inventory whenever a service is added, its authentication model
changes, or a new administrative interface becomes reachable.

## Review fields

For every public hostname, record:

- Authentication method.
- Whether the administrative interface is publicly reachable.
- Whether self-registration or open account creation is enabled.
- Whether multi-factor authentication is available and enabled for
  administrators.
- Whether API keys or tokens are exposed through the UI, logs, or dashboard.
- The date of the most recent review.

## Inventory

| Hostname | Service | Backend port | Authentication | Admin exposure | Signup | MFA | API-key exposure | Last reviewed |
|---|---|---:|---|---|---|---|---|---|
| `grafana.derezzed.info` | Grafana | 3000 | Local account | Dedicated administrator account | Disabled | Requires external IdP | None | 2026-11-01 |
| `vault.derezzed.info` | Vaultwarden | 8222 | Local accounts | Admin token required | Disabled | Authenticator app | None | 2026-11-01 |
| `jellyfin.derezzed.info` | Jellyfin | 8096 | Local accounts | Dedicated administrator account | Disabled | Not supported | Five expected integration keys | 2026-11-01 |
| `seerr.derezzed.info` | Jellyseerr/Overseerr | 5055 | Local accounts | Dedicated administrator account | Admin-controlled | Not supported | None | 2026-11-01 |
| `audiobookshelf.derezzed.info` | Audiobookshelf | 13378 | Local accounts | Review | Review | Review | Review | Pending |
| `radarr.derezzed.info` | Radarr | 7878 | Application authentication | Public, authenticated | N/A | Not supported | Protected | 2026-11-01 |
| `sonarr.derezzed.info` | Sonarr | 8989 | Application authentication | Public, authenticated | N/A | Not supported | Protected | 2026-11-01 |
| `lidarr.derezzed.info` | Lidarr | 8686 | Application authentication | Public, authenticated | N/A | Not supported | Protected | 2026-11-01 |
| `bazarr.derezzed.info` | Bazarr | 6767 | Application authentication | Public, authenticated | N/A | Not supported | Protected | 2026-11-01 |
| `prowlarr.derezzed.info` | Prowlarr | 9696 | Application authentication | Public, authenticated | N/A | Not supported | Protected | 2026-11-01 |
| `shoko.derezzed.info` | Shoko | 8111 | Review | Review | Review | Review | Review | Pending |
| `qb.derezzed.info` | qBittorrent | 8080 | qBittorrent WebUI username/password | Public, authenticated | N/A | Not supported | None | 2026-11-01 |
| `home.derezzed.info` | Homepage | 8082 | None; public dashboard | No admin UI | N/A | N/A | None | Pending |
| `derezzed.info` / `www.derezzed.info` | Static landing page | 8083 | None | None | N/A | N/A | None | Pending |

## LAN-only services

| Service | Backend port | Exposure | Last reviewed |
|---|---:|---|---|
| Shoko | 8111 | LAN-only; not routed through HAProxy or advertised publicly | 2026-11-01 |

Shoko remains enabled for local media integrations, but it is not added to
`networking.proxyBackendPorts`, HAProxy, or the public Homepage dashboard.
Use VPN access when remote administration is required.

## Priority review order

1. **Audiobookshelf** — Confirm separate administrator and user accounts, and
   review API tokens.

## Completed reviews

### Lidarr, Bazarr, and Prowlarr — 2026-11-01

- All three services use application authentication and require login before
  library, indexer, and settings data are accessible.
- Default credentials are not in use.
- API keys are protected and were not exposed through the public interfaces,
  logs, or dashboards.
- Connected integrations were reviewed; no unused integrations or unintended
  users were identified.
- Lidarr, Bazarr, and Prowlarr do not provide native multi-factor
  authentication.

### Radarr and Sonarr — 2026-11-01

- Both services use application authentication and require login before
  library, queue, and settings data are accessible.
- Default credentials are not in use.
- API keys are protected and were not exposed through the public interfaces,
  logs, or dashboards.
- Connected integrations were reviewed; no unused integrations or unintended
  users were identified.
- Radarr and Sonarr do not provide native multi-factor authentication.

### Vaultwarden — 2026-11-01

- Authentication uses local Vaultwarden accounts.
- The administrative panel resolves at `/admin` and requires the configured
  admin token.
- The admin token is strong and has not been exposed.
- Open signup is disabled.
- Multi-factor authentication is enabled for the user account using an
  authenticator application.
- No unintended organization, attachment, or Send shares were identified.
- The Vaultwarden master password remains unique and must be retained securely;
  Vaultwarden cannot recover it.

### Grafana — 2026-11-01

- Authentication uses a local Grafana administrator account.
- The default Grafana administrator credentials are not in use; the
  administrator account uses a unique password.
- Self-registration is disabled.
- Anonymous access is disabled.
- No unused users, service accounts, service-account tokens, or legacy API
  keys were identified.
- No dashboards are publicly accessible without authentication.
- Grafana OSS does not provide built-in MFA; enabling MFA would require an
  external identity provider.

### Seerr — 2026-11-01

- Authentication uses local Seerr accounts.
- Account creation is controlled by an administrator rather than open to the
  public.
- Administrative access is limited to a dedicated administrator account.
- Seerr does not provide native multi-factor authentication.
- No API keys or tokens were exposed through the public interface.
- Connected media integrations were reviewed and no unused integrations were
  identified.

### Jellyfin — 2026-11-01

- Authentication uses local Jellyfin accounts.
- Open registration is disabled.
- Administrative access is limited to a dedicated administrator account.
- Jellyfin does not provide native multi-factor authentication.
- API keys exist only for expected integrations: Bazarr, Seerr, Lidarr,
  Radarr, and Sonarr.
- No unknown or unused API keys were identified.
- API keys must not be shared in logs, tickets, screenshots, or repository
  files.

### qBittorrent — 2026-11-01

- WebUI authentication is enabled and working through the public HAProxy route.
- Administrative access requires the configured qBittorrent WebUI credentials.
- Authentication bypass rules are not used for HAProxy-forwarded requests.
- CSRF protection and Host header validation are enabled.
- The default `admin` / `adminadmin` credentials are not in use.
- No API key is exposed through the public WebUI.

### Shoko — 2026-11-01

- Removed from the public HAProxy backend allowlist and Homepage dashboard.
- Remains enabled for LAN-only media integrations.
- Remote administration requires VPN access.

## Required controls

- Administrative interfaces must require authentication appropriate to their
  sensitivity.
- Self-registration must be disabled unless explicitly documented as intended.
- API keys and tokens must be treated as secrets and must not appear in public
  dashboards, repository files, screenshots, or logs.
- Shared administrator credentials must not be used.
- MFA must be enabled where the application supports it, especially for
  Vaultwarden administrators.
- Services that do not require public access must be removed from
  `networking.proxyBackendPorts`, HAProxy, and the public Homepage dashboard.

## Review process

1. Test each public hostname over HTTPS.
2. Confirm the expected authentication prompt or login flow.
3. Attempt to access administrative functionality without authentication.
4. Review user, API-key, token, and registration settings in the application.
5. Update the inventory table and set the review date.
6. Remove any service from public exposure if it does not require internet
   access.
