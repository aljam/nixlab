# SOPS secrets

Secrets are service-scoped to reduce the impact of a compromised host or
credential. Every secret file has an explicit SOPS creation rule; there is no
fleet-wide fallback rule.

## Recipient model

| Secret file | Recipients | Purpose |
|---|---|---|
| `secrets/common.yaml` | `aljam`, all hosts | Shared user/login secrets. |
| `secrets/nas.yaml` | `aljam`, `navi`, `oryx` | NAS credentials for desktop hosts that mount the NAS. |
| `secrets/database.yaml` | `aljam`, `r730xd` | PostgreSQL and pgAdmin secrets. |
| `secrets/matrix.yaml` | `aljam`, `r730xd` | Matrix Synapse, MatrixRTC, LiveKit, and pfSense CA secrets. |
| `secrets/vaultwarden.yaml` | `aljam`, `r730xd` | Vaultwarden secrets. |
| `secrets/monitoring.yaml` | `aljam`, `r730xd` | Grafana and alerting secrets. |
| `secrets/media.yaml` | `aljam`, `r730xd` | Radarr, Sonarr, and Recyclarr API keys. |

Servers do not receive NAS credentials because they do not mount the NAS.

## Changing recipients

After changing a creation rule in `.sops.yaml`, re-encrypt the affected file
locally:

```bash
sops updatekeys secrets/nas.yaml
sops -d secrets/nas.yaml >/dev/null
```

Then rebuild only hosts that should retain access to that secret file.
