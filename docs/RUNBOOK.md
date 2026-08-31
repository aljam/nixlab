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
sudo nix-store --gc

# Vacuum the Nix store (optimize symlinks)
sudo nix-store --optimise

# Check disk usage
nix-du  # or: nix-visualize /nix/store
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

# Check DNS
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
sudo zpool scrub <pool>
```

## Secrets

```bash
# Decrypt a secret manually
sops -d secrets/secrets.yaml

# Re-encrypt after editing
sops -e -i secrets/secrets.yaml

# Check sops-nix activation
journalctl -b | grep sops

# List decrypted secrets
ls -la /run/secrets.d/
```

## Host-Key Recovery (Critical)

If you regenerated SSH host keys and SOPS decryption fails:

### Option 1: Rollback

```bash
# Boot into previous generation (before key change)
sudo nixos-rebuild switch --rollback

# Or select from boot menu
```

### Option 2: Manual Decrypt from Another Host

```bash
# From a host that can still decrypt (has valid key in .sops.yaml)
sops -d secrets/secrets.yaml > /tmp/secrets-plain.yaml

# Copy new host public key
scp /etc/ssh/ssh_host_ed25519_key.pub other-host:/tmp/

# Re-encrypt with new key
sops -e --age <new-key-pub> /tmp/secrets-plain.yaml > secrets/secrets.yaml

# Update .sops.yaml with new key
# Run sops updatekeys
sops updatekeys secrets/secrets.yaml

# Rebuild
sudo nixos-rebuild switch
```

### Option 3: Reset User Password (if aljam_password lost)

```bash
# Boot into any generation
# At boot menu, select "Systemd rescue mode" or add "init=/bin/sh" to kernel cmdline

# Mount root if needed
mount -o remount,rw /

# Reset password manually
passwd aljam

# Rebuild with new password hash
# (update secrets.yaml with new hash, re-encrypt, rebuild)
```

## Troubleshooting

### Build Fails

1. Check the error message for the failing module
2. Run `nix flake check` to isolate evaluation errors
3. Search the module for the failing attribute
4. Check recent commits with `git log -p -- <file>`
5. Try building a minimal config to isolate the issue

### Service Won't Start

1. Check `journalctl -u <service>` for errors
2. Verify secrets are present: `ls -la /run/secrets.d/`
3. Check configuration: `nixos-option services.<service>`
4. Test with minimal config in a temporary flake
5. Check dependencies: `systemctl list-dependencies <service>`

### Network Unreachable

1. Check firewall: `sudo nft list ruleset`
2. Verify HAProxy is running on pfSense (192.168.1.1)
3. Test backend directly: `curl http://<backend>:<port>`
4. Check DNS resolution: `dig <hostname>`
5. Verify route: `ip route get <dest>`

### Disk Full

1. Identify large files: `du -sh /* | sort -h`
2. Clean Nix store: `sudo nix-collect-garbage -d`
3. Remove old logs: `sudo journalctl --vacuum-time=7d`
4. Check for orphaned snapshots: `zfs list -t snapshot`
5. Remove old generations: `nixos-rebuild list-generations` then `nixos-rebuild delete-generations --old`

### SOPS Decryption Fails

1. Check host SSH key matches `.sops.yaml`:
   ```bash
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   cat .sops.yaml
   ```
2. Check activation logs: `journalctl -b | grep sops`
3. Verify secret exists: `ls -la /run/secrets.d/`
4. Test manual decrypt: `sops -d secrets/secrets.yaml`

### mutableUsers = false Lockout

If you're locked out due to password issues:

1. **Boot into previous generation** with working password
2. **Or use systemd rescue mode** to reset password manually
3. **Update secrets.yaml** with new password hash
4. **Re-encrypt and rebuild**

## Emergency Access

### SSH Broken

1. Boot into the previous generation from the boot menu
2. Fix the configuration
3. Rebuild and test SSH before rebooting

### System Won't Boot

1. Boot from a NixOS installer USB
2. Mount the root filesystem:
   ```bash
   mount -t zfs rpool/root /mnt
   ```
3. Chroot and rebuild:
   ```bash
   mount --bind /dev /mnt/dev
   mount --bind /proc /mnt/proc
   mount --bind /sys /mnt/sys
   chroot /mnt
   nixos-install --flake /path/to/flake#<hostname>
   ```

### ZFS Pool Degraded

1. Check pool status: `zpool status -v`
2. Identify failed disk: `smartctl -a /dev/sdX`
3. Replace disk and resilver:
   ```bash
   zpool replace <pool> <old-disk> <new-disk>
   zpool status  # Monitor resilver
   ```
