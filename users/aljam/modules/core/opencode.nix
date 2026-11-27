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

  loadKey = ''
    if [ -z "''${PERPLEXITY_API_KEY:-}" ] && [ -r ${keyFile} ]; then
      PERPLEXITY_API_KEY="$(< ${keyFile})"
      export PERPLEXITY_API_KEY
    fi

    if [ -z "''${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ] && [ -r ${githubKeyFile} ]; then
      GITHUB_PERSONAL_ACCESS_TOKEN="$(< ${githubKeyFile})"
      export GITHUB_PERSONAL_ACCESS_TOKEN
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

    permissions = [
      {
        action = "shell";
        resource = "*";
        effect = "ask";
      }
      {
        action = "shell";
        resource = "git status*";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "git diff*";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "nix fmt*";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "nix flake check*";
        effect = "ask";
      }
      {
        action = "shell";
        resource = "nixos-rebuild*";
        effect = "ask";
      }
      {
        action = "shell";
        resource = "git commit*";
        effect = "ask";
      }
      {
        action = "shell";
        resource = "git push*";
        effect = "deny";
      }
    ];

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
