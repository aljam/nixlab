{
  config,
  lib,
  ...
}:
{
  options.services.nixlab.promtail = {
    enable = lib.mkEnableOption "Promtail systemd-journal log shipping";

    lokiUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:3100/loki/api/v1/push";
      description = "Loki push API URL used by this host's Promtail agent.";
    };
  };

  config = lib.mkIf config.services.nixlab.promtail.enable {
    users.users.promtail.extraGroups = [ "systemd-journal" ];

    services.promtail = {
      enable = true;

      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };

        positions.filename = "/var/lib/promtail/positions.yaml";

        clients = [
          { url = config.services.nixlab.promtail.lokiUrl; }
        ];

        scrape_configs = [
          {
            job_name = "systemd-journal";

            journal = {
              max_age = "12h";
              labels.job = "systemd-journal";
            };

            relabel_configs = [
              {
                source_labels = [ "__journal__hostname" ];
                target_label = "host";
              }
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
        ];
      };
    };
  };
}
