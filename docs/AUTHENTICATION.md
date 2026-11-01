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
| `qb.derezzed.info` | qBittorrent | 8080 | WebUI authentication | Review | N/A | N/A | Review | Pending |
| `home.derezzed.info` | Homepage | 8082 | None; public dashboard | No admin UI | N/A | N/A | None | Pending |
| `derezzed.info` / `www.derezzed.info` | Static landing page | 8083 | None | None | N/A | N/A | None | Pending |

## Priority review order

1. **qBittorrent** — Confirm WebUI authentication is required and that bypass
   rules do not unintentionally apply to requests forwarded by HAProxy.
2. **Shoko** — Determine whether its administrative or API surface should be
   publicly reachable. If not, remove it from the HAProxy backend allowlist and
   public Homepage dashboard.
3. **Jellyfin** — Confirm there is no open registration and that administrative
   access is limited to a dedicated administrator account.
4. **Seerr** — Confirm account creation is admin- or invite-controlled.
5. **Grafana** — Enable MFA for the `aljam` administrator account and review
   users, service accounts, and API keys.
6. **Vaultwarden** — Confirm the admin panel is not publicly discoverable or
   linked, enable MFA for user accounts, and rotate the admin token if it has
   ever been exposed.
7. **Radarr, Sonarr, Lidarr, Bazarr, Prowlarr** — Confirm forms authentication
   is enabled and API keys are protected.
8. **Audiobookshelf** — Confirm separate administrator and user accounts, and
   review API tokens.

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
