# Binary caches trusted by every host. Caches for desktop-only software are
# added in modules/roles/desktop-node.nix so that servers do not trust them.
{ lib, config, ... }:

let
  # Keep each substituter and its signing key together. This prevents the
  # substituter and trusted-public-key lists from drifting independently.
  caches = {
    "https://cache.nixos.org" = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
    "https://aljam.cachix.org" = "aljam.cachix.org-1:E3E80fk8YEaTw0Y9V+0IHmhrvLQ/xACZ1VMXDZZ80oo=";
    "https://nix-community.cachix.org" = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
  };

  cacheUrls = lib.attrNames caches;
  cacheKeys = lib.attrValues caches;

  duplicateUrls = lib.subtractLists (lib.unique cacheUrls) cacheUrls;
  duplicateKeys = lib.subtractLists (lib.unique cacheKeys) cacheKeys;
in
{
  assertions = [
    {
      assertion = duplicateUrls == [ ];
      message = "Nix substituter URLs must be unique. Duplicates: ${lib.concatStringsSep ", " duplicateUrls}";
    }
    {
      assertion = duplicateKeys == [ ];
      message = "Nix trusted public keys must be unique. Duplicates: ${lib.concatStringsSep ", " duplicateKeys}";
    }
  ];

  nix.settings = {
    substituters = cacheUrls;
    trusted-public-keys = cacheKeys;
  };
}
