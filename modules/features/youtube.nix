# YouTube subscription downloads.
#
# Exposure model:
# - The bgutil POT provider is bound only to loopback.
# - No secrets are used by this module.
# - Downloads are written to `/mnt/media/youtube` by the shared `media` group.
{
  config,
  pkgs,
  inputs,
  ...
}:
let
  mediaDir = "/mnt/media/youtube";

  potProvider = pkgs.python314Packages.bgutil-ytdlp-pot-provider;
  potSitePackages = "${potProvider}/lib/python3.14/site-packages";
in
{
  imports = [
    ./media-storage.nix
  ];

  environment.systemPackages = with pkgs; [
    ytdl-sub
    yt-dlp
    deno
    potProvider
  ];

  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers.bgutil-pot = {
    image = "docker.io/brainicism/bgutil-ytdlp-pot-provider:latest";
    ports = [
      "127.0.0.1:4416:4416"
    ];
    autoStart = true;
    extraOptions = [ "--init" ];
  };

  systemd.tmpfiles.rules = [
    "d ${mediaDir} 0770 media media -"
  ];

  environment.etc."yt-dlp/plugins/bgutil-ytdlp-pot-provider/yt_dlp_plugins".source =
    "${potSitePackages}/yt_dlp_plugins";

  environment.etc."ytdl-sub/config.yaml".text = ''
    configuration:
      working_directory: "/var/lib/ytdl-sub"

    presets:
      default:
        ytdl_options:
          plugin_dirs:
            - "/etc/yt-dlp/plugins"
          format: "bv*+ba/b"
          live_from_start: true
          js_runtimes:
            deno: {}
          remote_components:
            - "ejs:github"
          extractor_args:
            youtube:
              player_client:
                - "web_embedded"
            youtubepot-bgutilhttp:
              baseurl:
                - "http://127.0.0.1:4416"
          retries: 3
          fragment_retries: 3
          ignoreerrors: true

        output_options:
          output_directory: "${mediaDir}"
          file_name: "{channel}/{upload_date}_{title}.{ext}"
  '';

  environment.etc."ytdl-sub/subscriptions.yaml".text = ''
    igotno_username:
      preset:
        - default
      download:
        url: "https://www.youtube.com/@igotno_username"
  '';

  systemd.services.ytdl-sub = {
    description = "ytdl-sub YouTube automation";

    wants = [
      "network-online.target"
      "podman-bgutil-pot.service"
    ];

    after = [
      "network-online.target"
      "podman-bgutil-pot.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      User = "media";
      Group = "media";
      WorkingDirectory = "/var/lib/ytdl-sub";
      StateDirectory = "ytdl-sub";

      Environment = [
        "PYTHONPATH=${potSitePackages}"
      ];

      ExecStart =
        "${pkgs.ytdl-sub}/bin/ytdl-sub "
        + "--config /etc/ytdl-sub/config.yaml "
        + "sub /etc/ytdl-sub/subscriptions.yaml";

      ReadWritePaths = [
        "/var/lib/ytdl-sub"
        mediaDir
      ];

      TimeoutStartSec = "4h";
    };
  };

  systemd.timers.ytdl-sub = {
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "30min";
      Persistent = true;
    };
  };
}
