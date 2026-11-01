{ config, ... }:

{
  # Both services need the same public pfSense root CA, but the repository
  # requires SOPS secrets to be owner-only (0400). Decrypt the same source key
  # into separate service-owned secret files.
  sops.secrets = {
    pfsense-root-ca-matrix = {
      key = "pfsense-root-ca";
      sopsFile = ../../secrets/matrix.yaml;
      owner = "matrix-synapse";
      group = "matrix-synapse";
      mode = "0400";
    };

    pfsense-root-ca-prometheus = {
      key = "pfsense-root-ca";
      sopsFile = ../../secrets/matrix.yaml;
      owner = "prometheus";
      group = "prometheus";
      mode = "0400";
    };
  };
}
