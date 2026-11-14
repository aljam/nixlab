# Public service exposure

This document audits services intentionally reachable from the public Internet
through the pfSense HAProxy frontend.

`docs/public-endpoints.json` is the machine-readable source of truth for the
public hostname inventory. It is consumed by the edge-security workflow and
the Prometheus blackbox monitoring job.

A hostname may be added to that file only when:

- It is intentionally reachable from the public Internet.
- It is routed through the approved HAProxy frontend.
- Its backend service has a declared exposure intent.
- Its authentication, authorization, and rate-limiting boundary is documented.
- The service does not appear in `networking.internalOnlyPorts`.

## Exposure model

| Intent | Meaning | Public exposure |
|---|---|---|
| `loopback` | Reachable only from the hosting machine | Forbidden |
| `lan` | Reachable from trusted LAN hosts | Forbidden |
| `proxy` | Reachable through the HAProxy backend allowlist | Permitted when intentionally published |
| `public` | Directly reachable from the Internet | Requires explicit justification |

HAProxy is the approved public ingress path. A service must not be exposed
directly from the Internet unless its module explicitly justifies that
exposure.

## Public hostname inventory

| Hostname | Service | Exposure intent | Authentication boundary | Review rule |
|---|---|---|---|---|
| `home.derezzed.info` | Homepage | `proxy` | Public dashboard; verify no privileged actions or sensitive metadata are exposed. | Keep public only if the dashboard remains non-sensitive. |
| `jellyfin.derezzed.info` | Jellyfin | `proxy` | Application authentication. | Keep public only while user authentication and media-library permissions remain enforced. |
| `seerr.derezzed.info` | Overseerr | `proxy` | Application authentication. | Keep public only while request and administrative actions require authentication. |
| `audiobookshelf.derezzed.info` | Audiobookshelf | `proxy` | Application authentication. | Keep public only while library access remains authenticated. |
| `sonarr.derezzed.info` | Sonarr | `proxy` | Application authentication; public probe may receive 200 or 401. | Keep public only if unauthenticated access cannot mutate configuration or trigger actions. |
| `radarr.derezzed.info` | Radarr | `proxy` | Application authentication; public probe may receive 200 or 401. | Keep public only if unauthenticated access cannot mutate configuration or trigger actions. |
| `prowlarr.derezzed.info` | Prowlarr | `proxy` | Application authentication; public probe may receive 200 or 401. | Keep public only if unauthenticated access cannot mutate configuration or trigger actions. |
| `bazarr.derezzed.info` | Bazarr | `proxy` | Application authentication. | Keep public only if unauthenticated access cannot mutate configuration or trigger actions. |
| `lidarr.derezzed.info` | Lidarr | `proxy` | Application authentication; public probe may receive 200 or 401. | Keep public only if unauthenticated access cannot mutate configuration or trigger actions. |
| `autobrr.derezzed.info` | Autobrr | `proxy` | Application authentication. | Keep public only if unauthenticated access cannot mutate configuration or trigger actions. |
| `grafana.derezzed.info` | Grafana | `proxy` | Application authentication. | Keep public only if anonymous access remains disabled and administrative actions require authentication. |
| `vault.derezzed.info` | Vaultwarden | `proxy` | Application authentication. | Keep public only while vault access remains authenticated and encrypted. |
| `matrix.derezzed.info` | Matrix Synapse | `proxy` | Matrix federation/client protocol. | Keep public only while federation and client access are intentionally required. |
| `rtc.derezzed.info` | Matrix RTC | `proxy` | Matrix RTC protocol. | Keep public only while RTC access is intentionally required. |
| `peertube.derezzed.info` | PeerTube | `proxy` | Application authentication for administrative actions. | Keep public only while administrative actions require authentication. |
| `radio.derezzed.info` | Radio service | `proxy` | Public streaming endpoint; may redirect. | Keep public only while the stream is intended for public consumption. |

## Transport policy

Every public endpoint must require:

- HTTPS.
- TLS 1.2 or newer.
- HSTS.

These requirements are encoded in `docs/public-endpoints.json` and validated by
the edge-security workflow and Prometheus blackbox monitoring.

## Backend isolation

A public hostname must route to a backend port listed in
`networking.proxyBackendPorts`. It must not route to a port listed in
`networking.internalOnlyPorts`.

The firewall permits access to proxy backend ports only from the HAProxy
gateway. Other LAN hosts must not be able to reach those backend ports
directly.

## Review rule

Before adding a public hostname:

1. Add the backend port to `networking.proxyBackendPorts`.
2. Ensure the service is not listed in `networking.internalOnlyPorts`.
3. Confirm the service’s authentication and authorization model.
4. Add the hostname to `docs/public-endpoints.json`.
5. Add a row to the inventory above.
6. State why public access is necessary.
7. State the condition under which public access should be removed.

## Removal path

Remove a public hostname when:

- The service is no longer needed publicly.
- The service can be consumed through a VPN or LAN-only path.
- The service exposes sensitive functionality without an adequate
  authentication boundary.
- The service is deprecated or replaced.

Public exposure should be intentional, documented, and periodically reviewed.
