{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        addKeysToAgent = true;
      };

      r820 = {
        host = "r820";
        hostname = "192.168.1.4";
        user = "aljam";
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };

      r730 = {
        host = "r730";
        hostname = "192.168.1.3";
        user = "aljam";
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };

      r730xd = {
        host = "r730xd";
        hostname = "192.168.1.2";
        user = "aljam";
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };

      navi = {
        host = "navi";
        hostname = "navi";
        user = "aljam";
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };

      oryx = {
        host = "oryx";
        hostname = "oryx";
        user = "aljam";
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };

      brayd = {
        host = "brayd";
        hostname = "2.25.165.52";
        user = "aljam";
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };

      deploy-navi = {
        host = "deploy-navi";
        hostname = "navi";
        user = "deploy";
        identityFile = "~/.ssh/nixlab_deploy";
        identitiesOnly = true;
      };

      deploy-oryx = {
        host = "deploy-oryx";
        hostname = "oryx";
        user = "deploy";
        identityFile = "~/.ssh/nixlab_deploy";
        identitiesOnly = true;
      };

      deploy-r820 = {
        host = "deploy-r820";
        hostname = "192.168.1.4";
        user = "deploy";
        identityFile = "~/.ssh/nixlab_deploy";
        identitiesOnly = true;
      };

      deploy-r730 = {
        host = "deploy-r730";
        hostname = "192.168.1.3";
        user = "deploy";
        identityFile = "~/.ssh/nixlab_deploy";
        identitiesOnly = true;
      };

      deploy-r730xd = {
        host = "deploy-r730xd";
        hostname = "192.168.1.2";
        user = "deploy";
        identityFile = "~/.ssh/nixlab_deploy";
        identitiesOnly = true;
      };
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
      ExecStart = "${lib.getExe' pkgs.openssh "ssh-agent"} -D -a %t/ssh-agent.socket";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ];
  };

  home.sessionVariables.SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-agent.socket";
}
