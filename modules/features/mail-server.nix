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
  security.acme = {
    acceptTerms = true;
    defaults.email = "aljam@${primaryDomain}";
  };

  mailserver = {
    enable = true;
    stateVersion = 5;
    fqdn = "mail.${primaryDomain}";
    domains = mailDomains;

    loginAccounts = {
      "aljam@${primaryDomain}" = {
        hashedPasswordFile = config.sops.secrets.aljam_password.path;
      };
    };

    extraVirtualAliases = aliases;

    x509.useACMEHost = config.mailserver.fqdn;

    enableImap = true;
    enableImapSsl = true;
    enableSubmission = true;
    enableSubmissionSsl = true;
  };

  services.nginx = {
    enable = true;
    virtualHosts.${config.mailserver.fqdn} = {
      enableACME = true;
    };
  };

  networking.firewall.allowedTCPPorts = [
    25
    587
    993
    80
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
