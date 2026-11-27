{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
    ../../modules/hardware/dell-poweredge.nix
    ../../modules/roles/server-core.nix
    ../../modules/roles/storage-node.nix
    ../../modules/features/nvidia-headless.nix
    ../../modules/features/disk-health.nix
    ../../modules/features/qwen-inference.nix
    ../../modules/features/huggingface-cli.nix
    ../../modules/features/gpu-fan-control.nix
    ../../users/pervitiner/nixos.nix
  ];

  networking.hostId = "acccc16e"; # Required for ZFS

  networking.firewall.extraInputRules = ''
    # Allow LAN clients to reach the local Qwen inference API.
    ip saddr 192.168.1.0/24 tcp dport 8001 accept
  '';

  home-manager.users.pervitiner = import ../../users/pervitiner/home.nix;

  modules.features.disk-health = {
    enable = true;

    devices = [
      { path = "/dev/disk/by-id/wwn-0x5000c5007dd3fee3"; }
      { path = "/dev/disk/by-id/wwn-0x5000c5007dd70cb7"; }
      { path = "/dev/disk/by-id/wwn-0x5000c5007de11ecb"; }
      { path = "/dev/disk/by-id/wwn-0x5000c5007f119817"; }
      { path = "/dev/disk/by-id/wwn-0x5000c5007f1268cb"; }
      { path = "/dev/disk/by-id/wwn-0x5000c5007f138ae3"; }
      { path = "/dev/disk/by-id/wwn-0x5000c5008f0364e3"; }
      { path = "/dev/disk/by-id/wwn-0x5000c5008f0517e3"; }
    ];
  };

  modules.features.huggingfaceCli.enable = true;

  modules.features.gpuFanControl.enable = true;

  modules.features.qwenInference = {
    enable = true;
    modelPath = "/var/lib/qwen-inference/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf";
    contextLength = 163840;
    cacheTypeK = "q8_0";
  };
}
