# Loki Remote Access Firewall

This runbook documents the pfSense firewall configuration for remote Loki access over Tailscale.

## Scope

The pfSense rule controls access to Loki at `192.168.1.2:3100` from approved Tailscale clients.

TCP port 3100 permits both log ingestion and Loki query access. It is not a push-only permission.

This rule applies to Tailscale ingress only. Direct LAN access to Loki still requires host-level restrictions.

## Aliases

Create the following aliases in pfSense under **Firewall → Aliases**.

| Alias | Type | Contents |
|---|---|---|
| `LOKI_SERVER` | Host(s) | `192.168.1.2` |
| `LOKI_REMOTE_CLIENTS` | Host(s) | Approved client Tailscale IPv4 addresses |

Obtain each approved client address with:

```sh
tailscale ip -4
```

Do not use `192.168.1.1` as the source alias for remote clients. That address is observed after forwarding to the LAN; match the original client addresses on ingress.

## Firewall rules

Create these rules on the Tailscale ingress interface under **Firewall → Rules**.

| Setting | Allow rule | Deny rule |
|---|---|---|
| Action | Pass | Block |
| Address family | IPv4 | IPv4 |
| Protocol | TCP | TCP |
| Source | `LOKI_REMOTE_CLIENTS` | Any |
| Source port | Any | Any |
| Destination | `LOKI_SERVER` | `LOKI_SERVER` |
| Destination port | `3100` | `3100` |
| Logging | Enabled during testing | Enabled |
| Description | Approved remote clients to Loki | Deny other remote clients to Loki |
| Gateway | Default | Default |

Place both rules above any broad Tailscale-to-LAN pass rule. pfSense interface rules are evaluated in order, and the first matching rule controls the packet.

Do not add these rules to the LAN interface. If no dedicated Tailscale interface or interface group exists, identify the actual ingress filtering path before applying the rules.

## Validation

### Positive test

On an approved client, generate a unique marker and verify it reaches Loki:

```sh
marker="loki-test-$(cat /proc/sys/kernel/random/uuid)"
logger -t loki-ingestion-test -- "$marker"
echo "$marker"

sleep 10

curl --fail-with-body --silent --show-error --get \
  --connect-timeout 5 --max-time 20 \
  'http://192.168.1.2:3100/loki/api/v1/query_range' \
  --data-urlencode "query={job=\"systemd-journal\"} |= \"$marker\"" \
  --data-urlencode 'since=5m' \
  --data-urlencode 'limit=20' |
  jq '{status, streams: [.data.result[]? | {labels: .stream, entries: .values}]}'
```

The test passes when the response contains the exact marker and the stream label `host` identifies the originating host.

### Negative test

From a Tailscale client that is not in `LOKI_REMOTE_CLIENTS`, run:

```sh
curl --connect-timeout 5 --max-time 20 \
  http://192.168.1.2:3100/ready
```

The request should fail. Confirm that the firewall block rule logged the connection.

## Current status

- Verified navi-to-Loki ingestion using a unique marker.
- The marker appeared in Loki with `host=navi` and `job=systemd-journal`.
- Firewall rule configuration and the unapproved-client denial test remain pending.
- Host-level restrictions on the Loki server remain required for direct LAN access.
