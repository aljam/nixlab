# SSH access and brute-force protection.
#
# SSH access is group-based: members of `wheel` may log in with public keys.
# Adding a user to `wheel` intentionally grants that user SSH access and
# administrative privileges.
{
  config,
  lib,
  ...
}:

{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      AllowGroups = [ "wheel" ];
    };

    extraConfig = ''
      Match Group wheel
        AuthenticationMethods publickey
    '';
  };

  services.fail2ban = {
    enable = true;
    jails.sshd = {
      enabled = true;
      settings = {
        filter = "sshd";
        port = "ssh";
        logpath = "%(sshd_log)s";
      };
    };
  };

  users.mutableUsers = false;

  assertions = [
    {
      assertion = config.services.openssh.settings.PasswordAuthentication == false;
      message = "SSH password authentication must remain disabled.";
    }
    {
      assertion = config.services.openssh.settings.PermitRootLogin == "no";
      message = "Direct SSH root login must remain disabled.";
    }
    {
      assertion = config.services.openssh.settings.KbdInteractiveAuthentication == false;
      message = "SSH interactive authentication must remain disabled.";
    }
  ];
}
