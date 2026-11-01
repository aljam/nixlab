# PostgreSQL and pgAdmin.
#
# Exposure model:
# - PostgreSQL listens only on loopback and this host's fleet service address.
# - pgAdmin listens only on loopback and is intentionally not added to
#   `networking.proxyBackendPorts`. Expose it through an authenticated,
#   admin-only route only if explicitly needed.
# - TCP database authentication is limited to explicit database/user pairs.
# - The firewall permits only the Matrix Synapse host to reach PostgreSQL.
{
  config,
  pkgs,
  lib,
  ...}:

{
  sops.secrets.pgadmin_password = {
    sopsFile = ../../secrets/database.yaml;
    owner = "pgadmin";
  };

  services.postgresql = {
    enable = true;
    enableTCPIP = true;

    settings = {
      listen_addresses = lib.mkForce (
        lib.concatStringsSep "," [
          "127.0.0.1"
          config.networking.servicesBindAddress
        ]
      );

      password_encryption = "scram-sha-256";
    };

    authentication = lib.mkOverride 10 '''
      local all all peer

      # Keep TCP rules narrow: each rule names both the database and role.
      host webscraper webscraper 127.0.0.1/32 scram-sha-256
      host admin admin 127.0.0.1/32 scram-sha-256
      host matrix-synapse matrix-synapse 127.0.0.1/32 scram-sha-256
      host matrix-synapse matrix-synapse ${config.networking.fleet.r730xd.ip}/32 scram-sha-256
    ''';

    ensureDatabases = [
      "webscraper"
      "admin"
      "matrix-synapse"
    ];

    ensureUsers = [
      {
        name = "webscraper";
        ensureDBOwnership = true;
      }
      {
        name = "admin";
        ensureDBOwnership = true;
      }
      {
        name = "matrix-synapse";
        ensureDBOwnership = true;
      }
    ];
  };

  # Matrix Synapse runs on r730xd and connects to this PostgreSQL instance.
  # Permit only that host; pg_hba still enforces the database/user pair and
  # SCRAM authentication.
  networking.firewall.extraInputRules = '''
    ip saddr ${config.networking.fleet.r730xd.ip} tcp dport 5432 accept comment "Matrix Synapse PostgreSQL"
  ''';

  services.pgadmin = {
    enable = true;
    initialEmail = "admin@derezzed.info";
    initialPasswordFile = config.sops.secrets.pgadmin_password.path;
    port = 5050;
    settings.DEFAULT_SERVER = "127.0.0.1";
  };
}
