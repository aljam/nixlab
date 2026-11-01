# Tests

The flake maintains two active checks:

## `nftables-input-rules`

A fast, VM-free evaluation check that validates custom nftables input rules
across every host. It rejects overly broad rules that accept traffic without a
meaningful match condition.

## `firewall-isolation`

A NixOS VM integration test that validates network isolation between backend
services, the HAProxy gateway, and untrusted LAN hosts.

## Removed tests

The former service-health, service-isolation, backup, and standalone security
assertion tests were removed because they were unused or invalid. Their useful
sudo and SSH checks are now enforced by `modules/features/security-policy.nix`.
