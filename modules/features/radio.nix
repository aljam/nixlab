{ lib, config, pkgs, ... }:
let
  cfg = config.modules.features.radio;
  liquidsoapScript = config.sops.templates.liquidsoap-radio.path;
  icecastConfig = config.sops.templates.icecast-xml.path;
  icecastHostname = "radio.derezzed.info";
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

    sops.templates.icecast-xml = {
      owner = "icecast";
      group = "icecast";
      mode = "0400";
      content = ''
        <?xml version="1.0"?>
        <icecast>
          <hostname>${icecastHostname}</hostname>

          <authentication>
            <source-password>${config.sops.placeholder.icecast_source_password}</source-password>
            <relay-password>${config.sops.placeholder.icecast_relay_password}</relay-password>
            <admin-user>admin</admin-user>
            <admin-password>${config.sops.placeholder.icecast_admin_password}</admin-password>
          </authentication>

          <paths>
            <logdir>/var/log/icecast</logdir>
            <adminroot>${pkgs.icecast}/share/icecast/admin</adminroot>
            <webroot>${pkgs.icecast}/share/icecast/web</webroot>
            <alias source="/" dest="/status.xsl"/>
          </paths>

          <listen-socket>
            <port>8000</port>
            <bind-address>0.0.0.0</bind-address>
          </listen-socket>

          <security>
            <chroot>0</chroot>
          </security>
        </icecast>
      '';
    };

    services.icecast = {
      enable = true;
      hostname = icecastHostname;
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
        ExecStart = lib.mkForce "${pkgs.icecast}/bin/icecast -c ${icecastConfig}";
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
