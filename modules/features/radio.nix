{ lib, config, pkgs, ... }:
let
  cfg = config.modules.features.radio;
  liquidsoapScript = config.sops.templates.liquidsoap-radio.path;
in
{
  options.modules.features.radio = {
    enable = lib.mkEnableOption "Internet radio streaming stack";

    musicDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/media/music";
      description = "Directory containing the radio music library.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      icecast_admin_password = {
        sopsFile = ../../secrets/radio.yaml;
        owner = "root";
        group = "root";
        mode = "0400";
        restartUnits = [ "icecast.service" ];
      };

      icecast_source_password = {
        sopsFile = ../../secrets/radio.yaml;
        owner = "root";
        group = "root";
        mode = "0400";
        restartUnits = [ "icecast.service" "liquidsoap-radio.service" ];
      };

      icecast_relay_password = {
        sopsFile = ../../secrets/radio.yaml;
        owner = "root";
        group = "root";
        mode = "0400";
        restartUnits = [ "icecast.service" ];
      };
    };

    sops.templates.liquidsoap-radio = {
      content = ''
        radio = playlist("${cfg.musicDir}")

        output.icecast(
          %mp3(bitrate = 192),
          host = "127.0.0.1",
          port = 8000,
          mount = "stream",
          password = "${config.sops.secrets.icecast_source_password.path}",
          radio
        )
      '';
      owner = "root";
      group = "root";
      mode = "0400";
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
