{ pkgs, lib, ... }:

let
  # Key is read at launch from a root-managed sops file; never enters the Nix store.
  keyFile = "/run/secrets/perplexity_api_key";

  opencode = pkgs.writeShellScriptBin "opencode" ''
    if [ -z "''${PERPLEXITY_API_KEY:-}" ] && [ -r ${keyFile} ]; then
      PERPLEXITY_API_KEY="$(< ${keyFile})"
      export PERPLEXITY_API_KEY
    fi
    exec ${lib.getExe pkgs.opencode} "$@"
  '';

  settings = {
    "$schema" = "https://opencode.ai/config.json";
    mcp.perplexity = {
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

  opencodeConfig = (pkgs.formats.json { }).generate "opencode.json" settings;
in
{
  home.packages = [ (lib.hiPrio opencode) ];

  xdg.configFile."opencode/opencode.json".source = opencodeConfig;
}
