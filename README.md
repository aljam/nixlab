# Nixlab

Nixlab is a declarative, reproducible, GitOps-driven multi-machine homelab infrastructure managed entirely via a unified Nix flake.

## Services

| Area | Services |
|---|---|
| Media | Jellyfin, Seerr, PeerTube |
| Downloads | Sonarr, Radarr, Prowlarr, Bazarr, Lidarr, qBittorrent, Autobrr, Recyclarr |
| Identity / communication | Vaultwarden, Matrix Synapse, Matrix RTC |
| Monitoring | Prometheus, Grafana, Alertmanager, node_exporter, Blackbox exporter |

## Hosts

| Host | Role |
|---|---|
| `navi` | Desktop |
| `oryx` | Desktop |
| `r820` | Server |
| `r730` | Server |
| `r730xd` | Server |

## Deployment

Deployments are performed through the `deploy` app:

```bash
nix run .#deploy -- [host ...]
```

The deploy app refuses to run from a dirty Git working tree, requires a full commit SHA, verifies that `HEAD` matches `origin/main`, runs `nix flake check`, and deploys only the declared hosts.

## Deployment Plan

Before deploying, preview the revision and hosts that `deploy` would target:

```bash
nix run .#deploy-plan
```

To plan a specific host:

```bash
nix run .#deploy-plan -- r820
```

The `deploy-plan` app applies the same repository and revision guards as `deploy`, runs `nix flake check`, and prints the selected hosts. It does not connect to hosts or run `deploy-rebuild switch`.

## Documentation

- `docs/ARCHITECTURE.md`
- `docs/DEPLOYMENT.md`
- `docs/NETWORKING.md`
- `docs/SECURITY.md`
- `docs/RECOVERY.md`
- `docs/PUBLIC_SERVICES.md`
- `docs/AUTHENTICATION.md`
