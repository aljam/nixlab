{
  pkgs,
  lib,
  ...
}:

let
  githubKeyFile = "/run/secrets/github_mcp_token";

  qwenGithub = pkgs.writeShellScriptBin "qwen-github" ''
    if [ -z "''${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ] && [ -r ${githubKeyFile} ]; then
      GITHUB_PERSONAL_ACCESS_TOKEN="$(< ${githubKeyFile})"
      export GITHUB_PERSONAL_ACCESS_TOKEN
    fi

    exec ${pkgs.qwen-code}/bin/qwen "$@"
  '';

  settings = {
    mcpServers.github = {
      command = "${pkgs.docker}/bin/docker";
      args = [
        "run"
        "-i"
        "--rm"
        "-e"
        "GITHUB_PERSONAL_ACCESS_TOKEN"
        "ghcr.io/github/github-mcp-server"
      ];
      env = {
        GITHUB_PERSONAL_ACCESS_TOKEN = "$GITHUB_PERSONAL_ACCESS_TOKEN";
      };
      timeout = 30000;
      trust = false;
    };
  };

  qwenConfig = (pkgs.formats.json { }).generate "settings.json" settings;
in
{
  home.packages = [
    qwenGithub
  ];

  home.file.".qwen/settings.json".source = qwenConfig;
}
