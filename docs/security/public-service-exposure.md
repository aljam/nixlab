# Public service exposure

This document records the intended public exposure for services reachable through the pfSense HAProxy gateway.

| Public hostname | Service | Exposure | Security boundary | Disposition |
|---|---|---|---|---|
| `home.derezzed.info` | Homepage | `proxy` | Public dashboard; verify no privileged actions or sensitive metadata are exposed. | Keep public only if the dashboard remains non-sensitive. |
| `jellyfin.derezzed.info` | Jellyfin | `proxy` | Application authentication. | Keep public only while user authentication and media-library permissions remain enforced. |
| `seerr.derezzed.info` | Overseerr | `proxy` | Application authentication. | Keep public only while request and administrative actions require authentication. |
| `sonarr.derezzed.info` | Sonarr | `proxy` | Application authentication; public probe may receive 200 or 401. | Keep public only if unauthenticated access cannot mutate configuration or trigger actions. |
| `radarr.derezzed.info` | Radarr | `proxy` | Application authentication; public probe may receive 200 or 401. | Keep public only if unauthenticated access cannot mutate configuration or trigger actions. |
| `prowlarr.derezzed.info` | Prowlarr | `proxy` | Application authentication; public probe may receive 200 or 401. | Keep public only if unauthenticated access cannot mutate configuration or trigger actions. |
| `bazarr.derezzed.info` | Bazarr | `proxy` | Application authentication. | Keep public only if unauthenticated access cannot mutate configuration or trigger actions. |
| `lidarr.derezzed.info` | Lidarr | `proxy` | Application authentication; public probe may receive 200 or 401. | Keep public only if unauthenticated access cannot mutate configuration or trigger actions. |
| `autobrr.derezzed.info` | Autobrr | `proxy` | Application authentication. | Keep public only if unauthenticated access cannot mutate configuration or trigger actions. |
| `grafana.derezzed.info` | Grafana | `proxy` | Application authentication. | Keep public only while administrative access remains authenticated. |
| `vault.derezzed.info` | Vaultwarden | `proxy` | Application authentication. | Keep public only while signups remain disabled and administrative access remains protected. |
| `matrix.derezzed.info` | Matrix Synapse | `proxy` | Application authentication; public registration requires CAPTCHA. | Keep public only while registration controls and administrative access remain enforced. |
| `rtc.derezzed.info` | Matrix RTC | `proxy` | JWT-protected Real-Time Communication service. | Keep public only while JWT validation and RTC access controls remain enforced. |
| `peertube.derezzed.info` | PeerTube | `proxy` | Application authentication. | Keep public only while signups remain disabled and administrative access remains protected. |
| `radio.derezzed.info` | Radio | `proxy` | Public streaming endpoint; administrative interface must remain internal. | Keep public only while the administrative interface remains internal. |

## Rules

- Every public hostname must be intentionally declared in `docs/public-endpoints.json`.
- Public endpoints must use HTTPS and require HSTS.
- Public endpoints must require TLS 1.2 or newer.
- Administrative interfaces, databases, caches, message queues, and internal services must not be publicly reachable.
- Debug endpoints, metrics, source maps, and sensitive diagnostics must not be publicly exposed unless explicitly approved.
- Public exposure must be reviewed whenever a service, port, route, or authentication boundary changes.
