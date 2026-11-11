{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.modules.features.radio;
  liquidsoapScript = config.sops.templates.liquidsoap-radio.path;
  icecastHostname = "radio.${config.networking.myDomain}";
  # Only the local nginx front-end (radio-visualizer) talks to Icecast.
  icecastBind = "127.0.0.1";
in
{
  # Declares the `media` group, which owns the music library.
  imports = [ ./media-storage.nix ];

  options.modules.features.radio = {
    enable = lib.mkEnableOption "Internet radio streaming stack";

    musicDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/media/music";
      description = "Directory containing the radio music library.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.radio = { };

    users.users.icecast = {
      isSystemUser = true;
      group = "radio";
      description = "Icecast streaming server";
    };

    sops.secrets =
      let
        icecastSecret = {
          sopsFile = ../../secrets/radio.yaml;
          owner = "icecast";
          group = "radio";
          mode = "0400";
          restartUnits = [
            "icecast.service"
            "liquidsoap-radio.service"
          ];
        };
      in
      {
        icecast_source_password = icecastSecret;
        icecast_admin_password = icecastSecret;
      };

    sops.templates.liquidsoap-radio = {
      content = ''
        radio = mksafe(playlist("${cfg.musicDir}"))

        output.icecast(
          %mp3(bitrate = 320),
          host = "127.0.0.1",
          port = 8000,
          mount = "stream",
          password = "${config.sops.placeholder.icecast_source_password}",
          radio
        )
      '';
      owner = "icecast";
      group = "radio";
      mode = "0440";
    };

    sops.templates.icecast-xml = {
      owner = "icecast";
      group = "radio";
      mode = "0440";
      content = ''
        <?xml version="1.0"?>
        <icecast>
          <hostname>${icecastHostname}</hostname>

          <authentication>
            <source-password>${config.sops.placeholder.icecast_source_password}</source-password>
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
            <bind-address>${icecastBind}</bind-address>
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
      listen.address = icecastBind;
      # Required by the upstream module, but its generated config is never
      # used: ExecStart below points at the SOPS-rendered icecast-xml instead.
      admin.password = "unused-by-rendered-icecast-config";
    };

    systemd.services.icecast.serviceConfig = {
      LoadCredential = "icecast-xml:${config.sops.templates.icecast-xml.path}";
      ExecStart = lib.mkForce "${pkgs.icecast}/bin/icecast -c \${CREDENTIALS_DIRECTORY}/icecast-xml";
    };

    roles.security.systemdHardenedServices = [ "liquidsoap-radio" ];

    systemd.services.liquidsoap-radio = {
      description = "Liquidsoap radio stream";
      wantedBy = [ "multi-user.target" ];
      after = [
        "sops-nix.service"
        "icecast.service"
      ];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        ExecStart = "${pkgs.liquidsoap}/bin/liquidsoap ${liquidsoapScript}";
        # Liquidsoap decodes every file in the library, so it must not be
        # root. It reads the rendered script (`radio`) and the music
        # (`media`) and sends the stream to Icecast on loopback.
        DynamicUser = true;
        SupplementaryGroups = [
          "radio"
          "media"
        ];
      };
    };
  };
}
