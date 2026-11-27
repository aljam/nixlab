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
    ../../modules/features/huggingface-cli.nix
    ../../modules/features/qwen-inference.nix
  ];

  networking.hostId = "acccc16e"; # Required for ZFS

  environment.systemPackages = with pkgs; [
    cudatoolkit
  ];

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

  modules.features.qwenInference = {
    enable = true;
    modelPath = "/var/lib/qwen-inference/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf";
    contextLength = 16384;
  };
}
