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
```

### Remote Rebuild

```bash
# From another machine with SSH access
nixos-rebuild switch --flake .#<hostname> --target-host <hostname>
```

## Rollback

```bash
# List generations
nixos-rebuild list-generations

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Rollback to a specific generation
sudo nixos-rebuild switch --generation <num>
```

## Garbage Collection

```bash
# Remove old generations (keep last 5)
sudo nix-collect-garbage -d --delete-older-than 7d

# Run Nix GC
sudo nix gc

# Vacuum the Nix store
sudo nix store optimise
```

## Service Management

```bash
# Check service status
systemctl status <service>

# Restart a service
sudo systemctl restart <service>

# View logs
journalctl -u <service> -f

# View all failed services
systemctl --failed
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
```

## Secrets

```bash
# Decrypt a secret manually
sops -d secrets/secrets.yaml

# Re-encrypt after editing
sops -e -i secrets/secrets.yaml

# Check sops-nix activation
journalctl -u sops-nix
```

## Troubleshooting

### Build Fails

1. Check the error message for the failing module
2. Run `nix flake check` to isolate evaluation errors
3. Search the module for the failing attribute
4. Check recent commits with `git log -p -- <file>`

### Service Won't Start

1. Check `journalctl -u <service>` for errors
2. Verify secrets are present: `ls -la /run/secrets.d/`
3. Check configuration: `nixos-option services.<service>`
4. Test with minimal config in a temporary flake

### Network Unreachable

1. Check firewall: `sudo nft list ruleset`
2. Verify HAProxy is running: `systemctl status haproxy`
3. Test backend directly: `curl http://<backend>:<port>`
4. Check DNS resolution: `dig <hostname>`

### Disk Full

1. Identify large files: `du -sh /* | sort -h`
2. Clean Nix store: `sudo nix-collect-garbage -d`
3. Remove old logs: `sudo journalctl --vacuum-time=7d`
4. Check for orphaned snapshots: `zfs list -t snapshot`

## Emergency Access

If SSH is broken:

1. Boot into the previous generation from the boot menu
2. Fix the configuration
3. Rebuild and test SSH before rebooting

If the system won't boot:

1. Boot from a NixOS installer USB
2. Mount the root filesystem
3. Chroot and rebuild: `nixos-install --flake .#<hostname>`
