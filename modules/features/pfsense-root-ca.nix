{ config, ... }:

{
  # The pfSense root CA is public trust material. Matrix Synapse owns its
  # decrypted copy, while Prometheus reads the same CA for PostgreSQL TLS
  # verification. Mode 0444 permits both service users to read it.
  sops.secrets.pfsense-root-ca = {
    sopsFile = ../../secrets/matrix.yaml;
    owner = "matrix-synapse";
    group = "matrix-synapse";
    mode = "0444";
    restartUnits = [
      "matrix-synapse.service"
      "prometheus.service"
    ];
  };
}
