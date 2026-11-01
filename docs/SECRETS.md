# Secrets Management

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) using age keys and managed via [sops-nix](https://github.com/Mic92/sops-nix).

## Structure

Secrets are split by service or trust boundary:

```text
secrets/
├── common.yaml       # Fleet-wide user/login secrets
├── nas.yaml          # CIFS credentials
├── database.yaml     # PostgreSQL / pgAdmin
├── matrix.yaml       # Matrix Synapse and Matrix RTC / LiveKit
├── vaultwarden.yaml  # Vaultwarden
├── monitoring.yaml   # Grafana and alerting
└── media.yaml        # Radarr, Sonarr, and media automation API keys
```

Each module that consumes a secret declares its own `sopsFile`. Do not add a global `sops.defaultSopsFile`.

## Key Model

Age identities are host SSH Ed25519 keys:

- Each host's age identity is `/etc/ssh/ssh_host_ed25519_key`
- The corresponding public key is in `.sops.yaml` under the relevant `creation_rules`
- This ties secrets to the host's SSH identity, not a separate age key

## Verify host age recipients

After initially deploying a host, replacing its host key, or changing `.sops.yaml`, verify that its SSH-derived age public key matches the recipient configured in `.sops.yaml`.

From an administrative machine:

```bash
ssh <host> 'cat /etc/ssh/ssh_host_ed25519_key.pub' | ssh-to-age
```

Or run this on the host:

```bash
sudo nix-shell -p age --run \
  'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub'
```

The resulting `age1...` value must exactly match that host's entry in `.sops.yaml`. If it does not, update the recipient and re-encrypt every secret file that includes that host.

## Recipient model

| File | Intended recipients | Consumers |
|---|---|---|
| `common.yaml` | Desktop key and all hosts | User configuration |
| `nas.yaml` | Desktop key and hosts importing `nas-mount.nix` | CIFS mount |
| `database.yaml` | Desktop key and PostgreSQL host | pgAdmin |
| `matrix.yaml` | Desktop key and Matrix/LiveKit host | Matrix Synapse, LiveKit |
| `vaultwarden.yaml` | Desktop key and Vaultwarden host | Vaultwarden |
| `monitoring.yaml` | Desktop key and monitoring host | Grafana |
| `media.yaml` | Desktop key and media automation host | Recyclarr |

The desktop key is included so secrets can be edited locally. Remove it from a file's recipients if local editing is not required.

## Media secrets

`secrets/media.yaml` must contain the API keys used by Recyclarr:

```yaml
radarr_api_key: <Radarr API key>
sonarr_api_key: <Sonarr API key>
```

Recyclarr loads these keys through systemd credentials and uses them to connect
to local Radarr and Sonarr instances. It expects the Servarr stack to be enabled
on the same host.

## Encrypt a secret file

SOPS matches `creation_rules` against the **input path**. Create the plaintext temporarily at the destination path, then encrypt it in place:

```bash
cp /tmp/common.yaml secrets/common.yaml
sops -e -i secrets/common.yaml

cp /tmp/nas.yaml secrets/nas.yaml
sops -e -i secrets/nas.yaml

cp /tmp/database.yaml secrets/database.yaml
sops -e -i secrets/database.yaml

cp /tmp/matrix.yaml secrets/matrix.yaml
sops -e -i secrets/matrix.yaml

cp /tmp/vaultwarden.yaml secrets/vaultwarden.yaml
sops -e -i secrets/vaultwarden.yaml

cp /tmp/monitoring.yaml secrets/monitoring.yaml
sops -e -i secrets/monitoring.yaml

cp /tmp/media.yaml secrets/media.yaml
sops -e -i secrets/media.yaml
```

Never commit the plaintext files from `/tmp`.

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

## Host-key rotation

If a host SSH Ed25519 key is regenerated, update its age recipient in `.sops.yaml` and re-encrypt every file that includes that recipient:

```bash
sops updatekeys secrets/common.yaml
sops updatekeys secrets/database.yaml
sops updatekeys secrets/matrix.yaml
sops updatekeys secrets/media.yaml
```

Test decryption before rebooting. If a host key is lost or rotated without updating recipients, SOPS decryption will fail on that host.

## Best practices

- Never commit plaintext secrets.
- Keep each secret in the narrowest appropriate category file.
- Use `neededForUsers = true` only for secrets required before user creation.
- Back up host SSH keys; they are the hosts' age identities.
- Test decryption after any host-key or `.sops.yaml` change.
