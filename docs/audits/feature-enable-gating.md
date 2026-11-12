# Feature-module enable gating audit

## Goal

Make optional feature modules safe to import by requiring an explicit `enable` option before they activate services, containers, users, or persistence.

## Current pattern

Some feature modules currently activate behavior on import, while others already provide an `enable` option. This creates inconsistent composition semantics: importing a module can have side effects even when a role does not intend to use that feature.

## Audit checklist

For every module under `modules/features/`, verify:

- It defines `options.<feature>.enable` with `mkEnableOption`.
- Service, container, virtual-host, user, directory, and persistence definitions are guarded by `config.<feature>.enable`.
- Role modules explicitly set `enable = true` only for features they intend to activate.
- Disabled modules do not create users, state directories, containers, or reverse-proxy routes.

## Proposed convention

Use this shape for every optional feature:

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.<feature>;
in
{
  options.<feature>.enable = lib.mkEnableOption "<feature>";

  config = lib.mkIf cfg.enable {
    # services, containers, users, persistence, and routes
  };
}
```

## Migration order

1. Inventory every feature module and record whether it already has an `enable` option.
2. Add `mkEnableOption` where missing.
3. Guard all observable side effects with `lib.mkIf cfg.enable`.
4. Update role modules to explicitly enable the features they use.
5. Add a NixOS VM test that proves a disabled feature leaves no service, container, user, or route behind.

## Acceptance criteria

- Importing a feature module without setting `enable = true` has no host-level side effects.
- Every enabled feature remains explicitly visible in the role that uses it.
- `nix flake check --no-build --print-build-logs` passes.
