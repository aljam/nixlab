# Initial regression test: intentionally does not repair missing watch paths
# or enable auditd on behalf of the production module.
{ ... }:
{
  name = "audit-runtime-validation";

  nodes.machine = { pkgs, ... }: {
    imports = [ ../modules/features/audit-logging.nix ];
    environment.systemPackages = [ pkgs.audit ];
    services.openssh.enable = true;
    services.cron.enable = false;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("configured watch targets exist"):
        for path in ["/usr/bin/sudo", "/etc/sudoers", "/etc/sudoers.d/",
                     "/etc/passwd", "/etc/group", "/etc/shadow", "/etc/gshadow",
                     "/etc/ssh/sshd_config", "/etc/ssh/sshd_config.d/", "/etc/audit/"]:
            machine.succeed(f"test -e {path}")

    with subtest("audit collection is running"):
        machine.wait_for_unit("auditd.service", timeout=60)

    with subtest("all baseline watches loaded"):
        rules = machine.succeed("auditctl -l")
        for path, key in [
            ("/usr/bin/sudo", "sudo-execution"),
            ("/etc/sudoers", "sudoers-change"),
            ("/etc/sudoers.d", "sudoers-change"),
            ("/etc/passwd", "identity-change"),
            ("/etc/group", "identity-change"),
            ("/etc/shadow", "identity-change"),
            ("/etc/gshadow", "identity-change"),
            ("/etc/ssh/sshd_config", "sshd-config-change"),
            ("/etc/ssh/sshd_config.d", "sshd-config-change"),
            ("/etc/audit", "audit-config-change"),
        ]:
            assert any(path in line and key in line for line in rules.splitlines()), (path, key, rules)

    with subtest("identity attribute change produces an event"):
        machine.succeed("chmod 0640 /etc/passwd")
        machine.wait_until_succeeds("ausearch -k identity-change -f /etc/passwd -ts boot --raw | grep 'type=SYSCALL'")
        machine.succeed("chmod 0644 /etc/passwd")
  '';
}
