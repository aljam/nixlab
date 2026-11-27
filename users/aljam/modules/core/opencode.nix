{ pkgs, lib, inputs, ... }:

let
  # Key is read at launch from a root-managed sops file; never enters the Nix store.
  keyFile = "/run/secrets/perplexity_api_key";

  loadKey = ''
    if [ -z "''${PERPLEXITY_API_KEY:-}" ] && [ -r ${keyFile} ]; then
      PERPLEXITY_API_KEY="$(< ${keyFile})"
      export PERPLEXITY_API_KEY
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
      perplexity = {
        type = "local";
        command = [
          "${pkgs.nodejs}/bin/npx"
          "-y"
          "@perplexity-ai/mcp-server"
        ];
        environment.PERPLEXITY_API_KEY = "{env:PERPLEXITY_API_KEY}";
        enabled = true;
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
