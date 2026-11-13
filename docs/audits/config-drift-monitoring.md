# Configuration drift monitoring

## Status

Implemented.

## Controls

- Compare the active NixOS configuration revision with the expected revision.
- Detect failed critical systemd units.
- Detect listening TCP and UDP sockets that are not declared in the host inventory.
- Compare the active nftables ruleset hash with the expected ruleset hash.
- Export drift findings through node_exporter.
- Alert on revision drift, failed critical services, unexpected listeners, and firewall changes.

## Validation

Run:

```console
nix flake check --show-trace
nix build .#checks.x86_64-linux.drift-detection
./result/bin/nixos-test-driver
```

Confirm that the VM test detects revision drift and a failed critical service.
