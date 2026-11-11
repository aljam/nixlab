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
      prometheusServerEnabled = cfg.modules.features.prometheus-server.enable or false;
      scrapeJobs = cfg.services.prometheus.scrapeConfigs or [ ];
      jobNames = map (job: job.job_name or "") scrapeJobs;
      nodeExporterEnabled = cfg.services.prometheus.exporters.node.enable or false;
    in
    {
      inherit
        hostname
        prometheusServerEnabled
        jobNames
        nodeExporterEnabled
        ;
    }
  ) hosts;

  missingScrapeJobs = lib.filter (
    report: report.prometheusServerEnabled && report.jobNames == [ ]
  ) hostReports;

  unscrapedNodeExporters = lib.filter (
    report:
    report.prometheusServerEnabled
    && report.nodeExporterEnabled
    && !lib.any (job: lib.hasInfix "node" job) report.jobNames
  ) hostReports;

  errors =
    map (report: "${report.hostname}: Prometheus is enabled but has no scrape jobs.") missingScrapeJobs
    ++ map (report: "${report.hostname}: node_exporter is enabled but is not scraped.") unscrapedNodeExporters;
in
if errors == [ ] then
  pkgs.runCommand "monitoring-coverage" { } "touch $out"
else
  throw (lib.concatStringsSep "\n" errors)
