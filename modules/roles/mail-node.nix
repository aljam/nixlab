{
  config,
  pkgs,
  domains,
  lib,
  ...
}:

{
  # Mail secrets remain root-owned until the mail server is activated.
  # They are retained for the eventual mail stack, but the server is disabled
  # because outbound SMTP is blocked by the ISP.
  sops.secrets."smtp_relay_password" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets."mail_password_aljam" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  mailserver = {
    # Eventual feature: outbound SMTP is blocked by the ISP.
    enable = false;

    fqdn = "mail.${domains.primary}";

    domains = lib.attrValues domains;

    loginAccounts = {
      "aljam@${domains.primary}" = {
        hashedPasswordFile = config.sops.secrets."mail_password_aljam".path;

        # Dynamically map 'admin@<domain>' for every domain in your fleet,
        # plus any custom static aliases you want to include!
        aliases = (map (d: "admin@${d}") (lib.attrValues domains)) ++ [
          "@${domains.glow_net}" # Wildcard catch-all for glowrunner.network
        ];
      };
    };

    certificateScheme = "acme-nginx";

    # SENDGRID RELAY (Bypass Bell's Port 25 Block)
    indexSmarthost = true;

    relay = [
      {
        host = "smtp.sendgrid.net";
        port = 587;
        username = "apikey";
        passwordFile = config.sops.secrets."smtp_relay_password".path;
      }
    ];
  };
}
