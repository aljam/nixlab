# Binary caches trusted by every host. Caches for desktop-only software are
# added in modules/roles/desktop-node.nix so that servers do not trust them.
{
  ...
}:

{
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://aljam.cachix.org"
    "https://nix-community.cachix.org"
  ];

  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "aljam.cachix.org-1:E3E80fk8YEaTw0Y9V+0IHmhrvLQ/xACZ1VMXDZZ80oo="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
}
