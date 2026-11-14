{ config, ... }:
{
  # The repository requires SOPS secrets to be owner-only mode 0400.
  # Decrypt separate copies of the same public pfSense root CA for Matrix
  # Synapse and Prometheus so each service can read its own file.
  sops.secrets.pfsense-root-ca-matrix = mkSecret {
    name = "pfsense-root-ca-matrix";
    sopsFile = ../../secrets/matrix.yaml;
    key = "pfsense-root-ca";
    owner = "matrix-synapse";
    group = "matrix-synapse";
    restartUnits = [ "matrix-synapse.service" ];
  };

  sops.secrets.pfsense-root-ca-prometheus = mkSecret {
    name = "pfsense-root-ca-prometheus";
    sopsFile = ../../secrets/matrix.yaml;
    key = "pfsense-root-ca";
    owner = "prometheus";
    group = "prometheus";
    restartUnits = [ "prometheus.service" ];
  };
}
