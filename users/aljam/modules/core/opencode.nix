{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # Keys are read at launch from root-managed sops files; never enter the Nix store.
  keyFile = "/run/secrets/perplexity_api_key";
  githubKeyFile = "/run/secrets/github_mcp_token";
  qwenKeyFile = "/run/secrets/QWEN_API_KEY";
  inklingKeyFile = "/run/secrets/inkling_api_key";

  loadKey = ''
    if [ -z "''${PERPLEXITY_API_KEY:-}" ] && [ -r ${keyFile} ]; then
      PERPLEXITY_API_KEY="$(< ${keyFile})"
      export PERPLEXITY_API_KEY
    fi

    if [ -z "''${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ] && [ -r ${githubKeyFile} ]; then
      GITHUB_PERSONAL_ACCESS_TOKEN="$(< ${githubKeyFile})"
      export GITHUB_PERSONAL_ACCESS_TOKEN
    fi

    if [ -z "''${QWEN_API_KEY:-}" ] && [ -r ${qwenKeyFile} ]; then
      QWEN_API_KEY="$(< ${qwenKeyFile})"
      export QWEN_API_KEY
    fi

    if [ -z "''${INKLING_API_KEY:-}" ] && [ -r ${inklingKeyFile} ]; then
      INKLING_API_KEY="$(< ${inklingKeyFile})"
      export INKLING_API_KEY
    fi
  '';

  opencode = pkgs.writeShellScriptBin "opencode" ''
    ${loadKey}
    exec ${lib.getExe pkgs.opencode} "$@"
  '';

  desktopPackage = inputs.opencode-desktop.packages.x86_64-linux.default;

  opencodeDesktop = pkgs.writeShellScriptBin "opencode-desktop" ''
    ${loadKey}
    exec ${lib.getExe desktopPackage} "$@"
  '';

  settings = {
    "$schema" = "https://opencode.ai/config.json";

    model = "perplexity-agent/anthropic/claude-sonnet-5-5";

    permission = {
      "*" = "ask";

      bash = {
        "git status *" = "allow";
        "git diff *" = "allow";
        "nix fmt *" = "allow";
        "nix flake check *" = "ask";
        "nixos-rebuild *" = "ask";
        "git commit *" = "ask";
        "git push *" = "deny";
      };
    };

    provider = {
      "perplexity-agent" = {
        npm = "@ai-sdk/open-responses";
        name = "Perplexity Agent API";
        options = {
          name = "perplexity-agent";
          url = "https://api.perplexity.ai/v1/responses";
          apiKey = "{env:PERPLEXITY_API_KEY}";
          headers = {
            "X-Pplx-Integration" = "opencode/1.0";
          };
        };
        models = {
          "anthropic/claude-sonnet-5-5" = {
            name = "Claude Sonnet 5.5";
          };
        };
      };

      "qwen-local" = {
        npm = "@ai-sdk/openai-compatible";
        name = "Qwen Local";
        options = {
          baseURL = "http://192.168.1.3:8001/v1";
          apiKey = "{env:QWEN_API_KEY}";
        };
        models = {
          "qwen3-coder-30b-a3b" = {
            name = "Qwen3 Coder 30B A3B (local)";
          };
        };
      };

      "inkling-local" = {
        npm = "@ai-sdk/openai-compatible";
        name = "Inkling Local";
        options = {
          baseURL = "http://192.168.1.3:8002/v1";
          apiKey = "{env:INKLING_API_KEY}";
        };
        models = {
          "inkling" = {
            name = "Inkling 2 Mini (local)";
          };
        };
      };
    };

    mcp = {
      github = {
        type = "remote";
        url = "https://api.githubcopilot.com/mcp/";
        enabled = true;
        oauth = false;
        headers = {
          "Authorization" = "Bearer {env:GITHUB_PERSONAL_ACCESS_TOKEN}";
        };
      };

      perplexity = {
        type = "local";
        command = [
          "${pkgs.nodejs}/bin/npx"
          "-y"
          "@perplexity-ai/mcp-server"
        ];
        environment.PERPLEXITY_API_KEY = "{env:PERPLEXITY_API_KEY}";
        enabled = false;
      };
    };
  };

  opencodeConfig = (pkgs.formats.json { }).generate "opencode.json" settings;
in
{
  home.packages = [
    (lib.hiPrio opencode)
    (lib.hiPrio opencodeDesktop)
  ];

  xdg.configFile."opencode/opencode.json".source = opencodeConfig;
}
