{ config, ... }:

{
  # Matrix Synapse owns its decrypted copy of the public pfSense root CA.
  # Prometheus receives the CA path through its own module option, so the
  # Prometheus module remains usable in SOPS-free test VMs.
  sops.secrets.pfsense-root-ca = {
    sopsFile = ../../secrets/matrix.yaml;
    owner = "matrix-synapse";
    group = "matrix-synapse";
    mode = "0400";
  };
}
