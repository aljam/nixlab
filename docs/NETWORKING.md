# Networking

This document describes the network topology, subnets, and firewall rules for nixlab.

## Topology

```
                    ┌─────────────┐
                    │   Internet  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   pfSense   │
                    │  Firewall   │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼──────┐ ┌───▼────┐ ┌────▼─────┐
       │    r820     │ │  r730  │ │   r730xd │
       │  HAProxy    │ │  ZFS   │ │  Apps    │
       │  Edge       │ │  Media │ │  Services│
       └─────────────┘ └────────┘ └──────────┘
              │
       ┌──────┴──────┐
       │             │
  ┌────▼────┐  ┌─────▼────┐
  │  navi   │  │   oryx   │
  │ Desktop │  │  Laptop  │
  └─────────┘  └──────────┘
```

## Subnets

| VLAN | Subnet         | Purpose                    |
|------|----------------|----------------------------|
| 10   | 10.0.10.0/24   | Servers (r730, r730xd, r820) |
| 20   | 10.0.20.0/24   | Desktops (navi, oryx)      |
| 30   | 10.0.30.0/24   | IoT / Guest                |

## Firewall Rules

### nftables

The firewall is configured via NixOS `networking.firewall` and custom nftables rules.

Key rules:

- **Input chain**: Allow SSH (22), HAProxy (80/443), and specific service ports
- **Forward chain**: Allow traffic from LAN to servers via HAProxy
- **Drop policy**: Default deny for unmatched traffic

### Security Properties

The `tests/firewall.nix` test enforces:

1. **qBittorrent WebUI** (port 8080) is not reachable from LAN hosts
2. **Vaultwarden** (port 8888) is not reachable from LAN hosts
3. **node-exporter** (port 9100) is only reachable from r730 (monitoring host)

Run the test with:

```bash
nix build .#checks.x86_64-linux.firewall
```

## HAProxy Configuration

HAProxy runs on r820 and proxies:

- `media.<domain>` → Jellyfin (r730:8096)
- `vaultwarden.<domain>` → Vaultwarden (r730xd:8888)
- `grafana.<domain>` → Grafana (r730:3000)

Backend health checks ensure services are available before routing traffic.

## DNS

Internal DNS is provided by pfSense. Hosts are registered via DHCP static leases.

## Troubleshooting

### Check Firewall Rules

```bash
sudo nft list ruleset
```

### Test Port Reachability

```bash
# From another host
nc -zv <host> <port>

# Check listening services
ss -tlnp | grep <port>
```

### HAProxy Debug

```bash
# Check HAProxy status
echo "show stat" | socat /var/run/haproxy.sock stdio

# View HAProxy logs
journalctl -u haproxy -f
```
