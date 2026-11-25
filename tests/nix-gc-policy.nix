{ ... }:
{
  name = "nix-gc-policy";

  nodes = {
    configured =
      { ... }:
      {
        imports = [ ../modules/features/nix-gc ];

        modules.features.nix-gc = {
          enable = true;
          schedule = "Sun 03:00";
          retention = {
            generations = 4;
            age = "14 days";
          };
        };
      };

    disabled =
      { ... }:
      {
        imports = [ ../modules/features/nix-gc ];
      };
  };

  testScript = ''
    start_all()

    with subtest("automatic Nix GC is disabled by default"):
        disabled.fail("systemctl cat nixlab-nix-gc.timer")
        disabled.fail("systemctl cat nixlab-nix-gc.service")

    with subtest("enabled GC has a schedule and retention policy"):
        configured.succeed("systemctl cat nixlab-nix-gc.service")
        configured.succeed("systemctl cat nixlab-nix-gc.timer")
        configured.succeed(
            "systemctl cat nixlab-nix-gc.timer | grep -q 'OnCalendar=Sun 03:00'"
        )

    with subtest("GC service is one-shot, root-owned, and hardened"):
        configured.succeed(
            "systemctl show nixlab-nix-gc.service --property=Type | grep -q 'Type=oneshot'"
        )
        configured.succeed(
            "systemctl show nixlab-nix-gc.service --property=User | grep -q 'User=root'"
        )
        configured.succeed(
            "systemctl show nixlab-nix-gc.service --property=NoNewPrivileges | grep -q 'NoNewPrivileges=yes'"
        )
        configured.succeed(
            "systemctl show nixlab-nix-gc.service --property=ProtectSystem | grep -q 'ProtectSystem=strict'"
        )

    with subtest("GC timer is persistent and randomized"):
        configured.succeed(
            "systemctl show nixlab-nix-gc.timer --property=Persistent | grep -q 'Persistent=yes'"
        )
        configured.succeed(
            "systemctl show nixlab-nix-gc.timer --property=RandomizedDelayUSec | grep -q 'RandomizedDelayUSec=15min'"
        )
  '';
}
