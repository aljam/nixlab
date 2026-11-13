{
  config,
  lib,
  ...
}:
let
  lokiUrl = config.services.nixlab.logShipping.lokiUrl;

  isLoopbackHttp = lib.hasPrefix "http://127.0.0.1" lokiUrl || lib.hasPrefix "http://[::1]" lokiUrl;
  isHttps = lib.hasPrefix "https://" lokiUrl;

  allowedHosts = config.services.nixlab.logShipping.allowedLokiHosts;

  urlHost =
    let
      withoutScheme = lib.removePrefix "http://" (lib.removePrefix "https://" lokiUrl);
      hostPart = lib.head (lib.splitString "/" withoutScheme);
    in
    lib.head (lib.splitString ":" hostPart);

  isAllowedHost = lib.elem urlHost allowedHosts;

  lokiEndpointAllowed = isLoopbackHttp || isHttps || isAllowedHost;
in
{
  options.services.nixlab.logShipping = {
    enable = lib.mkEnableOption "Grafana Alloy systemd-journal log shipping to Loki";

    lokiUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:3100/loki/api/v1/push";
      description = "Loki push API URL used by this host's Alloy agent.";
    };

    allowedLokiHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Explicit hostnames or IP addresses allowed for plaintext HTTP Loki
        push endpoints. HTTPS and loopback HTTP endpoints are always allowed.
      '';
    };
  };

  config = lib.mkIf config.services.nixlab.logShipping.enable {
    # The fleet monitoring server is the intended Loki endpoint.
    services.nixlab.logShipping.allowedLokiHosts = lib.mkDefault [
      config.networking.fleet.${config.networking.monitoringServer}.ip
    ];

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
          The Loki push endpoint must use loopback HTTP, HTTPS, or an
          explicitly allowed Loki host. Configured endpoint: ${lokiUrl}
        '';
      }

      {
        assertion = !(config.roles.server.enable or false) || config.services.nixlab.logShipping.enable;
        message = "Server hosts must enable systemd-journal log shipping to Loki.";
      }
    ];
  };
}
