# Secrets Management

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) using age keys and managed via [sops-nix](https://github.com/Mic92/sops-nix).

## Structure

```
secrets/
└── secrets.yaml    # Encrypted secrets
```

## Setup

### 1. Generate an Age Key

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

### 2. Add Your Public Key to `.sops.yaml`

Edit `.sops.yaml` and add your age public key to the `age` recipients list.

### 3. Encrypt a Secret

```bash
# Create a plaintext file
echo "my-secret-value" > secret.txt

# Encrypt it
sops -e secret.txt > secrets/secret.yaml.encrypted

# Or use sops-nix format
sops -e --input-type yaml --output-type yaml secret.yaml > secrets/secrets.yaml
```

### 4. Define in secrets.yaml

```yaml
# secrets/secrets.yaml
my-secret:
  path: /run/secrets/my-secret
  owner: root
  group: root
  mode: "0400"
```

### 5. Import in NixOS Configuration

```nix
# In your host or module
{ config, ... }:
{
  sops.secrets.my-secret = {
    path = "/run/secrets/my-secret";
    owner = "myuser";
    group = "mygroup";
    mode = "0400";
  };

  # Use the secret
  systemd.services.my-service = {
    environment = {
      MY_SECRET = config.sops.secrets.my-secret.path;
    };
  };
}
```

## Decryption

Secrets are decrypted automatically during system activation by the `sops-nix` activation script. They are materialized in `/run/secrets.d/` and symlinked to the configured paths.

## Best Practices

- **Never commit plaintext secrets** - only encrypted `.yaml` files
- **Use specific owners/groups** - restrict access to the minimum required
- **Rotate keys periodically** - re-encrypt with new age keys
- **Backup age keys securely** - store in a password manager or hardware token

## Troubleshooting

### "No valid key found"

Ensure your age public key is in `.sops.yaml` and your private key is in `~/.config/sops/age/keys.txt`.

### "File has not been modified"

SOPS tracks modification time. If the file hasn't changed, re-encrypt with `sops -d -i secrets/secrets.yaml`.

### Mount ordering issues

If a service needs secrets before mounting filesystems, add `x-systemd.requires=sops-nix.service` to the mount options.
