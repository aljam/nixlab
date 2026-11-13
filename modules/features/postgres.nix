{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.modules.features.postgres;

  postgresAuth = config.services.postgresql.authentication or "";
  postgresPort = config.services.postgresql.settings.port or 5432;
  proxyBackendPorts = config.networking.proxyBackendPorts;

  # Remote PostgreSQL clients must explicitly negotiate TLS. Loopback rules
  # are exempt because their traffic does not traverse a network interface.
  plaintextRemotePostgresRules = lib.filter (
    line:
    let
      trimmed = lib.strings.trim line;
    in
    lib.strings.hasPrefix "host " trimmed
    && !(lib.strings.hasInfix "127.0.0.1/32" trimmed)
    && !(lib.strings.hasInfix "::1/128" trimmed)
  ) (lib.strings.splitString "\n" postgresAuth);
in
{
  imports = [
    ./restic-backup.nix
  ];

  options.modules.features.postgres = {
    enable = lib.mkEnableOption "PostgreSQL server with encrypted LAN access";

    listenAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Specific address on which PostgreSQL listens. When null, PostgreSQL
        listens on all addresses; firewall and pg_hba rules remain required.
      '';
    };

    ensureDatabases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Databases to ensure exist.";
    };

    ensureUsers = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "PostgreSQL role name.";
            };

            ensureDBOwnership = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether the role owns its identically named database.";
            };
          };
        }
      );
      default = [ ];
      description = "PostgreSQL roles to ensure exist.";
    };

    allowedClients = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            database = lib.mkOption {
              type = lib.types.str;
              example = "matrix-synapse";
            };

            user = lib.mkOption {
              type = lib.types.str;
              example = "matrix-synapse";
            };

            address = lib.mkOption {
              type = lib.types.str;
              example = "192.168.1.10/32";
            };
          };
        }
      );
      default = [ ];
      description = "LAN clients allowed to connect over TLS.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;

      ensureDatabases = cfg.ensureDatabases;

      ensureUsers = map (user: { inherit (user) name ensureDBOwnership; }) cfg.ensureUsers;

      settings = {
        listen_addresses =
          if cfg.listenAddress == null then lib.mkForce "*" else lib.mkForce "${cfg.listenAddress},127.0.0.1";
        port = 5432;
        ssl = true;
        ssl_cert_file = "/var/lib/postgresql/tls/server.crt";
        ssl_key_file = "/var/lib/postgresql/tls/server.key";
      };

      authentication = lib.concatMapStringsSep "\n" (
        client: "hostssl ${client.database} ${client.user} ${client.address} scram-sha-256"
      ) cfg.allowedClients;
    };

    systemd.services.postgresql.serviceConfig = {
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/postgresql" ];
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
    };

    systemd.services.postgresql-tls-cert = {
      description = "Generate or rotate the PostgreSQL TLS certificate";
      before = [ "postgresql.service" ];
      requiredBy = [ "postgresql.service" ];
      serviceConfig = {
        Type = "oneshot";
        UMask = "0077";
      };
      script = ''
        certDir=/var/lib/postgresql/tls
        install -d -m 0700 -o postgres -g postgres "$certDir"

        certificate_needs_rotation=false

        if [ ! -s "$certDir/server.key" ] || [ ! -s "$certDir/server.crt" ]; then
          certificate_needs_rotation=true
        else
          expiry_epoch=$(
            ${pkgs.openssl}/bin/openssl x509 \
              -in "$certDir/server.crt" \
              -noout -enddate \
              | cut -d= -f2 \
              | xargs -0 -I{} date -d "{}" +%s
          )
          now_epoch=$(date +%s)

          # Rotate 30 days before expiry.
          if [ "$((expiry_epoch - now_epoch))" -lt "$((30 * 24 * 60 * 60))" ]; then
            certificate_needs_rotation=true
          fi
        fi

        if [ "$certificate_needs_rotation" = true ]; then
          temporary_key="$certDir/server.key.new"
          temporary_cert="$certDir/server.crt.new"

          ${pkgs.openssl}/bin/openssl req -new -x509 -days 365 -nodes \
            -subj "/CN=${config.networking.hostName}.lan" \
            -keyout "$temporary_key" \
            -out "$temporary_cert"

          chown postgres:postgres "$temporary_key" "$temporary_cert"
          chmod 0600 "$temporary_key"
          chmod 0640 "$temporary_cert"

          mv "$temporary_key" "$certDir/server.key"
          mv "$temporary_cert" "$certDir/server.crt"
        fi
      '';
    };

    systemd.timers.postgresql-tls-cert = {
      description = "Rotate the PostgreSQL TLS certificate before expiry";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = "*-*-01 03:00:00";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    # One rule per client address, however many databases it may reach.
    networking.firewall.extraInputRules = lib.concatMapStringsSep "\n" (
      address: "ip saddr ${address} tcp dport 5432 accept"
    ) (lib.unique (map (client: client.address) cfg.allowedClients));

    environment.systemPackages = with pkgs; [
      restic
    ];

    modules.features.restic-backup = {
      enable = true;

      jobs.postgresql = {
        repository = "/var/lib/restic-backup/repo";
        paths = [ "/var/lib/restic-backup/postgresql" ];
        requires = [ "postgresql.service" ];
        after = [ "postgresql.service" ];

        # Only the PostgreSQL backup job needs pg_dump and runuser support.
        runtimePackages = with pkgs; [
          postgresql
        ];

        preBackupScript = ''
          backupRoot=/var/lib/restic-backup
          postgresDumpDir="$backupRoot/postgresql"

          install -d -m 0711 "$backupRoot"
          chown restic-backup:restic-backup "$backupRoot"
          chmod 0711 "$backupRoot"

          install -d -m 0730 "$postgresDumpDir"
          chown postgres:restic-backup "$postgresDumpDir"
          chmod 0730 "$postgresDumpDir"

          # Dump exactly the databases this host declares; the list cannot drift.
          for database in ${lib.escapeShellArgs cfg.ensureDatabases}; do
            dump="$postgresDumpDir/''${database}.dump"
            temporary="''${dump}.tmp"

            runuser -u postgres -- pg_dump --dbname="$database" --format=custom --file="$temporary"
            chown restic-backup:restic-backup "$temporary"
            chmod 0600 "$temporary"
            mv "$temporary" "$dump"
          done
        '';
      };
    };

    assertions = [
      # Prevent regression to broad PostgreSQL authentication rules.
      {
        assertion = !(lib.hasInfix "host all all" postgresAuth);
        message = "PostgreSQL authentication must not contain broad host/all/all rules.";
      }

      # Remote PostgreSQL authentication must explicitly require TLS.
      {
        assertion = plaintextRemotePostgresRules == [ ];
        message = "PostgreSQL authentication must use hostssl for every non-loopback client rule.";
      }

      # PostgreSQL is a sensitive backend service and must not be exposed
      # through the HAProxy backend allowlist.
      {
        assertion = !(lib.elem postgresPort proxyBackendPorts);
        message = "PostgreSQL must not be exposed through the HAProxy backend allowlist.";
      }
    ];
  };
}
