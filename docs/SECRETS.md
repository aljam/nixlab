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

## Recipient audit

CI runs `scripts/check-sops-recipients.py` to enforce the recipient matrix
above. The audit verifies that:

- every expected host and administrator recipient is defined exactly once;
- every recipient reference resolves to a defined key;
- every secret file has exactly one explicit creation rule;
- each rule grants exactly the recipients documented for that file; and
- no fleet-wide fallback rule exists.

The audit validates the declarative recipient policy. It does not decrypt
secret files or verify that an encrypted file was most recently re-encrypted
with the current policy.

## Recovery drill

Run the host-specific recovery drill before relying on a new or rebuilt host:

```bash
bash scripts/sops-recovery-drill.sh --host r730xd
```

The drill validates the recipient policy, resolves the selected host's SOPS
recipient, lists the secret files intended for that host, and prints the
recovery checklist.

To exercise decryption from a local SOPS identity that is authorized for the
host's allowed files, run:

```bash
bash scripts/sops-recovery-drill.sh --host r730xd --decrypt
```

CI runs the non-decrypting drill for `r730xd` and validates the script syntax.
Decryption requires a real SOPS identity and must be run locally or from a
trusted administrative environment.

## Changing recipients

After changing a creation rule in `.sops.yaml`, re-encrypt the affected file
locally:

```bash
sops updatekeys secrets/nas.yaml
sops -d secrets/nas.yaml >/dev/null
```

Then rebuild only hosts that should retain access to that secret file.

When replacing or rebuilding a host, preserve or rotate its SSH Ed25519 host
key, update its recipient in `.sops.yaml`, run `sops updatekeys` for every
affected secret file, and confirm decryption on the rebuilt host before
deploying further changes.
