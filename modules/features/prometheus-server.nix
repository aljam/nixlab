{
  config,
  lib,
  ...
}:
{
  services.prometheus.ruleFiles = [
    ./prometheus/rules/prometheus-rules.yml
    ./prometheus/rules/drift-rules.yml
  ];
}
