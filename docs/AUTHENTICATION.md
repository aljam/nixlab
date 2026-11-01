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
| `grafana.derezzed.info` | Grafana | 3000 | Local account | Admin UI public | Disabled | Review | Review | Pending |
| `vault.derezzed.info` | Vaultwarden | 8222 | Local accounts | Admin token required | Disabled | Review | Review | Pending |
| `jellyfin.derezzed.info` | Jellyfin | 8096 | Local accounts | Review | Review | Review | Review | Pending |
| `seerr.derezzed.info` | Jellyseerr/Overseerr | 5055 | Local accounts | Review | Review | Review | Review | Pending |
| `audiobookshelf.derezzed.info` | Audiobookshelf | 13378 | Local accounts | Review | Review | Review | Review | Pending |
| `radarr.derezzed.info` | Radarr | 7878 | Application authentication | Review | N/A | N/A | Review | Pending |
| `sonarr.derezzed.info` | Sonarr | 8989 | Application authentication | Review | N/A | N/A | Review | Pending |
| `lidarr.derezzed.info` | Lidarr | 8686 | Application authentication | Review | N/A | N/A | Review | Pending |
| `bazarr.derezzed.info` | Bazarr | 6767 | Application authentication | Review | N/A | N/A | Review | Pending |
| `prowlarr.derezzed.info` | Prowlarr | 9696 | Application authentication | Review | N/A | N/A | Review | Pending |
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

1. **Jellyfin** — Confirm there is no open registration and that administrative
   access is limited to a dedicated administrator account.
2. **Seerr** — Confirm account creation is admin- or invite-controlled.
3. **Grafana** — Enable MFA for the `aljam` administrator account and review
   users, service accounts, and API keys.
4. **Vaultwarden** — Confirm the admin panel is not publicly discoverable or
   linked, enable MFA for user accounts, and rotate the admin token if it has
   ever been exposed.
5. **Radarr, Sonarr, Lidarr, Bazarr, Prowlarr** — Confirm forms authentication
   is enabled and API keys are protected.
6. **Audiobookshelf** — Confirm separate administrator and user accounts, and
   review API tokens.

## Completed reviews

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
  Grafana and Vaultwarden administrators.
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
