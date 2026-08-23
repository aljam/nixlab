# modules/features/grafana.nix
{ config, lib, pkgs, ... }:

let
  bindAddr = config.servicesHostIP or "127.0.0.1";
in
{
  sops.secrets."grafana-admin-password" = {
    owner = "grafana";
    group = "grafana";
    mode = "0640";
  };

  sops.secrets."grafana-secret-key" = {
    owner = "grafana";
    group = "grafana";
    mode = "0640";
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = bindAddr;
        http_port = 3000;
      };
      security = {
        admin_password = "$__file{/run/secrets/grafana-admin-password}";
        secret_key = "$__file{/run/secrets/grafana-secret-key}";
      };
    };
  };

  networking.proxyBackendPorts = [ 3000 ];

  # Fix: Ensure data directory ownership on activation
  system.activationScripts.grafana-data-dir.text = ''
    ${pkgs.coreutils}/bin/chown grafana:grafana /var/lib/grafana
    ${pkgs.coreutils}/bin/chmod 755 /var/lib/grafana
  '';
}
