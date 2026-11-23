{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.features.tailscale-health;

  tailscaleHealthExporter = pkgs.writers.writePython3 "tailscale-health-exporter" { } ''
    import json
    import os
    import pathlib
    import subprocess
    import sys


    output = pathlib.Path(os.environ["OUTPUT_FILE"])
    output.parent.mkdir(parents=True, exist_ok=True)

    metrics = [
        "nixlab_tailscale_up 0",
        "nixlab_tailscale_address_configured 0",
        "nixlab_tailscale_peer_count 0",
        "nixlab_tailscale_peer_online 0",
    ]

    try:
        result = subprocess.run(
            [
                "${pkgs.tailscale}/bin/tailscale",
                "status",
                "--json",
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )

        status = json.loads(result.stdout)
        self_peer = status.get("Self") or {}
        peers = status.get("Peer") or {}

        addresses = self_peer.get("TailscaleIPs") or []
        online_peers = sum(
            1
            for peer in peers.values()
            if peer.get("Online")
        )

        metrics = [
            "nixlab_tailscale_up 1",
            f"nixlab_tailscale_address_configured {int(bool(addresses))}",
            f"nixlab_tailscale_peer_count {len(peers)}",
            f"nixlab_tailscale_peer_online {online_peers}",
        ]
    except Exception as error:
        print(
            f"tailscale health export failed: {error}",
            file=sys.stderr,
        )

    output.write_text(
        "\n".join(metrics) + "\n",
        encoding="utf-8",
    )
  '';
in
{
  options.modules.features.tailscale-health = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Export local Tailscale daemon health metrics through node_exporter.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/1";
      description = "systemd calendar interval for refreshing Tailscale metrics.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.tailscale-health-export = {
      description = "Export local Tailscale daemon health metrics";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${tailscaleHealthExporter}";
        Environment = [
          "OUTPUT_FILE=/var/lib/node-exporter/textfile/tailscale-health.prom"
        ];
        User = "node-exporter";
        Group = "node-exporter";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    systemd.timers.tailscale-health-export = {
      description = "Refresh local Tailscale daemon health metrics";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
        RandomizedDelaySec = "15s";
        Unit = "tailscale-health-export.service";
      };
    };

    roles.security.systemdHardenedServices = [
      "tailscale-health-export"
    ];
  };
}
