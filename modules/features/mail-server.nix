{ config, lib, ... }:

let
  primaryDomain = "derezzed.info";
  mailDomains = [
    primaryDomain
    "fuwa.space"
    "cybal.org"
    "netrunner.dev"
    "glowrunner.network"
    "glowrunner.dev"
    "glowrunner.xyz"
  ];

  roleAliases = [
    "postmaster"
    "abuse"
    "webmaster"
  ];

  aliases = lib.listToAttrs (
    lib.concatMap (
      domain:
      map (name: {
        name = "${name}@${domain}";
        value = "aljam@${primaryDomain}";
      }) roleAliases
    ) mailDomains
  );
in
{
  mailserver = {
    enable = true;
    fqdn = "mail.${primaryDomain}";
    domains = mailDomains;

    loginAccounts = {
      "aljam@${primaryDomain}" = {
        hashedPasswordFile = config.sops.secrets.aljam_password.path;
      };
    };

    extraVirtualAliases = aliases;

    certificateScheme = "acme";

    enableImap = true;
    enableImapSsl = true;
    enableSubmission = true;
    enableSubmissionSsl = true;
  };

  services.postfix = {
    mapFiles.sasl_passwd = config.sops.secrets."mail/postfix-sasl-passwd".path;

    extraConfig = ''
      smtp_sasl_auth_enable = yes
      smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
      smtp_sasl_security_options = noanonymous
      smtp_sasl_tls_security_options = noanonymous
      smtp_tls_security_level = encrypt
      relayhost = [smtp-pulse.com]:587
    '';
  };

  sops.secrets."mail/postfix-sasl-passwd" = {
    sopsFile = ../../secrets/mail.yaml;
    owner = config.services.postfix.user;
    group = config.services.postfix.group;
    mode = "0400";
  };

  networking.firewall.allowedTCPPorts = [
    25
    587
    993
  ];

  assertions = [
    {
      assertion = !(lib.elem 25 config.networking.proxyBackendPorts);
      message = "SMTP port 25 must not be exposed through the HAProxy backend allowlist.";
    }
    {
      assertion = !(lib.elem 587 config.networking.proxyBackendPorts);
      message = "Mail submission port 587 must not be exposed through the HAProxy backend allowlist.";
    }
    {
      assertion = !(lib.elem 993 config.networking.proxyBackendPorts);
      message = "IMAPS port 993 must not be exposed through the HAProxy backend allowlist.";
    }
  ];
}
