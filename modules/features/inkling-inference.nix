{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.features.inklingInference;

  # Inkling 2 Mini uses the `inkling2_loop` architecture, which requires
  # llama.cpp b12600 or newer. Pin the upstream flake to a compatible release.
  # The upstream default CUDA 13 toolchain no longer supports the P40's Pascal
  # compute capability 6.1, so use CUDA 12.9, matching the prior Qwen build.
  llamaCppCudaBase = inputs.llama-cpp.packages.x86_64-linux.cuda.override {
    cudaPackages = pkgs.cudaPackages_12_9;
  };

  # The upstream package always builds its bundled web UI, even when
  # `useWebUi` is disabled. Its PWA asset generator attempts to copy a
  # read-only Nix store asset into the build tree and fails in the sandbox.
  # Replace it with an empty output and remove the copy step; the Inkling
  # service needs only the headless llama-server endpoint.
  llamaCppCuda = llamaCppCudaBase.overrideAttrs (old: {
    webui = pkgs.runCommand "llama-cpp-empty-webui" { } "mkdir -p $out";
    postPatch = "";

    # llama.cpp's CUDA backend includes NVML directly. Add the CUDA 12.9 NVML
    # development headers so `ggml-cuda.cu` can find `nvml.h`.
    buildInputs = (old.buildInputs or [ ]) ++ [
      pkgs.cudaPackages_12_9.cuda_nvml_dev
    ];

    # Target the dual Tesla P40 GPUs (Pascal, compute capability 6.1).
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      "-DCMAKE_CUDA_ARCHITECTURES=61"
    ];
  });

  cacheArgs =
    lib.optionals (cfg.cacheTypeK != "f16") [
      "--cache-type-k"
      cfg.cacheTypeK
    ]
    ++ lib.optionals (cfg.cacheTypeV != "f16") [
      "--cache-type-v"
      cfg.cacheTypeV
    ];

  startScript = pkgs.writeShellScript "inkling-inference-start" ''
    exec ${cfg.package}/bin/llama-server \
      --host ${lib.escapeShellArg cfg.host} \
      --port ${toString cfg.port} \
      --model ${lib.escapeShellArg cfg.modelPath} \
      --ctx-size ${toString cfg.contextLength} \
      --n-gpu-layers ${toString cfg.gpuLayers} \
      --split-mode layer \
      --tensor-split ${lib.escapeShellArg cfg.tensorSplit} \
      ${lib.escapeShellArgs cacheArgs} \
      ${lib.optionalString (cfg.apiKeyFile != null) ''--api-key "$INKLING_API_KEY"''} \
      ${lib.escapeShellArgs cfg.extraArgs}
  '';
in
{
  options.modules.features.inklingInference = {
    enable = lib.mkEnableOption "Inkling local inference server using llama.cpp";

    package = lib.mkOption {
      type = lib.types.package;
      default = llamaCppCuda;
      description = "CUDA-enabled llama.cpp package used to provide llama-server.";
    };

    modelPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/inkling-inference/Inkling-2-Mini-Unbound-v3-Q5_K_M.gguf";
      description = "Absolute path to the Inkling GGUF model file.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.3";
      description = "LAN address for llama-server to listen on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8002;
      description = "TCP port for llama-server to listen on.";
    };

    # Start with a context that fits the dual P40 VRAM budget. The 256K
    # context requires more than 42 GiB of compute/KV buffer allocation on a
    # single CUDA device and exceeds a P40's 24 GiB capacity.
    contextLength = lib.mkOption {
      type = lib.types.int;
      default = 32768;
      description = "Context window size in tokens.";
    };

    cacheTypeK = lib.mkOption {
      type = lib.types.str;
      default = "q8_0";
      example = "f16";
      description = "llama.cpp KV cache data type for keys.";
    };

    cacheTypeV = lib.mkOption {
      type = lib.types.str;
      default = "q8_0";
      example = "f16";
      description = "llama.cpp KV cache data type for values.";
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
      default = "/run/secrets/inkling_api_key";
      description = "Path to an environment file containing INKLING_API_KEY for llama-server API authentication.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--parallel"
        "1"
      ];
      description = "Additional llama-server arguments.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.inkling-inference = {
      isSystemUser = true;
      group = "inkling-inference";
      extraGroups = [ "video" ];
      description = "Inkling llama.cpp inference service";
    };

    users.groups.inkling-inference = { };

    sops.secrets.inkling_api_key = lib.mkIf (cfg.apiKeyFile != null) {
      sopsFile = ../../secrets/common.yaml;
      format = "yaml";
      key = "inkling_api_key";
      path = cfg.apiKeyFile;
      owner = "inkling-inference";
      group = "inkling-inference";
      restartUnits = [ "inkling-inference.service" ];
    };

    systemd.services.inkling-inference = {
      description = "Inkling local inference server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "inkling-inference";
        Group = "inkling-inference";
        StateDirectory = "inkling-inference";

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
        ReadWritePaths = [ "/var/lib/inkling-inference" ];

        DeviceAllow = [
          "char-nvidia-uvm rw"
          "char-nvidia rw"
        ];
      };
    };
  };
}
