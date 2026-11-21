# Deployment

Nixlab deployments are revision-pinned and performed through flake apps.

## Plan a deployment

Preview the revision and hosts that would be deployed:

```bash
nix run .#deploy-plan
```

Plan one or more specific hosts:

```bash
nix run .#deploy-plan -- r820
nix run .#deploy-plan -- r730 r730xd
```

`deploy-plan` validates the repository and revision, runs `nix flake check`, and prints the target hosts. It does not connect to hosts or switch configurations.

## Check deployment status

Check whether deploy hosts are running the current `origin/main` revision:

```bash
nix run .#deploy-status
```

Check one or more specific hosts:

```bash
nix run .#deploy-status -- r820
nix run .#deploy-status -- r730 r730xd
```

`deploy-status` connects to each selected host to read its active configuration revision. It reports `up-to-date`, `out-of-date`, or `unknown`, but does not switch, upgrade, or reboot hosts.

## Deploy

Deploy the current `origin/main` revision to all configured deploy hosts:

```bash
nix run .#deploy
```

Deploy one or more specific hosts:

```bash
nix run .#deploy -- r820
nix run .#deploy -- r730 r730xd
```

The deploy app refuses a dirty working tree, requires a full commit SHA, verifies that `HEAD` matches `origin/main`, runs `nix flake check`, and then deploys the selected hosts.
