# SOPS defaults shared by hosts that consume encrypted secrets.
#
# Each feature module declares the specific `sopsFile` it needs. This prevents
# a host from implicitly receiving decryption access to unrelated secrets.
{
  ...
}:

{
  sops.defaultSopsFormat = "yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
}
