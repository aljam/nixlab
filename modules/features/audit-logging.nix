{ config, lib, pkgs, ... }:

{
  services.journald = {
    enable = true;
    persistent = true;

    extraConfig = ''
      Storage=persistent
      MaxRetentionSec=30day
      SystemMaxUse=2G
      Compress=yes
    '';
  };

  security.audit = {
    enable = true;

    rules = [
      # Privilege escalation
      "-w /usr/bin/sudo -p x -k sudo-execution"
      "-w /etc/sudoers -p wa -k sudoers-change"
      "-w /etc/sudoers.d/ -p wa -k sudoers-change"

      # Account and group changes
      "-w /etc/passwd -p wa -k identity-change"
      "-w /etc/group -p wa -k identity-change"
      "-w /etc/shadow -p wa -k identity-change"
      "-w /etc/gshadow -p wa -k identity-change"

      # SSH configuration and keys
      "-w /etc/ssh/sshd_config -p wa -k sshd-config-change"
      "-w /etc/ssh/ -p wa -k ssh-config-change"

      # Audit policy changes
      "-w /etc/audit/ -p wa -k audit-config-change"
      "-w /var/lib/audit/ -p wa -k audit-log-change"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/audit 0750 root root -"
  ];

  assertions = [
    {
      assertion = config.security.audit.enable;
      message = "Audit logging must remain enabled on NixLab hosts.";
    }
  ];
}
