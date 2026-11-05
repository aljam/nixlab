{ config, pkgs, lib, ... }:
let
  icecastPort = 8000;

  icecastConfig = config.sops.templates.icecast-config.path;
  liquidsoapScript = config.sops.templates.liquidsoap-radio.path;
in
{
  sops.secrets = {
    icecast-admin-password = {
      sopsFile = ../../secrets/radio.yaml;
      owner = "root";
      group = "keys";
      mode = "0400";
    };

    icecast-source-password = {
      sopsFile = ../../secrets/radio.yaml;
      owner = "root";
      group = "keys";
      mode = "0400";
    };

    icecast-relay-password = {
      sopsFile = ../../secrets/radio.yaml;
      owner = "root";
      group = "keys";
      mode = "0400";
    };
  };

  sops.templates = {
    icecast-config = {
      content = ''
        <?xml version="1.0"?>
        <icecast>
          <hostname>radio.derezzed.info</hostname>

          <authentication>
            <admin-user>admin</admin-user>
            <admin-password>${config.sops.placeholder.icecast-admin-password}</admin-password>
          </authentication>

          <paths>
            <logdir>/var/log/icecast</logdir>
            <adminroot>${pkgs.icecast}/share/icecast/admin</adminroot>
            <webroot>${pkgs.icecast}/share/icecast/web</webroot>
            <alias source="/" dest="/status.xsl"/>
          </paths>

          <listen-socket>
            <port>${toString icecastPort}</port>
            <bind-address>::</bind-address>
          </listen-socket>

          <security>
            <chroot>0</chroot>
          </security>

          <authentication>
            <source-password>${config.sops.placeholder.icecast-source-password}</source-password>
            <relay-password>${config.sops.placeholder.icecast-relay-password}</relay-password>
          </authentication>
        </icecast>
      '';
      owner = "root";
      group = "keys";
      mode = "0440";
    };

    liquidsoap-radio = {
      content = ''
        set("log.file", false)
        set("log.stdout", true)

        music = playlist("/var/lib/radio/music")

        radio = fallback([
          request.queue(id = "requests"),
          music
        ])

        output.icecast(
          %mp3(bitrate = 192, samplerate = 44100, stereo = true),
          host = "127.0.0.1",
          port = ${toString icecastPort},
          password = "${config.sops.placeholder.icecast-source-password}",
          mount = "/stream",
          name = "Derezzed Radio",
          description = "Homelab radio",
          genre = "misc",
          public = false,
          radio
        )
      '';
      owner = "liquidsoap";
      group = "liquidsoap";
      mode = "0400";
    };
  };

  services.icecast = {
    enable = true;
    hostname = "radio.derezzed.info";
  };

  systemd.services.icecast = {
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "sops-nix.service"
    ];

    serviceConfig = {
      SupplementaryGroups = [ "keys" ];
      ExecStart = lib.mkForce (
        lib.concatStringsSep " " [
          (lib.getExe pkgs.icecast)
          "-c"
          icecastConfig
        ]
      );
    };
  };

  services.liquidsoap.streams.radio = liquidsoapScript;

  systemd.tmpfiles.rules = [
    "d /var/lib/radio/music 0755 liquidsoap liquidsoap -"
  ];

  networking.firewall.allowedTCPPorts = [ icecastPort ];
}
