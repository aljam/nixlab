# SSH access and brute-force protection.
#
# The `aljam` user and members of `wheel` may log in with public keys.
# These allowlists are OR-ed by OpenSSH, so adding a user to `wheel`
# intentionally grants that user SSH access.
{
  ...
}:

{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      AllowUsers = [ "aljam" ];
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
}
