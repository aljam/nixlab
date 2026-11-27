{ config, lib, ... }:

let
  cfg = config.modules.features.opencodeSecret;
in
{
  options.modules.features.opencodeSecret = {
    enable = lib.mkEnableOption "Perplexity API key secret for OpenCode";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."perplexity_api_key" = {
      sopsFile = ../../secrets/common.yaml;
      format = "yaml";
      key = "perplexity_api_key";
      path = "/run/secrets/perplexity_api_key";
      owner = config.users.users.aljam.name;
      group = config.users.users.aljam.group;
      mode = "0400";
    };
  };
}
