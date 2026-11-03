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

    certs."mail.${primaryDomain}" = {
      dnsProvider = "cloudflare";
      environmentFile = config.sops.templates."cloudflare-acme-env".path;
    };
  };

  mailserver = {
    enable = true;
    stateVersion = 5;
    localDnsResolver = false;
    fqdn = "mail.${primaryDomain}";
    domains = mailDomains;

    accounts = {
      "aljam@${primaryDomain}" = {
        hashedPasswordFile = config.sops.secrets.aljam_password.path;
      };
    };

    aliases = aliases;

    x509.useACMEHost = "mail.${primaryDomain}";

    enableImap = true;
    enableImapSsl = true;
    enableSubmission = true;
    enableSubmissionSsl = true;
  };

  sops.secrets."cloudflare-api-token" = {
    sopsFile = ../../secrets/acme.yaml;
    owner = "acme";
    group = "acme";
    mode = "0400";
  };

  sops.templates."cloudflare-acme-env" = {
    content = "CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder."cloudflare-api-token"}";
    owner = "acme";
    group = "acme";
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
