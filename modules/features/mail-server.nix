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

  acmeService = "acme-order-renew-mail.${primaryDomain}";
  tokenFile = config.sops.secrets."cloudflare-api-token".path;
in
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "aljam@${primaryDomain}";

    certs."mail.${primaryDomain}" = {
      dnsProvider = "cloudflare";
      environmentFile = config.sops.secrets."CLOUDFLARE_DNS_API_TOKEN".path;
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

  sops.secrets."CLOUDFLARE_DNS_API_TOKEN" = {
    sopsFile = ../../secrets/acme.yaml;
    owner = "acme";
    group = "acme";
    mode = "0400";
  };

  systemd.services.${acmeService} = {
    preStart = ''
      install -d -m 0700 -o acme -g acme /run/cloudflare-acme
      token="$(sed -n 's/^cloudflare-api-token=//p' ${tokenFile})"
      printf '%s\n' "CLOUDFLARE_DNS_API_TOKEN=$token" > /run/cloudflare-acme/environment
      chown acme:acme /run/cloudflare-acme/environment
      chmod 0400 /run/cloudflare-acme/environment
    '';
    serviceConfig = {
      RuntimeDirectory = "cloudflare-acme";
      RuntimeDirectoryMode = "0700";
    };
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
