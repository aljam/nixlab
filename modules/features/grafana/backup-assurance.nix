{ pkgs, ... }:

let
  dashboard = pkgs.writeTextDir "backup-assurance.json" (
    builtins.readFile ./assets/backup-assurance.json
  );
in
{
  services.grafana.provision.dashboards.settings.providers = [
    {
      name = "NixLab backup assurance";
      options = {
        path = dashboard;
        foldersFromFilesStructure = false;
      };
    }
  ];
}
