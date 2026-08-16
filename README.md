# Pi Zero 2W Homelab (Docker)

A simple Docker stack for your Pi: file manager, VPN, and mesh radio monitoring.

## What's in the stack

| Service | What it does | Port |
|---------|-------------|------|
| **FileBrowser (Quantum)** | Web file manager | `8080` |
| **wg-easy** | WireGuard VPN (access your Pi from anywhere) | `51822` (admin UI, local only) + `51820/udp` (VPN) |
| **MeshMonitor** | Meshtastic mesh radio dashboard | `8081` |
| BLE Bridge | Connects MeshMonitor to your radio over Bluetooth | — |
| Watchtower | Auto-updates containers monthly | — |

## Quick start

```bash
git clone <this repo>
cd v3-docker
chmod +x install.sh
./install.sh
```

The installer sets up Docker, Bluetooth, and copies `.env.default` to `.env`.

Then edit your settings:

```bash
nano .env
```

Key settings:

| Setting | What it is |
|---------|------------|
| `INIT_HOST` | Your public IP or domain (needed for the VPN) |
| `INIT_DNS` | Your Pi's local IP |
| `WG_ADMIN_USERNAME` / `WG_ADMIN_PASSWORD` | wg-easy admin login |
| `BLE_ADDRESS` | Your radio's Bluetooth MAC (find it below) |
| `TZ` | Your timezone, e.g. `Europe/Madrid` |

Log out and back in (or reboot), then start everything:

```bash
docker compose up -d
```

## Where to access things

Find your Pi's IP first:

```bash
hostname -I
```

| Service | Address | Login |
|---------|---------|-------|
| FileBrowser | `http://<PI_IP>:8080` | `admin` / `admin` |
| MeshMonitor | `http://<PI_IP>:8081` | `admin` / `changeme` |
| wg-easy UI | `http://127.0.0.1:51822` (only on the Pi) | from `.env` |

**Change the default passwords right after logging in.** FileBrowser: Settings → Profile. MeshMonitor: click your username → Change Password.

### Access wg-easy from your computer

The admin UI is only reachable on the Pi itself. From another machine, use an SSH tunnel:

```bash
ssh -L 51822:127.0.0.1:51822 pi@<PI_IP>
# then open http://localhost:51822
```

### Connect to your Pi's VPN from outside your home

1. Set `INIT_HOST` in `.env` to your public IP or DDNS hostname
2. On your router, forward **UDP `51820`** to your Pi's IP
3. Create a client in the wg-easy UI and scan its QR code with the WireGuard app

Once connected, you can open FileBrowser/MeshMonitor as if you were on your home network. **Don't** forward port `8080` or `8081` to the internet — the VPN is the safe way in.

## Your Meshtastic radio (BLE)

Find its Bluetooth address:

```bash
docker run --rm --privileged -v /var/run/dbus:/var/run/dbus \
  ghcr.io/yeraze/meshtastic-ble-bridge:latest --scan
```

Copy the `AA:BB:CC:DD:EE:FF` address into `.env` as `BLE_ADDRESS`, then restart:

```bash
docker compose up -d
```

## Useful commands

```bash
docker compose ps                 # is everything running?
docker compose logs meshmonitor   # see logs for one service
docker compose down               # stop everything
docker compose up -d              # start everything again
```

## Updating

Containers are pinned to specific versions. Watchtower updates them automatically on the 1st of each month. To update manually:

```bash
docker compose pull
docker compose up -d
```