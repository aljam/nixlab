{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.features.qwenInference;

  # Tesla P40 is Pascal (compute capability 6.1) and requires the legacy
  # proprietary NVIDIA driver configured by `modules/features/nvidia-headless.nix`.
  # CUDA 12.2 matches the maximum CUDA version supported by the legacy 535
  # driver branch and includes support for the P40 architecture.
  llamaCppCuda = pkgs.llama-cpp.override {
    cudaSupport = true;
    cudaPackages = pkgs.cudaPackages_12_2;
  };

  startScript = pkgs.writeShellScript "qwen-inference-start" ''
    exec ${cfg.package}/bin/llama-server \
      --host ${lib.escapeShellArg cfg.host} \
      --port ${toString cfg.port} \
      --model ${lib.escapeShellArg cfg.modelPath} \
      --ctx-size ${toString cfg.contextLength} \
      --n-gpu-layers ${toString cfg.gpuLayers} \
      --split-mode layer \
      --tensor-split ${lib.escapeShellArg cfg.tensorSplit} \
      ${lib.optionalString (cfg.apiKeyFile != null) ''--api-key "$QWEN_API_KEY"''} \
      ${lib.escapeShellArgs cfg.extraArgs}
  '';
in
{
  options.modules.features.qwenInference = {
    enable = lib.mkEnableOption "Qwen local inference server using llama.cpp";

    package = lib.mkOption {
      type = lib.types.package;
      default = llamaCppCuda;
      description = "CUDA-enabled llama.cpp package used to provide llama-server.";
    };

    modelPath = lib.mkOption {
      type = lib.types.str;
      example = "/var/lib/qwen-inference/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf";
      description = "Absolute path to the GGUF model file.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.3";
      description = "LAN address for llama-server to listen on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8001;
      description = "TCP port for llama-server to listen on.";
    };

    contextLength = lib.mkOption {
      type = lib.types.int;
      default = 16384;
      description = "Context window size in tokens.";
    };

    gpuLayers = lib.mkOption {
      type = lib.types.int;
      default = 999;
      description = "Number of model layers to offload to GPU.";
    };

    tensorSplit = lib.mkOption {
      type = lib.types.str;
      default = "1,1";
      description = "Relative VRAM allocation across CUDA devices.";
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/qwen_api_key";
      description = "Path to an environment file containing QWEN_API_KEY for llama-server API authentication.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional llama-server arguments.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.qwen-inference = {
      isSystemUser = true;
      group = "qwen-inference";
      description = "Qwen llama.cpp inference service";
    };

    users.groups.qwen-inference = { };

    systemd.services.qwen-inference = {
      description = "Qwen local inference server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "qwen-inference";
        Group = "qwen-inference";
        StateDirectory = "qwen-inference";

        EnvironmentFile = lib.mkIf (cfg.apiKeyFile != null) [ cfg.apiKeyFile ];

        ExecStartPre = [
          "${pkgs.coreutils}/bin/test -f ${lib.escapeShellArg cfg.modelPath}"
        ];

        ExecStart = "${startScript}";

        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = "15min";

        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = false;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/qwen-inference" ];

        DeviceAllow = [
          "char-nvidia-uvm rw"
          "char-nvidia rw"
        ];
      };
    };
  };
}
