{ config, pkgs, domains, lib, ... }:

{
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
    enable = true;
    
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
