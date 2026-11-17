# Vpn-lite by Rust

Minimal OpenVPN tunnel container: **HTTP CONNECT proxy + killswitch firewall
+ process supervisor** in a single small static Rust binary (~1 MB).

A lean alternative to VPN sidecar images for workloads that only need
"traffic out through a specific tunnel" — e.g. per-worker egress IPs.

## Features

- **CONNECT proxy** on `0.0.0.0:8888` (HTTPS tunneling; plain-HTTP forward
  proxying intentionally unsupported)
- **`GET /healthz`** on the same port — `200` only while `tun0` exists
- **Killswitch (iptables)**: default-DROP on INPUT/FORWARD/OUTPUT; traffic
  may only leave via `tun0` or the VPN server itself — no IP leaks if the
  tunnel drops
- **Tunnel DNS** pinned to `10.2.0.1` (ProtonVPN); external DNS blocked
- **Auto-restart**: exits when `openvpn` dies → Docker `restart` policy
- **Zero runtime deps beyond `openvpn`**: the supervisor *is* the binary

## Measured footprint (Alpine 3.20, openvpn 2.6)

| | vpn-lite | typical VPN sidecar |
|---|---|---|
| RSS per container | **~4–8 MiB** | ~35–45 MiB |

## Usage

```bash
docker run -d \
  --name vpn1 \
  --cap-add NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  -e PROTONVPN_USER='your-user' \
  -e PROTONVPN_PASS='your-pass' \
  -v /path/to/profile.ovpn:/etc/openvpn/client.ovpn:ro \
  -p 127.0.0.1:18011:8888 \
  vpn-lite
```

Then:

```bash
curl -x http://127.0.0.1:18011 https://api.ipify.org   # exit IP of the tunnel
curl http://127.0.0.1:18011/healthz                    # liveness
```

### docker compose

See `docker-compose.yml` — copy `.env.example` to `.env`, drop `.ovpn`
profiles into `profiles/`, `docker compose up -d`.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `PROTONVPN_USER` | — (required) | VPN username |
| `PROTONVPN_PASS` | — (required) | VPN password |
| `OPENVPN_PROFILE` | `/etc/openvpn/client.ovpn` | Path to `.ovpn` profile |
| `PROXY_PORT` | `8888` | CONNECT proxy listen port |
| `VPN_DNS` | `10.2.0.1` | Resolver forced inside the tunnel |
| `KILLSWITCH` | `on` | `off` disables iptables rules (**debug only**) |

## Notes & limitations

- OpenVPN **TCP client** profiles only (e.g. ProtonVPN `.ovpn` files)
- The killswitch allowlists the `remote` IPs found in the profile; if your
  profile rotates remotes to new IPs, reconnect picks them up on restart
- `auth-user-pass` profiles only — no certificates/client-key auth yet
- Run **one tunnel per container**; scale by running N containers
- Tested with ProtonVPN free-server profiles; other providers unverified

## Build

```bash
docker build -t vpn-lite .
# or locally: cargo build --release
```
