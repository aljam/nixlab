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
      X11Forwarding = false;
      MaxAuthTries = 3;
      LoginGraceTime = 20;
      MaxSessions = 10;
      MaxStartups = "10:30:60";
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };

    extraConfig = ''
      KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
      Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
      MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
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
