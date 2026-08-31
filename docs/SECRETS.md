# Secrets Management

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) using age keys and managed via [sops-nix](https://github.com/Mic92/sops-nix).

## Structure

```
secrets/
└── secrets.yaml    # Single encrypted file for all hosts
```

## Key Model

**Age identities are host SSH Ed25519 keys:**

- Each host's age identity is `/etc/ssh/ssh_host_ed25519_key`
- The corresponding public key is in `.sops.yaml` under the `age` recipients
- This ties secrets to the host's SSH identity, not a separate age key

### .sops.yaml

```yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    age: >-
      ssh-ed25519 AAAA... (r730),
      ssh-ed25519 AAAA... (r730xd),
      ssh-ed25519 AAAA... (r820),
      ssh-ed25519 AAAA... (navi),
      ssh-ed25519 AAAA... (oryx)
```

## Setup

### 1. Host SSH Key as Age Identity

On each host, the SSH Ed25519 host key is used directly:

```bash
# The private key (age identity)
/etc/ssh/ssh_host_ed25519_key

# The public key (SOPS recipient)
/etc/ssh/ssh_host_ed25519_key.pub
```

No separate age key is needed.

### 2. Encrypt a Secret

```bash
# Create plaintext YAML
cat > secret.yaml <<EOF
my-secret:
  path: /run/secrets/my-secret
  owner: root
  group: root
  mode: "0400"
EOF

# Encrypt with all host keys
sops -e secret.yaml > secrets/secrets.yaml
```

### 3. Define Secret in secrets.yaml

```yaml
# secrets/secrets.yaml
aljam_password:
  path: /run/secrets/users/aljam/password
  owner: root
  group: root
  mode: "0400"
  neededForUsers: true  # Critical for mutableUsers = false

cifs_credentials:
  path: /run/secrets/cifs-credentials
  owner: root
  group: root
  mode: "0400"
```

### 4. Import in NixOS Configuration

```nix
# In common.nix or host config
{ config, ... }:
{
  sops.secrets.aljam_password = {
    path = "/run/secrets/users/aljam/password";
    owner = "aljam";
    group = "aljam";
    mode = "0400";
    neededForUsers = true;  # Must be available before user creation
  };

  # Use the secret
  users.users.aljam.hashedPasswordFile = config.sops.secrets.aljam_password.path;
}
```

## Decryption

Secrets are decrypted automatically during system activation by the `sops-nix` activation script. They are materialized in `/run/secrets.d/` and symlinked to the configured paths.

## Host-Key Regeneration Footgun

**Critical:** If you regenerate a host's SSH Ed25519 key, SOPS decryption will fail on that host until you update the recipients.

### Recovery Steps

1. **Boot into previous generation** (before key change) if possible:
   ```bash
   sudo nixos-rebuild switch --rollback
   ```

2. **Or manually decrypt from another host** with valid key:
   ```bash
   # From a host that can still decrypt
   sops -d secrets/secrets.yaml > secrets-seed.yaml
   
   # Re-encrypt with new host key
   sops -e --age <new-host-key-pub> secrets-seed.yaml > secrets/secrets.yaml
   ```

3. **Update .sops.yaml** with new host public key:
   ```bash
   # Add new ssh-ed25519 AAAA... to .sops.yaml
   # Remove old key
   ```

4. **Run sops updatekeys**:
   ```bash
   sops updatekeys secrets/secrets.yaml
   ```

5. **Rebuild**:
   ```bash
   sudo nixos-rebuild switch
   ```

### Prevention

- **Don't regenerate host keys** unless necessary
- **Backup `/etc/ssh/ssh_host_ed25519_key`** before any key rotation
- **Test decryption** after key changes before rebooting

## mutableUsers = false Implications

With `users.mutableUsers = false`, user passwords are set at build time from secrets:

- `neededForUsers = true` is **required** for `aljam_password`
- If the secret is missing or can't be decrypted, user creation fails
- Recovery requires booting a generation with valid secrets or manually setting password

## Best Practices

- **Never commit plaintext secrets** - only encrypted `secrets.yaml`
- **Backup host SSH keys** - they are your age identities
- **Test decryption** after any host-key or `.sops.yaml` change
- **Use `neededForUsers`** for secrets required before user creation
- **Keep secrets minimal** - one file, host-specific values in subkeys if needed

## Troubleshooting

### "No valid key found"

The host SSH key doesn't match any recipient in `.sops.yaml`:

```bash
# Check current host key
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub

# Compare with .sops.yaml recipients
cat .sops.yaml
```

### "Decryption failed after host-key change"

See [Host-Key Regeneration Footgun](#host-key-regeneration-footgun) above.

### "Secret not available at boot"

Check activation order:

```bash
# View sops-nix activation script
cat /run/current-system/sw/bin/sops-nix-activation

# Check journal
journalctl -b | grep sops
```

For CIFS mounts that need secrets, add:

```nix
fileSystems."/mnt/nas" = {
  device = "//192.168.2.10/share";
  fsType = "cifs";
  options = [
    "credentials=/run/secrets/cifs-credentials"
    "noauto"
    "x-systemd.automount"
    "x-systemd.requires=sops-nix.service"
  ];
};
```
