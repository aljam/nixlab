# SSH access and brute-force protection.
#
# Only the `aljam` user may log in, and only with a public key.
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
