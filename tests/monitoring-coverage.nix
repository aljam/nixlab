{
  pkgs,
  hosts,
}:
let
  inherit (pkgs) lib;

  hostReports = lib.mapAttrsToList (
    hostname: host:
    let
      cfg = host.config;
      prometheusEnabled = cfg.services.prometheus.enable or false;
      scrapeJobs = cfg.services.prometheus.scrapeConfigs or [ ];
      jobNames = map (job: job.job_name or "") scrapeJobs;
      nodeExporterEnabled = cfg.services.prometheus.exporters.node.enable or false;
    in
    {
      inherit hostname prometheusEnabled jobNames nodeExporterEnabled;
    }
  ) hosts;

  errors =
    lib.concatMap
      (
        report:
        lib.optionals report.prometheusEnabled (
          lib.optional (report.jobNames == [ ])
            "${report.hostname}: Prometheus is enabled but has no scrape jobs."
          ++ lib.optionals report.nodeExporterEnabled (
            lib.optional
              (!lib.any (job: lib.hasInfix "node" job) report.jobNames)
              "${report.hostname}: node_exporter is enabled but is not scraped."
          )
        )
      )
      hostReports;
in
pkgs.runCommand "monitoring-coverage"
  {
    passAsFile = [ "report" ];
    report = lib.generators.toPretty { } hostReports;
  }
  (
    if errors == [ ] then
      ''
        echo "Monitoring coverage check passed."
        echo "$report" > "$out"
      ''
    else
      ''
        echo "Monitoring coverage check failed:" >&2
        ${lib.concatMapStringsSep "\n" (error: ''echo "- ${error}" >&2'') errors}
        exit 1
      ''
  )
