{ lib, config, pkgs, ... }:

let
  cfg = config.modules.features.radio;
  liquidsoapScript = config.sops.templates.liquidsoap-radio.path;
in
{
  options.modules.features.radio.enable =
    lib.mkEnableOption "Internet radio streaming stack";

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      icecast-admin-password = {
        sopsFile = ../../secrets/radio.yaml;
        owner = "root";
        group = "root";
        mode = "0400";
        restartUnits = [ "icecast.service" ];
      };

      icecast-source-password = {
        sopsFile = ../../secrets/radio.yaml;
        owner = "root";
        group = "root";
        mode = "0400";
        restartUnits = [ "icecast.service" "liquidsoap-radio.service" ];
      };

      icecast-relay-password = {
        sopsFile = ../../secrets/radio.yaml;
        owner = "root";
        group = "root";
        mode = "0400";
        restartUnits = [ "icecast.service" ];
      };
    };

    services.icecast = {
      enable = true;
      hostname = "radio.derezzed.info";
      admin.password = "unused-by-custom-execstart";
    };

    systemd.services.liquidsoap-radio = {
      description = "Liquidsoap radio stream";
      wantedBy = [ "multi-user.target" ];
      after = [ "sops-nix.service" "icecast.service" ];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        ExecStart = "${pkgs.liquidsoap}/bin/liquidsoap ${liquidsoapScript}";
      };
    };
  };
}
