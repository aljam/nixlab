{
  config,
  lib,
  ...
}:

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

    environment.etc."alloy/config.alloy".text = ''
      loki.source.journal "journal" {
        max_age = "12h"

        labels = {
          job = "systemd-journal",
        }

        relabel_rules = loki.relabel.journal.rules

        forward_to = [loki.relabel.journal.receiver]
      }

      loki.relabel "journal" {
        forward_to = [loki.write.loki.receiver]

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
  };
}
