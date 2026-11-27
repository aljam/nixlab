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
  llamaCppCuda = pkgs.llama-cpp.override {
    cudaSupport = true;
  };
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
      default = "127.0.0.1";
      description = "Address for llama-server to listen on.";
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

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional llama-server arguments.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.qwen-inference = {
      description = "Qwen local inference server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        StateDirectory = "qwen-inference";
        ExecStart = lib.escapeShellArgs (
          [
            "${lib.getExe cfg.package}"
            "--host"
            cfg.host
            "--port"
            (toString cfg.port)
            "--model"
            cfg.modelPath
            "--ctx-size"
            (toString cfg.contextLength)
            "--n-gpu-layers"
            (toString cfg.gpuLayers)
            "--split-mode"
            "layer"
            "--tensor-split"
            cfg.tensorSplit
          ]
          ++ cfg.extraArgs
        );
        Restart = "on-failure";
        RestartSec = "5s";

        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = false;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/qwen-inference" ];
      };
    };
  };
}
