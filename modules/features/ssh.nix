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
      AllowGroups =
        [ "wheel" ]
        ++ lib.optional config.roles.security.deployUser.enable "deploy";
      X11Forwarding = false;
      MaxAuthTries = 3;
      LoginGraceTime = 20;
      MaxSessions = 10;
      MaxStartups = "10:30:60";
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;

      # These must be set here and not in extraConfig. NixOS writes
      # `settings` (which has its own defaults for all three) before
      # extraConfig, and sshd keeps the first value it reads for a keyword.
      #
      # Curve25519 key exchange, alone or as a post-quantum hybrid.
      KexAlgorithms = [
        "mlkem768x25519-sha256"
        "sntrup761x25519-sha512"
        "sntrup761x25519-sha512@openssh.com"
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
      ];
      # AEAD ciphers only.
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
      ];
      # Encrypt-then-MAC with SHA-2 only.
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
      ];
    };
  };

  services.fail2ban = {
    enable = true;
    jails.sshd = {
      enabled = true;
      settings = {
        filter = "sshd";
        port = "ssh";
        logpath = "%(sshd_log)s";

        # SSH password authentication is disabled, so these limits primarily
        # constrain repeated key probing, connection abuse, and noisy
        # authentication attempts rather than password brute force.
        maxretry = 5;
        findtime = "10m";
        bantime = "1h";
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
