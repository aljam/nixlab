# Authentication

This document inventories authentication boundaries for services exposed through the public gateway.

| Public hostname | Service | Port | Authentication | Administrative access | Self-registration | MFA | API keys | Last reviewed |
|---|---|---:|---|---|---|---|---|---|
| `home.derezzed.info` | Homepage | 8080 | None | None | N/A | N/A | None | 2026-11-01 |
| `jellyfin.derezzed.info` | Jellyfin | 8096 | Local accounts | Dedicated administrator account | Disabled | Not supported | Five expected integration keys | 2026-11-01 |
| `seerr.derezzed.info` | Jellyseerr/Overseerr | 5055 | Local accounts | Dedicated administrator account | Admin-controlled | Not supported | None | 2026-11-01 |
| `radarr.derezzed.info` | Radarr | 7878 | Application authentication | Public, authenticated | N/A | Not supported | Protected | 2026-11-01 |
| `sonarr.derezzed.info` | Sonarr | 8989 | Application authentication | Public, authenticated | N/A | Not supported | Protected | 2026-11-01 |
| `lidarr.derezzed.info` | Lidarr | 8686 | Application authentication | Public, authenticated | N/A | Not supported | Protected | 2026-11-01 |
| `prowlarr.derezzed.info` | Prowlarr | 9696 | Application authentication | Public, authenticated | N/A | Not supported | Protected | 2026-11-01 |
| `bazarr.derezzed.info` | Bazarr | 6767 | Application authentication | Public, authenticated | N/A | Not supported | Protected | 2026-11-01 |
| `autobrr.derezzed.info` | Autobrr | 9696 | Application authentication | Public, authenticated | N/A | Not supported | Protected | 2026-11-01 |
| `grafana.derezzed.info` | Grafana | 3000 | Local accounts | Dedicated administrator account | Disabled | Authenticator app | Service-account tokens | 2026-11-01 |
| `vault.derezzed.info` | Vaultwarden | 8222 | Local accounts | Admin token required | Disabled | Authenticator app | None | 2026-11-01 |
| `matrix.derezzed.info` | Matrix Synapse | 8008 | Local accounts | Dedicated administrator account | Enabled with CAPTCHA | Not supported | None | 2026-11-01 |
| `rtc.derezzed.info` | Matrix RTC | 443 | JWT | Administrative API not public | N/A | N/A | JWT | 2026-11-01 |
| `peertube.derezzed.info` | PeerTube | 9000 | Local accounts | Dedicated administrator account | Disabled | Not supported | None | 2026-11-01 |
| `radio.derezzed.info` | Radio | 8000 | None | Administrative interface not public | N/A | N/A | None | 2026-11-01 |

## Rules

- Public administrative interfaces must require authentication.
- Public self-registration must be explicitly approved and rate-limited.
- API keys must be stored in SOPS-managed secrets, not committed in plaintext.
- Services must not expose internal addresses, stack traces, or sensitive diagnostics.
- Authentication boundaries must be reviewed when services, ports, or public exposure change.
