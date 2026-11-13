{
  config,
  lib,
  ...
}:
let
  lokiUrl = config.services.nixlab.logShipping.lokiUrl;

  isLoopbackHttp = lib.hasPrefix "http://127.0.0.1" lokiUrl || lib.hasPrefix "http://[::1]" lokiUrl;
  isHttps = lib.hasPrefix "https://" lokiUrl;

  privateHttpPrefixes =
    [ "http://10." "http://192.168." ]
    ++ map (n: "http://172.${toString n}.") (lib.range 16 31);

  isPrivateHttp = lib.any (prefix: lib.hasPrefix prefix lokiUrl) privateHttpPrefixes;

  lokiEndpointAllowed = isLoopbackHttp || isHttps || isPrivateHttp;
in
{
  options.services.nixlab.logShipping = {
    enable = lib.mkEnableOption "Grafana Alloy systemd-journal log shipping to Loki";

    lokiUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:3100/loki/api/v1/push";
      description = "Loki push API URL used by this host's Alloy agent.";
    };
  };

  config = lib.mkIf config.services.nixlab.logShipping.enable {
    users.groups.alloy = { };

    users.users.alloy = {
      isSystemUser = true;
      group = "alloy";
      extraGroups = [ "systemd-journal" ];
    };

    services.alloy.enable = true;

    systemd.services.alloy.serviceConfig = {
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
    };

    environment.etc."alloy/config.alloy".text = ''
      loki.source.journal "journal" {
        max_age = "12h"

        labels = {
          job = "systemd-journal",
        }

        relabel_rules = loki.relabel.journal.rules
        forward_to = [loki.write.loki.receiver]
      }

      loki.relabel "journal" {
        forward_to = []

        rule {
          source_labels = ["__journal__hostname"]
          target_label = "host"
        }

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label = "unit"
        }
      }

      loki.write "loki" {
        endpoint {
          url = "${config.services.nixlab.logShipping.lokiUrl}"
        }
      }
    '';

    assertions = [
      {
        assertion = lokiEndpointAllowed;
        message = ''
          The Loki push endpoint must use loopback HTTP, HTTPS, or a private
          RFC 1918 address. Configured endpoint: ${lokiUrl}
        '';
      }

      {
        assertion = !(config.roles.server.enable or false) || config.services.nixlab.logShipping.enable;
        message = "Server hosts must enable systemd-journal log shipping to Loki.";
      }
    ];
  };
}
