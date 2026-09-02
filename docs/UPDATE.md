# Update Process

This document describes how to update NixLab hosts and handle rollbacks.

## Regular Updates

### 1. Update the Flake

Update flake inputs to latest versions:

```bash
cd ~/nixlab
nix flake update
```

To update a specific input only:

```bash
nix flake update nixpkgs
```

### 2. Test Evaluation

Verify the flake evaluates correctly and passes checks:

```bash
nix flake check
```

This runs:
- NixOS module evaluation for all hosts
- nixfmt formatting checks
- statix lints
- deadnix dead code detection

### 3. Build and Switch

Rebuild the target host:

```bash
sudo nixos-rebuild switch --flake .#hostname
```

Replace `hostname` with the target machine (`navi`, `oryx`, `r730`, `r730xd`, `r820`).

### 4. Verify Services

Check critical services are running:

```bash
# Check systemd units
systemctl status

# Check specific services
systemctl status haproxy
systemctl status vaultwarden
systemctl status prometheus
systemctl status grafana-server
systemctl status podman

# Check network sockets
ss -tlnp | grep -E ':(80|443|3000|8200|9090)'

# Check firewall rules
sudo nft list ruleset
```

### 5. Monitor for Issues

Watch logs for errors in the first few minutes:

```bash
journalctl -f -p err
```

---

## Emergency Rollback

If an update causes issues, rollback to the previous generation:

### Immediate Rollback (Current Boot)

```bash
sudo nixos-rebuild switch --rollback
```

This reverts to the previous generation without rebooting.

### Rollback on Next Boot

If the system is already rebooted into a broken state:

1. **From GRUB menu**: Select the previous generation at boot time
2. **After booting**: Run `sudo nixos-rebuild switch --rollback`

### Delete Broken Generations

Clean up old generations to save space:

```bash
# Delete generations older than 7 days
sudo nix-collect-garbage --delete-older-than 7d

# Or delete all but the current generation
sudo nix-collect-garbage --delete-generations old
```

---

## Host-Specific Notes

### Servers (r730, r730xd, r820)

- Updates are typically safe to apply without downtime
- HAProxy and backend services restart gracefully
- Verify monitoring (Prometheus/Grafana) after update

### Desktops (navi, oryx)

- May require logout/login for desktop environment changes
- Hyprland updates may need a restart
- Check audio and GPU drivers after kernel updates

### Storage Node (r820)

- ZFS pool status should be verified after updates:
  ```bash
  zpool status
  ```

---

## Troubleshooting

### Build Fails

```bash
# Check what changed
git diff HEAD~1

# Try building without switching
sudo nixos-rebuild build --flake .#hostname

# Check logs
journalctl -xe
```

### Service Won't Start

```bash
# Check service status
systemctl status <service-name>

# View service logs
journalctl -u <service-name> -f

# Check configuration syntax
nixos-rebuild build --flake .#hostname 2>&1 | grep -i error
```

### Network Issues After Update

```bash
# Check firewall rules
sudo nft list ruleset

# Verify networking options
nix eval .#nixosConfigurations.hostname.config.networking

# Check if services are listening
ss -tlnp
```

---

## Best Practices

1. **Test on one host first**: Apply updates to a non-critical host before production servers
2. **Keep generations**: Don't garbage collect immediately; keep at least 2-3 generations
3. **Monitor after updates**: Watch Grafana dashboards for anomalies
4. **Update regularly**: Small, frequent updates are safer than large jumps
5. **Document issues**: If an update breaks something, note it in the commit message or runbook
