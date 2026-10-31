# Secrets Management

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) using age keys and managed via [sops-nix](https://github.com/Mic92/sops-nix).

## Structure

Secrets are split by service or trust boundary rather than kept in one global file:

```text
secrets/
├── common.yaml       # Fleet-wide user/login secrets
├── nas.yaml          # CIFS credentials
├── database.yaml     # PostgreSQL / pgAdmin
├── matrix.yaml       # Matrix Synapse and Matrix RTC / LiveKit
├── vaultwarden.yaml  # Vaultwarden
├── monitoring.yaml   # Grafana and alerting
└── backup.yaml       # Backup credentials
```

Each module that consumes a secret declares its own `sopsFile`. Do not add a global `sops.defaultSopsFile`.

## Key Model

Age identities are host SSH Ed25519 keys:

- Each host's age identity is `/etc/ssh/ssh_host_ed25519_key`
- The corresponding public key is in `.sops.yaml` under the relevant `creation_rules`
- This ties secrets to the host's SSH identity, not a separate age key

## Recipient model

| File | Intended recipients |
|---|---|
| `common.yaml` | Desktop key and all hosts |
| `nas.yaml` | Desktop key and hosts importing `nas-mount.nix` |
| `database.yaml` | Desktop key and PostgreSQL host |
| `matrix.yaml` | Desktop key and Matrix/LiveKit host |
| `vaultwarden.yaml` | Desktop key and Vaultwarden host |
| `monitoring.yaml` | Desktop key and monitoring host |
| `backup.yaml` | Desktop key and backup-capable hosts |

The desktop key is included so secrets can be edited locally. Remove it from a file's recipients if local editing is not required.

## Encrypt a new secret file

Create plaintext YAML outside the repository, then encrypt it into the intended path:

```bash
sops -e /tmp/common.yaml > secrets/common.yaml
sops -e /tmp/nas.yaml > secrets/nas.yaml
sops -e /tmp/database.yaml > secrets/database.yaml
sops -e /tmp/matrix.yaml > secrets/matrix.yaml
sops -e /tmp/vaultwarden.yaml > secrets/vaultwarden.yaml
sops -e /tmp/monitoring.yaml > secrets/monitoring.yaml
sops -e /tmp/backup.yaml > secrets/backup.yaml
```

SOPS selects recipients from the matching `creation_rules` entry in `.sops.yaml`.

## Use a secret in a module

```nix
{ config, ... }:
{
  sops.secrets.my-secret = {
    sopsFile = ../../secrets/database.yaml;
    owner = "my-service";
    group = "my-service";
    mode = "0400";
  };

  users.users.my-service.hashedPasswordFile =
    config.sops.secrets.my-secret.path;
}
```

For a secret required before user creation, set:

```nix
sops.secrets.aljam_password = {
  sopsFile = ../../secrets/common.yaml;
  neededForUsers = true;
};
```

## Migration from the legacy file

The former `secrets/secrets.yaml` remains intact until all new category files have been created, encrypted, and validated.

1. Decrypt the legacy file to temporary plaintext:

   ```bash
   sops -d secrets/secrets.yaml > /tmp/all-secrets.yaml
   ```

2. Split the relevant keys into temporary plaintext category files.

3. Encrypt each category file using the commands above.

4. Verify decryption locally:

   ```bash
   sops -d secrets/common.yaml >/dev/null
   sops -d secrets/database.yaml >/dev/null
   ```

5. Rebuild and activate one host before migrating the rest.

6. Delete `secrets/secrets.yaml` only after every consuming host has successfully rebuilt and activated.

## Host-key rotation

If a host SSH Ed25519 key is regenerated, update its age recipient in `.sops.yaml` and re-encrypt every file that includes that recipient:

```bash
sops updatekeys secrets/common.yaml
sops updatekeys secrets/database.yaml
```

Test decryption before rebooting. If a host key is lost or rotated without updating recipients, SOPS decryption will fail on that host.

## Best practices

- Never commit plaintext secrets.
- Keep each secret in the narrowest appropriate category file.
- Use `neededForUsers = true` only for secrets required before user creation.
- Back up host SSH keys; they are the hosts' age identities.
- Test decryption after any host-key or `.sops.yaml` change.
