{ config, pkgs, lib, ... }:
{
  services.icecast = {
    enable = true;
    hostname = "radio.derezzed.info";
    admin.password = "changeme-admin";
    extraConfig = ''
      <listen-socket>
        <port>8000</port>
      </listen-socket>

      <authentication>
        <source-password>changeme-source</source-password>
        <relay-password>changeme-relay</relay-password>
      </authentication>
    '';
  };

  systemd.services.icecast = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  services.liquidsoap.streams.radio = ''
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
      port = 8000,
      password = "changeme-source",
      mount = "/stream",
      name = "Derezzed Radio",
      description = "Homelab radio",
      genre = "misc",
      public = false,
      radio
    )
  '';

  systemd.tmpfiles.rules = [
    "d /var/lib/radio/music 0755 liquidsoap liquidsoap -"
  ];

  networking.firewall.allowedTCPPorts = [ 8000 ];
}
