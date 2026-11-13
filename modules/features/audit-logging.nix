# Preserve security-relevant events across reboots while bounding local
# journal growth.
#
# Kernel audit events are collected by auditd; the persistent systemd journal
# retains them locally for operational investigation. Loki provides the
# fleet-wide, retention-managed log store.
{
  config,
  lib,
  ...
}:

{
  security.audit.enable = true;
  security.auditd.enable = true;

  services.journald.persistent = true;
  services.journald.extraConfig = ''
    SystemMaxUse=2G
    KeepFree=1G
    MaxRetentionSec=30day
  '';

  assertions = [
    {
      assertion = config.security.audit.enable;
      message = "Kernel audit events must remain enabled.";
    }
    {
      assertion = config.services.journald.persistent;
      message = "The systemd journal must persist across reboots.";
    }
  ];
}
