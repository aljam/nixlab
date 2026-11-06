# Fast, VM-free validation of the security baseline for services exposed
# through the pfSense HAProxy gateway.
#
# HAProxy and TLS termination are outside this repository. This check covers
# the Nix-managed application configuration that HAProxy forwards to.
{
  pkgs,
  hosts,
}:

let
  inherit (pkgs) lib;

  isWildcard =
    address:
    lib.elem address [
      "0.0.0.0"
      "::"
    ];

  hostFailures =
    hostname: host:
    let
      cfg = host.config;
      grafana = cfg.services.grafana;
      vaultwarden = cfg.services.vaultwarden;

      grafanaEnabled = grafana.enable or false;
      vaultwardenEnabled = vaultwarden.enable or false;

      grafanaSettings = grafana.settings or { };
      grafanaServer = grafanaSettings.server or { };
      grafanaSecurity = grafanaSettings.security or { };
      grafanaAnonymous = (grafanaSettings."auth.anonymous" or { }).enabled or false;
      grafanaUsers = grafanaSettings.users or { };

      vaultwardenConfig = vaultwarden.config or { };

      grafanaChecks = lib.optionals grafanaEnabled (
        lib.flatten [
          (lib.optional (isWildcard
            grafanaServer.http_addr or ""
          ) "${hostname}: Grafana must not bind to every interface")
          (lib.optional grafanaAnonymous "${hostname}: Grafana must disable anonymous access")
          (lib.optional grafanaUsers.allow_sign_up "${hostname}: Grafana must disable self-registration")
          (lib.optional (
            (grafanaSecurity.admin_user or "") == ""
          ) "${hostname}: Grafana must configure an administrator user")
          (lib.optional (
            (grafanaSecurity.admin_password or "") == ""
          ) "${hostname}: Grafana must configure an administrator password")
          (lib.optional (
            (grafanaSecurity.secret_key or "") == ""
          ) "${hostname}: Grafana must configure a secret key")
        ]
      );

      vaultwardenChecks = lib.optionals vaultwardenEnabled (
        lib.flatten [
          (lib.optional (isWildcard (
            vaultwardenConfig.ROCKET_ADDRESS or ""
          )) "${hostname}: Vaultwarden must not bind to every interface")
          (lib.optional (
            (vaultwardenConfig.SIGNUPS_ALLOWED or "true") == "true"
          ) "${hostname}: Vaultwarden must disable signups")
          (lib.optional (
            (vaultwardenConfig.ADMIN_TOKEN_FILE or "") == ""
          ) "${hostname}: Vaultwarden must configure an admin token file")
          (lib.optional (
            (lib.toInt (vaultwardenConfig.ADMIN_RATELIMIT_SECONDS or "0")) <= 0
          ) "${hostname}: Vaultwarden must configure a positive admin rate-limit interval")
          (lib.optional (
            (lib.toInt (vaultwardenConfig.ADMIN_RATELIMIT_MAX_BURST or "0")) <= 0
          ) "${hostname}: Vaultwarden must configure a positive admin rate-limit burst")
          (lib.optional (
            !(lib.hasPrefix "https://" (vaultwardenConfig.DOMAIN or ""))
          ) "${hostname}: Vaultwarden must use an HTTPS public domain")
        ]
      );
    in
    grafanaChecks ++ vaultwardenChecks;

  failures = lib.flatten (lib.mapAttrsToList hostFailures hosts);

  failureFile = pkgs.writeText "public-service-hardening-failures" (
    lib.concatStringsSep "\n" failures
  );
in
pkgs.runCommand "public-service-hardening"
  {
    inherit failureFile;
  }
  ''
    if [ -s "$failureFile" ]; then
      echo "Public-service hardening checks failed:" >&2
      cat "$failureFile" >&2
      exit 1
    fi

    touch "$out"
  ''
