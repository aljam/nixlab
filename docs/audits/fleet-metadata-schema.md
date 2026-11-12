# Fleet metadata schema audit

## Goal

Make fleet host metadata explicit, validated during evaluation, and resistant to malformed addresses, missing fields, or unexpected attributes.

## Current state

`networking.fleet`, `networking.subnets`, and `networking.domains` already use stricter attribute types. However, fleet hosts still benefit from a dedicated schema that clearly distinguishes required identity fields from optional operational fields.

## Proposed host schema

Model each fleet host as a submodule with the following fields:

| Field | Type | Required | Purpose |
|---|---|---|---|
| `hostname` | non-empty string | yes | Canonical fleet hostname |
| `ip` | IPv4 address | no | Primary fleet address, when the host has one |
| `roles` | list of enum values | yes | Declared host responsibilities |
| `zpool` | non-empty string | no | Primary ZFS pool, when applicable |
| `site` | non-empty string | no | Physical or logical location |
| `description` | non-empty string | no | Human-readable host description |

Use `lib.types.submodule` for the host entry, with explicit option types and defaults where appropriate.

## Validation rules

Enforce these invariants during evaluation:

- Hostnames are unique across the fleet.
- IPv4 addresses, when present, are unique across the fleet.
- A host with a `zpool` must have a storage-related role or an explicit exception.
- A host with a fleet IP must have a valid IPv4 address.
- Role names come from a closed enumeration or a centrally registered role set.
- Unknown host attributes are rejected rather than silently accepted.

## Example

```nix
networking.fleet = {
  r730xd = {
    hostname = "r730xd";
    ip = "192.168.1.10";
    roles = [ "media-node" "storage-node" ];
    zpool = "tank";
    site = "home";
    description = "Primary media and storage server";
  };
};
```

## Migration steps

1. Inventory current fields in `networking.fleet`, `networking.subnets`, and `networking.domains`.
2. Define a `fleetHost` submodule with explicit types.
3. Add uniqueness and cross-field validation assertions.
4. Migrate host declarations incrementally, keeping backward-compatible fields where practical.
5. Add evaluation tests for duplicate hostnames, duplicate IPs, invalid addresses, and unknown roles.

## Acceptance criteria

- Invalid or unexpected fleet metadata fails during `nix flake check`.
- Hostname and IP uniqueness are enforced.
- Optional fields are explicit rather than implicit.
- Existing hosts continue to evaluate after migration.
- `nix flake check --no-build --print-build-logs` passes.
