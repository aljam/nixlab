{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.ssh = {
    enable = true;

    settings."*".AddKeysToAgent = "yes";

    matchBlocks."192.168.1.*" = {
      identityFile = "~/.ssh/nixlab_deploy";
      identitiesOnly = true;
    };
  };

  systemd.user.services.ssh-agent = {
    Unit = {
      Description = "OpenSSH authentication agent";
      Documentation = [ "man:ssh-agent(1)" ];
    };

    Service = {
      Type = "simple";
      Environment = "SSH_AUTH_SOCK=%t/ssh-agent.socket";
      ExecStart = "${lib.getExe pkgs.openssh}/bin/ssh-agent -D -a %t/ssh-agent.socket";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ];
  };

  home.sessionVariables.SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-agent.socket";
}
