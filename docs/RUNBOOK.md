# Runbook

Common operations and troubleshooting procedures for nixlab.

## Rebuilding a Host

### Local Rebuild

```bash
# Rebuild and switch to the new generation
sudo nixos-rebuild switch --flake .#<hostname>

# Rebuild without switching (test)
sudo nixos-rebuild build --flake .#<hostname>

# Show the diff before applying
sudo nixos-rebuild switch --flake .#<hostname> --show-trace

# Rebuild with install-bootloader (after disk changes)
sudo nixos-rebuild switch --flake .#<hostname> --install-bootloader
```

### Remote Rebuild

```bash
# From another machine with SSH access
nixos-rebuild switch --flake .#<hostname> --target-host <hostname>

# With sudo on remote
nixos-rebuild switch --flake .#<hostname> --target-host <hostname> --use-remote-sudo
```

## Rollback

```bash
# List generations
nixos-rebuild list-generations

# Rollback to previous generation (immediate)
sudo nixos-rebuild switch --rollback

# Rollback to a specific generation
sudo nixos-rebuild switch --generation <num>

# Boot into previous generation at next boot
# Select from boot menu (hold Shift during boot)
```

### After Bad Reboot

If you rebooted into a broken generation:

1. **Boot from previous generation** in the boot menu
2. **Make it permanent**:
   ```bash
   sudo nixos-rebuild switch --generation <num>
   ```

## Garbage Collection

```bash
# Remove old generations (keep last 5 for 7 days)
sudo nix-collect-garbage -d --delete-older-than 7d

# Run Nix store GC (removes unreferenced store paths)
nix-store --gc

# Vacuum the Nix store (optimize symlinks)
nix-store --optimise
```

## Service Management

```bash
# Check service status
systemctl status <service>

# Restart a service
sudo systemctl restart <service>

# Reload config (if supported)
sudo systemctl reload <service>

# View logs
journalctl -u <service> -f

# View all failed services
systemctl --failed

# Reset failed state
sudo systemctl reset-failed <service>
```

## Networking

```bash
# Check listening ports
ss -tlnp

# Check firewall rules
sudo nft list ruleset

# Test connectivity
curl -v http://<host>:<port>

# Check DNS resolution
resolvectl status

# Check network interfaces
ip addr show
```

## Storage

```bash
# Check ZFS pool status
zpool status

# Check ZFS snapshots
zfs list -t snapshot

# Check disk usage
df -h

# Check S.M.A.R.T. status
sudo smartctl -a /dev/sdX

# Run ZFS scrub (monthly)
zpool scrub <pool>
```

## Secrets

Secrets are split by service or trust boundary. See [SECRETS.md](SECRETS.md) for the complete file layout and recipient model.

```bash
# Decrypt a category file manually
sops -d secrets/common.yaml

# Edit and re-encrypt a category file in place
sops -e -i secrets/common.yaml

# Check sops-nix activation
journalctl -b | grep sops

# List decrypted secrets
ls -la /run/secrets.d/
```

Replace `common.yaml` with the relevant category file, such as `database.yaml`, `matrix.yaml`, `vaultwarden.yaml`, `monitoring.yaml`, `media.yaml`, or `nas.yaml`.

## Host-Key Recovery (Critical)

If you regenerated SSH host keys and SOPS decryption fails:

### Option 1: Rollback

```bash
# Boot into previous generation (before key change)
sudo nixos-rebuild switch --rollback

# Or select from boot menu
```

### Option 2: Re-encrypt affected category files

1. From a host or workstation that can still decrypt, export the plaintext:

   ```bash
   sops -d secrets/common.yaml > /tmp/common.yaml
   ```

2. Copy the new host public key and add it to the relevant `.sops.yaml` creation rule.

3. Copy the plaintext to the destination path and re-encrypt in place:

   ```bash
   cp /tmp/common.yaml secrets/common.yaml
   sops -e -i secrets/common.yaml
   ```

4. Update recipients for every affected category file:

   ```bash
   sops updatekeys secrets/common.yaml
   sops updatekeys secrets/database.yaml
   sops updatekeys secrets/matrix.yaml
   ```

5. Rebuild and verify decryption before rebooting.

### Option 3: Reset User Password (if aljam_password is lost)

1. Boot into any working generation.
2. Reset the password manually:

   ```bash
   passwd aljam
   ```

3. Generate a new password hash:

   ```bash
   mkpasswd -m yescrypt
   ```

4. Update `aljam_password` in `secrets/common.yaml`, re-encrypt it, and rebuild.

## Troubleshooting

### Build Fails

1. Check the error message for the failing module.
2. Run `nix flake check` to isolate evaluation errors.
3. Search the module for the failing attribute.
4. Check recent commits:

   ```bash
   git log -p -- <file>
   ```

5. Try building a minimal configuration to isolate the issue.

### Service Won't Start

```bash
# Verify secrets are present
ls -la /run/secrets.d/

# Check service dependencies
systemctl list-dependencies <service>

# Inspect service logs
journalctl -u <service> -b
```

### Network Unreachable

```bash
# Check firewall rules
sudo nft list ruleset

# Check listening sockets
ss -tlnp

# Test a backend directly
curl -v http://<backend>:<port>

# Check DNS
resolvectl status
```

### Disk Full

```bash
# Identify large directories
du -sh /* | sort -h

# Remove old generations and garbage
sudo nix-collect-garbage -d

# Remove old logs
sudo journalctl --vacuum-time=7d
```

### SOPS Decryption Fails

1. Check that the host SSH key matches a recipient in `.sops.yaml`:

   ```bash
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   cat .sops.yaml
   ```

2. Check activation logs:

   ```bash
   journalctl -b | grep sops
   ```

3. Verify that the expected category file exists and decrypts:

   ```bash
   sops -d secrets/common.yaml >/dev/null
   ```

4. Verify that the secret was materialized:

   ```bash
   ls -la /run/secrets.d/
   ```

### mutableUsers = false Lockout

If you are locked out because of a password issue:

1. Boot into a previous generation with a working password.
2. Reset the password manually or generate a new hash.
3. Update `aljam_password` in `secrets/common.yaml`.
4. Re-encrypt and rebuild.

## Emergency Access

### SSH Broken

1. Boot into the previous generation from the boot menu.
2. Fix the configuration.
3. Rebuild and test SSH before rebooting.

### System Won't Boot

```bash
# Example for a ZFS root system
mount -t zfs rpool/root /mnt
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
chroot /mnt

nixos-install --flake /path/to/flake#<hostname>
```

### ZFS Pool Degraded

```bash
zpool status -v
zpool replace <pool> <failed-disk> <replacement-disk>
zpool status -v
```
