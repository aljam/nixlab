# Controlled automatic security updates.
#
# Hosts periodically evaluate the fleet flake and switch to a new generation,
# but do not reboot automatically. Intentional configuration changes continue
# to use the restricted deployment workflow.
{
  config,
  lib,
  ...
}:

{
  system.autoUpgrade = {
    enable = true;
    flake = "github:Aljam/nixlab";
    dates = "04:00";
    randomizedDelaySec = "30min";
    allowReboot = false;
  };

  assertions = [
    {
      assertion = config.system.autoUpgrade.enable;
      message = "Automatic security updates must remain enabled.";
    }
    {
      assertion = !config.system.autoUpgrade.allowReboot;
      message = "Automatic reboots must remain disabled until explicitly enabled.";
    }
  ];
}
