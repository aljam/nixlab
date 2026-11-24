{ pkgs, ... }:

let
  dashboard = pkgs.writeTextDir "haproxy.json" (
    builtins.readFile ./assets/haproxy.json
  );
in
{
  services.grafana.provision.dashboards.settings.providers = [
    {
      name = "NixLab HAProxy gateway";
      options = {
        path = dashboard;
        foldersFromFilesStructure = false;
      };
    }
  ];
}
