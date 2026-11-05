{ lib, config, pkgs, ... }:
let
  cfg = config.modules.features.radio;
  liquidsoapScript = config.sops.templates.liquidsoap-radio.path;
  icecastRenderedConfig = "/run/icecast/icecast.xml";
  icecastPasswordFile = config.sops.secrets.icecast_source_password.path;
  icecastRenderScript = pkgs.writeShellScript "icecast-render-config" ''
    set -euo pipefail

    config="${pkgs.icecast}/etc/icecast.xml"
    if [ ! -f "$config" ]; then
      echo "Icecast package configuration not found: $config" >&2
      exit 1
    fi

    install -D -m 0600 -o icecast -g icecast \
      "$config" "${icecastRenderedConfig}"

    source_password="$(cat ${icecastPasswordFile})"
    sed -i \
      "s|<source-password>[^<]*</source-password>|<source-password>$source_password</source-password>|" \
      "${icecastRenderedConfig}"
  '';
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
    users.users.icecast = {
      isSystemUser = true;
      group = "icecast";
    };

    users.groups.icecast = { };

    sops.secrets = {
      icecast_admin_password = {
        sopsFile = ../../secrets/radio.yaml;
        owner = "icecast";
        group = "icecast";
        mode = "0400";
        restartUnits = [ "icecast.service" ];
      };

      icecast_source_password = {
        sopsFile = ../../secrets/radio.yaml;
        owner = "icecast";
        group = "icecast";
        mode = "0400";
        restartUnits = [ "icecast.service" "liquidsoap-radio.service" ];
      };

      icecast_relay_password = {
        sopsFile = ../../secrets/radio.yaml;
        owner = "icecast";
        group = "icecast";
        mode = "0400";
        restartUnits = [ "icecast.service" ];
      };
    };

    sops.templates.liquidsoap-radio = {
      content = ''
        radio = fallback([
          playlist("${cfg.musicDir}"),
          blank()
        ])

        output.icecast(
          %mp3(bitrate = 192),
          host = "127.0.0.1",
          port = 8000,
          mount = "stream",
          password = "${config.sops.placeholder.icecast_source_password}",
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
      listen.address = "0.0.0.0";
      admin.password = "unused-by-rendered-icecast-config";
    };

    systemd.services.icecast = {
      serviceConfig = {
        User = lib.mkForce "icecast";
        Group = lib.mkForce "icecast";
        DynamicUser = lib.mkForce false;
        RuntimeDirectory = "icecast";
        RuntimeDirectoryMode = "0700";
        StateDirectory = "icecast";
        LogsDirectory = "icecast";
        ExecStartPre = lib.mkForce "${icecastRenderScript}";
        ExecStart = lib.mkForce "${pkgs.icecast}/bin/icecast -c ${icecastRenderedConfig}";
      };
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
