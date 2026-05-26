# Pi Zero 2W Homelab

Pi-hole, Unbound, WireGuard (wg-easy), Filebrowser, nginx and Watchtower, all in Docker, on a Raspberry Pi Zero 2W with 512MB RAM.

## Prerequisites

- Raspberry Pi Zero 2W
- Pi OS Lite (64-bit), fresh install
- SSH access to the Pi
- A router where you can forward UDP ports (for WireGuard)
- A static LAN IP for the Pi (DHCP reservation on the router, or set it manually)

## Quick Start

### 1. Update the Pi

```
sudo apt update && sudo apt upgrade -y
sudo reboot
```

Wait for the Pi to come back, then reconnect via SSH.

### 2. Clone the repository

```
sudo apt install git -y
git clone <repo-url> pi-zero-homelab
cd pi-zero-homelab
```

Replace `<repo-url>` with the actual URL of this repository.

### 3. Run the install script

**Run this:** `bash install.sh`

This is the only script you run directly during initial setup. It does the following, in order:

1. **Creates required directories** -- `files/`, `filebrowser/`, `nginx/html/` for bind mounts used by the containers
2. **Installs Docker** -- adds the official Docker repository and installs `docker-ce`, `docker-compose-plugin`, and related packages
3. **Adds your user to the `docker` group** -- so you can run Docker without `sudo` (log out and back in after)
4. **Reduces swappiness** -- sets `vm.swappiness=10` to minimise SD card wear

After the script finishes, **log out and back in** (or reconnect your SSH session) for the Docker group change to take effect.

### 4. Configure passwords and settings

```
cp .env.default .env
nano .env
```

You must edit these values:

- `PIHOLE_WEBPASSWORD` -- password for Pi-hole admin panel
- `WG_HOST` / `INIT_HOST` -- your public IP or DDNS hostname (e.g. `vpn.example.com` or `1.2.3.4`)
- `INIT_DNS` -- your Pi's LAN IP (e.g. `192.168.0.15`)

To find your Pi's LAN IP:

```
hostname -I
```

If you don't have a static public IP, use a DDNS service like DuckDNS or No-IP and set `WG_HOST` to your DDNS hostname.

### 5. Start the stack

**Run this:** `docker compose up -d`

This creates and starts all containers (unbound, pihole, filebrowser, wg-easy, nginx, watchtower). The first start takes a few minutes because Unbound installs itself on first run.

The `docker-compose.yml` file is the main configuration that ties everything together. When you run `docker compose up -d`, Docker Compose automatically reads these supporting files (you do **not** run them manually):

| File | Role | How it's used |
|------|------|---------------|
| `unbound-entrypoint.sh` | Unbound first-run installer | Mounted into the `unbound` container. Runs inside the container (not by you) |
| `unbound/unbound.conf` | DNS resolver config | Mounted into the `unbound` container. Defines Quad9 DoT upstream |
| `iptables-nft-wrapper.sh` | nftables fallback | Mounted into the `wg-easy` container at `/usr/sbin/iptables`. Replaces missing `ip_tables` kernel module (Pi OS Trixie ships with nftables only) |
| `.env` | Secrets and settings | Loaded by `wg-easy` for `WG_HOST`, `INIT_HOST`, `INIT_DNS`, and port config |

Check progress:

```
docker compose ps
docker logs unbound --tail 10
```

Wait until `docker ps` shows all services as `(healthy)`.

### 6. Forward port on your router

Log into your router and create a port forwarding rule:

| Setting | Value |
|---------|-------|
| Protocol | UDP |
| External port | 51820 |
| Internal IP | Your Pi's LAN IP |
| Internal port | 51820 |

This is required for WireGuard clients to connect from outside your home network. No other ports need to be open.

### 7. Set up WireGuard on your phone or laptop

First, create an SSH tunnel to access the wg-easy admin UI:

```
# On your computer (not the Pi):
ssh -L 51821:localhost:51821 pi@<pi-lan-ip>
```

Open http://localhost:51821 in your browser. Register the first admin account and log in. Click "Create" to generate a new client, then download the config file or scan the QR code.

Import the config into the WireGuard app on your phone or laptop.

### 8. Verify phone DNS goes through Pi-hole

With `INIT_DNS` set to your Pi's LAN IP, wg-easy pushes Pi-hole as DNS to every new client. After connecting, your phone's DNS queries appear in the Pi-hole query log at `http://<pi-ip>:8081/admin`. If you don't see queries, recreate the client config in wg-easy to pick up the DNS change.

## Accessing the services

| Service | URL | How to reach it |
|---------|-----|-----------------|
| nginx landing page | http://&lt;pi-ip&gt; | Any browser on your LAN |
| Pi-hole admin | http://&lt;pi-ip&gt;:8081/admin | Any browser on your LAN |
| Filebrowser | http://&lt;pi-ip&gt;:8080 | Any browser on your LAN |
| wg-easy UI | http://localhost:51821 | SSH tunnel only |

Replace `<pi-ip>` with your Pi's actual LAN IP address.

The wg-easy admin UI is bound to localhost-only for security. Always use an SSH tunnel to access it.

After installing the WireGuard app on your phone and importing the config, the VPN is also accessible from anywhere (mobile data, other Wi-Fi networks) as long as the Pi is online and your router forwards UDP 51820.

## Maintenance

The Pi maintains itself automatically on a weekly schedule — plus monthly container updates to reduce SD card wear. Two tasks are active out of the box; one requires a one-time setup.

### Already active (no action needed)

| Task | When | What it does | Triggered by |
|------|------|-------------|--------------|
| **Container updates** | 1st of month, 7:00 AM | Watchtower refreshes all Docker images (monthly to limit SD wear) | `watchtower` container (defined in `docker-compose.yml`) |
| **Config backup** | Fri 1:00 AM | Tars `~/pi-zero-homelab/` to `~/backups/` (keeps last 4) | `scripts/backup.sh` — scheduled by cron (set up in `install.sh`) |

### One-time setup (run this after the stack is up)

**Run this once:** `bash ~/pi-zero-homelab/scripts/setup-maintenance.sh`

This enables automatic OS security updates via `unattended-upgrades` (Friday 2:00 AM). You will need your sudo password.

## Troubleshooting

### Container won't start

```
# Check logs
docker logs <container-name> --tail 20

# Recreate with fresh config
docker compose up -d --force-recreate <service-name>
```

### DNS not working through Pi-hole

```
# Check individual services
dig example.com @127.0.0.1 -p 5335 +short    # Unbound directly
dig example.com @127.0.0.1 -p 53 +short       # Via Pi-hole
```

If Unbound answers but Pi-hole doesn't, restart Pi-hole:

```
docker compose restart pihole
```

### Docker containers crash (OOM)

```
# Check for OOM kills
journalctl -k | grep -i oom

# Check memory usage
free -h

# Check per-container memory
docker stats --no-stream
```

If OOM kills happen, increase memory limits in `docker-compose.yml` and recreate:

```
docker compose down
docker compose up -d
```

### WireGuard clients connect but have no internet

Check that `INIT_DNS` in `.env` is set correctly:

```
grep INIT_DNS .env
```

If it's wrong, fix it then restart wg-easy:

```
docker compose restart wg-easy
```

Then regenerate the client config on your phone (delete and recreate the tunnel).

### Reset everything and start over

```
cd ~/pi-zero-homelab
docker compose down -v
docker system prune -af
rm -rf wg-easy
```

Then start again from step 3 (configure `.env` and `docker compose up -d`).

## Security notes

- wg-easy admin UI is bound to 127.0.0.1 -- use an SSH tunnel to access it
- Unbound uses Quad9 DoT (Swiss non-profit, audited privacy policy)
- Only UDP port 51820 needs to be open on your router
- WireGuard tunnel encrypts all traffic between your phone and Pi

## Project structure

```
pi-zero-homelab/
│
├── 🏃 YOU RUN THESE
│   ├── install.sh                  # Initial setup (Docker, directories, swappiness)
│   └── scripts/setup-maintenance.sh  # One-time: enable OS auto-updates
│
├── 🤖 USED AUTOMATICALLY BY DOCKER COMPOSE
│   ├── docker-compose.yml          # Main config — defines all 6 services
│   ├── .env.default                # Template — copy to .env and edit
│   ├── .env                        # Your secrets (gitignored)
│   ├── iptables-nft-wrapper.sh     # nftables → iptables shim for wg-easy
│   ├── unbound-entrypoint.sh       # Installs Unbound on container first start
│   └── unbound/
│       └── unbound.conf            # Unbound DNS config (Quad9 DoT)
│
├── ⏰ RUN ON SCHEDULE (no action needed)
│   └── scripts/backup.sh           # Friday 1AM cron — tars configs to ~/backups/
│
└── 📖 Other
    ├── LICENSE
    ├── README.md                   # This file
    ├── files/                      # Filebrowser file root (created by install.sh)
    ├── filebrowser/                # Filebrowser database (created by install.sh)
    └── nginx/
        └── html/                   # nginx landing page (created by install.sh)
```
