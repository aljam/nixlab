# SOPS defaults shared by hosts that consume encrypted secrets.
#
# Each feature module declares the specific `sopsFile` it needs. This prevents
# a host from implicitly receiving decryption access to unrelated secrets.
#
# Secret conventions:
# - Every `sops.secrets.<name>` declaration must set an explicit `owner`.
# - Secret files must use `mode = "0400"` unless a service requires otherwise.
# - Set `restartUnits` only for services that can safely reload credentials.
{
  ...
}:

{
  sops.defaultSopsFormat = "yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
}
