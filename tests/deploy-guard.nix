{
  pkgs,
  deployScript,
}:

pkgs.runCommand "deploy-guard" { } ''
  set -euo pipefail

  grep -F 'Refusing to deploy: Git working tree is dirty.' '${deployScript}' >/dev/null
  grep -F 'Refusing to deploy: unable to resolve a full commit SHA.' '${deployScript}' >/dev/null
  grep -F 'is not the tip of origin/main' '${deployScript}' >/dev/null
  grep -F 'deploy-rebuild switch' '${deployScript}' >/dev/null

  touch "$out"
''
