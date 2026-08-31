# Networking

This document describes the network topology, subnets, and firewall rules for nixlab.

## Topology

```
                    ┌─────────────┐
                    │   Internet  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   pfSense   │  192.168.1.1
                    │  (HAProxy)  │  ───────────────┐
                    └──────┬──────┘                 │ (reverse proxy)
                           │                        │
              ┌────────────┼────────────────────────┤
              │            │                        │
       ┌──────▼──────┐ ┌───▼────┐          ┌───────▼────────┐
       │    r820     │ │  r730  │          │     r730xd     │
       │  Edge       │ │ ZFS    │          │   Media/Apps   │
       │  Backends   │ │ PG     │          │ Jellyfin, VW   │
       │  Grafana    │ │ Build  │          │ Prometheus     │
       └─────────────┘ └────────┘          └────────────────┘
              │
       ┌──────┴──────┐
       │             │
  ┌────▼────┐  ┌─────▼────┐
  │  navi   │  │   oryx   │
  │ Desktop │  │  Laptop  │
  └─────────┘  └──────────┘

NAS: 192.168.2.10 (separate subnet, CIFS mount)
```

## Subnets

| Network | Subnet | Purpose |
|---------|--------|---------|
| LAN | 192.168.1.0/24 | All servers and desktops |
| NAS | 192.168.2.0/24 | CIFS storage (192.168.2.10) |

### Host IPs (DHCP static leases on pfSense)

| Host | IP | Role |
|------|----|------|
| pfSense | 192.168.1.1 | Gateway, DNS, HAProxy |
| r730 | 192.168.1.x | ZFS storage, PostgreSQL, remote builder |
| r730xd | 192.168.1.x | Media (Jellyfin, servarr), Vaultwarden, Prometheus |
| r820 | 192.168.1.x | Reverse proxy backends, Grafana |
| navi | 192.168.1.x | Desktop |
| oryx | 192.168.1.x | Laptop |
| NAS | 192.168.2.10 | CIFS storage |

## Firewall Rules

### pfSense / HAProxy

HAProxy runs on pfSense (192.168.1.1) and proxies:

- `media.<domain>` → Jellyfin (r730xd:8096)
- `vaultwarden.<domain>` → Vaultwarden (r730xd:8222)
- `grafana.<domain>` → Grafana (r820:3000)
- `homepage.<domain>` → Homepage (r730xd:8080)
- `prometheus.<domain>` → Prometheus (r730xd:9090)

Backend health checks ensure services are available before routing traffic.

### nftables (per-host)

Each server runs nftables via NixOS `networking.firewall`:

- **Allowed input**: SSH (22), service-specific ports (e.g., 8096 for Jellyfin, 8222 for Vaultwarden, 9090 for Prometheus, 3000 for Grafana)
- **Default policy**: Drop unmatched inbound traffic
- **LAN access**: Services are reachable from LAN but not exposed externally (HAProxy handles external)

### Security Properties

The `tests/firewall.nix` test enforces:

1. **qBittorrent WebUI** (port 8080) is not reachable from LAN hosts
2. **Vaultwarden** (port 8222) is not reachable from LAN hosts  
3. **node-exporter** (port 9100) is only reachable from r730xd (Prometheus host)

Run the test with:

```bash
nix build .#checks.x86_64-linux.firewall
```

## Monitoring Network Flow

- **Prometheus** (r730xd:9090) scrapes:
  - node-exporter on all hosts (9100)
  - Blackbox exporter for external probes
  - Service metrics (Jellyfin, Vaultwarden, PostgreSQL)

- **Grafana** (r820:3000) visualizes Prometheus data

- **Alertmanager** sends notifications via configured routes

## DNS

Internal DNS is provided by pfSense (192.168.1.1). Hosts are registered via DHCP static leases.

## Troubleshooting

### Check Firewall Rules

```bash
# List nftables ruleset
sudo nft list ruleset

# Check allowed ports
sudo nft list table inet filter
```

### Test Port Reachability

```bash
# From another host (LAN)
nc -zv <host> <port>

# Check listening services
ss -tlnp | grep <port>

# Test HAProxy backend
 curl -v http://<host>:<port>/health
```

### HAProxy Debug (on pfSense)

```bash
# Check HAProxy status (pfSense web UI or SSH)
# Status page: https://192.168.1.1/haproxy/haproxy_listeners.php
# Logs: System > Logs > HAProxy
```

### Prometheus Debug

```bash
# Check scrape targets
 curl http://localhost:9090/api/v1/targets

# View logs
journalctl -u prometheus -f
```

### NAS Mount Issues

```bash
# Check CIFS mount
mount | grep cifs

# Test connectivity
smbclient -L //192.168.2.10 -U <user>

# Check credentials file
ls -la /run/secrets.d/cifs-credentials
```
