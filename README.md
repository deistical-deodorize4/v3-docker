# Pi Zero 2W Homelab (Docker)

A simple Docker stack for your Pi: file manager, VPN, and mesh radio bridge.

## What's in the stack

| Service | What it does | Port |
|---------|-------------|------|
| **FileBrowser (Quantum)** | Web file manager | `8080` |
| **wg-easy** | WireGuard VPN (access your Pi from anywhere) | `51822` (admin UI, local only) + `51820/udp` (VPN) |
| **BLE Bridge** | Exposes your Meshtastic radio over TCP (for the pi02w-hub Telegram bot) | `127.0.0.1:4403` |
| Watchtower | Auto-updates containers monthly | — |

> **Note:** MeshMonitor (the web dashboard) was removed from the stack. The BLE
> bridge now publishes its Meshtastic TCP stream on the Pi's loopback only
> (`127.0.0.1:4403`), and the **pi02w-hub Telegram bot** connects to it directly
> to read your solar node's telemetry (temp, humidity, battery, …). Ask the bot
> with the `📡 Mesh` button or `/mesh`.

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
| wg-easy UI | `http://127.0.0.1:51822` (only on the Pi) | from `.env` |

**Change the default passwords right after logging in.** FileBrowser: Settings → Profile.

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

Once connected, you can open FileBrowser as if you were on your home network. **Don't** forward port `8080` or `4403` to the internet — the VPN is the safe way in.

## Your Meshtastic radio (BLE)

The BLE bridge connects to your Meshtastic radio over Bluetooth and exposes it as a
Meshtastic TCP stream on the Pi's loopback (`127.0.0.1:4403`). The pi02w-hub
Telegram bot connects there for solar-node telemetry.

Find your radio's Bluetooth address:

```bash
docker run --rm --privileged -v /var/run/dbus:/var/run/dbus \
  ghcr.io/yeraze/meshtastic-ble-bridge:latest --scan
```

Copy the `AA:BB:CC:DD:EE:FF` address into `.env` as `BLE_ADDRESS`, then restart:

```bash
docker compose up -d
```

Verify the bridge is listening (the bot connects to this):

```bash
ss -ltn | grep 4403   # 127.0.0.1:4403 should be LISTEN
```

## Useful commands

```bash
docker compose ps                 # is everything running?
docker compose logs filebrowser   # see logs for one service
docker compose down               # stop everything
docker compose up -d              # start everything again
```

## Updating

Containers are pinned to specific versions. Watchtower updates them automatically on the 1st of each month. To update manually:

```bash
docker compose pull
docker compose up -d
```