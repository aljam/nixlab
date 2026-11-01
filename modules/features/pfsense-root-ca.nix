{ config, ... }:

{
  # The pfSense root CA is public certificate material, so it can be
  # world-readable. Declaring it once avoids conflicting SOPS secret owners
  # between Matrix Synapse and Prometheus.
  sops.secrets.pfsense-root-ca = {
    sopsFile = ../../secrets/matrix.yaml;
    owner = "root";
    group = "root";
    mode = "0444";
  };
}
