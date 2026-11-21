{
  imports = [
    ./hardware-configuration.nix
    ../../modules/roles/desktop-node.nix
    ../../modules/hardware/system76-laptop.nix
  ];

  # Fetch CachyOS kernel outputs when available instead of compiling them on
  # the laptop. See the first-rebuild instructions in CACHIX.md.
  nix.settings = {
    substituters = [ "https://cache.lantian.pub/lantian" ];
    trusted-public-keys = [ "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ=" ];
  };
}
