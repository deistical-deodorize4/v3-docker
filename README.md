# Pi Zero 2W Privacy Stack

A beginner-friendly Docker setup for your Raspberry Pi Zero 2W that gives you a file manager, a VPN, and a Meshtastic mesh network monitor — all from your browser.

## What You Get

| Icon | Service | Port | What it does |
|------|---------|------|-------------|
| 📁 | **FileBrowser** | `8080` | Upload/download files through your browser |
| 🔒 | **wg-easy** | `51821` | WireGuard VPN with a web interface |
| 📡 | **MeshMonitor** | `8081` | Dashboard for your Meshtastic mesh network |
| 🔵 | **BLE Bridge** | — | Connects MeshMonitor to your node via Bluetooth |

---

## Step-by-Step Guide

### Step 0: What You Need

- [ ] Raspberry Pi Zero 2W
- [ ] MicroSD card (16 GB or more)
- [ ] Micro USB power cable
- [ ] Your Pi connected to WiFi with SSH enabled
- [ ] A Meshtastic device with Bluetooth (Heltec, LilyGo, RAK, etc.)
- [ ] A computer to SSH into the Pi

---

### Step 1: Download this project onto your Pi

SSH into your Pi and run:

```bash
git clone <put-the-repo-url-here>
cd pi02w-privacy-stack
```

---

### Step 2: Run the installer

```bash
chmod +x install.sh
./install.sh
```

The script will:
- Update your system packages
- Install Docker (needed to run the services)
- Install Bluetooth support (needed for the Meshtastic connection)
- Enable the Bluetooth service
- Copy `.env.default` to `.env` (your settings file)

⚠️ **After the installer finishes, log out and log back in** (or reboot):

```bash
exit
# SSH back in
```

This is required so your user can run Docker commands.

---

### Step 3: Edit your settings

Open the settings file:

```bash
nano .env
```

You'll see this:

```ini
TZ=Europe/Madrid
INIT_HOST=vpn.example.com
INIT_DNS=your_pi's_static_ip
WG_ADMIN_USERNAME=admin
WG_ADMIN_PASSWORD=CHANGE_ME
WG_UI_PORT=51821
BLE_ADDRESS=
```

**Change these values:**

| Setting | What to put |
|---------|------------|
| `TZ` | Your timezone. Examples: `America/New_York`, `Europe/London`, `Asia/Tokyo`. [Full list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) |
| `INIT_HOST` | Your Pi's public IP or Dynamic DNS hostname (only needed if you use the VPN from outside your home) |
| `INIT_DNS` | Your Pi's local IP address, e.g. `192.168.1.100` |
| `WG_ADMIN_USERNAME` | wg-easy admin username |
| `WG_ADMIN_PASSWORD` | wg-easy admin password. Leave empty to create it manually via the setup wizard on first start. Remove it from `.env` after first successful start |

Leave `BLE_ADDRESS` empty for now — we'll fill it in the next step.

**Save and exit:** `Ctrl+X`, then `Y`, then `Enter`.

---

### Step 4: Find your Meshtastic device's Bluetooth address

Your Meshtastic device talks over Bluetooth, so MeshMonitor needs its MAC address.

**4a.** Make sure your Meshtastic device is **powered on** and Bluetooth is **enabled**.

**4b.** On your Pi, run this scan command:

```bash
docker run --rm --privileged \
  -v /var/run/dbus:/var/run/dbus \
  ghcr.io/yeraze/meshtastic-ble-bridge:latest --scan
```

**4c.** Wait a few seconds. You'll see something like:

```
Found Meshtastic device: Meshtastic_1a2b (AA:BB:CC:DD:EE:FF)
```

**4d.** Copy the MAC address (the `AA:BB:CC:DD:EE:FF` part) and edit `.env` again:

```bash
nano .env
```

Find the line `BLE_ADDRESS=` and change it to:

```ini
BLE_ADDRESS=AA:BB:CC:DD:EE:FF
```

Save and exit: `Ctrl+X`, `Y`, `Enter`.

> **Scan didn't find your device?** See the "Pairing" section below, then come back here.

---

### Step 5: Start the services

```bash
docker compose up -d
```

This will download the Docker images and start all services. It may take a few minutes the first time.

To check everything is running:

```bash
docker compose ps
```

You should see all services with `Up` in the status column:

```
NAME                    STATUS              PORTS
filebrowser             Up                  ...
meshmonitor             Up                  ...
meshmonitor-ble-bridge  Up                  ...
wg-easy                 Up                  ...
```

---

### Step 6: Open the dashboards

Find your Pi's IP address:

```bash
hostname -I
```

Then open these in your browser:

| Service | URL |
|---------|-----|
| 📁 FileBrowser | `http://<YOUR_PI_IP>:8080` |
| 🔒 WireGuard (wg-easy) | `http://127.0.0.1:51821` (see note below) |
| 📡 MeshMonitor | `http://<YOUR_PI_IP>:8081` |

**WireGuard (wg-easy) note:** the admin UI is bound to `127.0.0.1` only, so from another machine use an SSH tunnel:

```bash
ssh -L 51821:127.0.0.1:51821 <pi-user>@<YOUR_PI_IP>
# then open http://localhost:51821
```

Log in with the admin username/password set in `.env` (`WG_ADMIN_USERNAME` / `WG_ADMIN_PASSWORD`), or with the account you create in the setup wizard on first start.

**MeshMonitor login:**

- Username: `admin`
- Password: `changeme`

Change this password right after logging in (click your username → Change Password).

---

## Pairing Your Meshtastic Device (if needed)

Some devices need to be paired with your Pi before the BLE bridge can use them.

**1.** Start the Bluetooth pairing tool:

```bash
bluetoothctl
```

**2.** Turn on scanning:

```
scan on
```

**3.** Wait for your device to appear. You'll see something like:

```
[NEW] Device AA:BB:CC:DD:EE:FF Meshtastic_1a2b
```

**4.** Pair with it:

```
pair AA:BB:CC:DD:EE:FF
```

**5.** Trust it (so it connects automatically in the future):

```
trust AA:BB:CC:DD:EE:FF
```

**6.** Exit:

```
exit
```

**7.** Now redo Step 4 (scan with the Docker command) and set `BLE_ADDRESS` in `.env`.

**8.** Restart the services:

```bash
docker compose up -d
```

---

## Useful Commands

### Check if services are running

```bash
docker compose ps
```

### See what's happening (logs)

```bash
# All services at once
docker compose logs

# Just one service
docker compose logs meshmonitor
docker compose logs meshmonitor-ble-bridge
```

### Stop everything

```bash
docker compose down
```

### Start everything again

```bash
docker compose up -d
```

### Update to the latest version

```bash
docker compose pull
docker compose up -d
```

---

## If Something Goes Wrong

### MeshMonitor shows a blank white page

Edit `docker-compose.yml`:

```bash
nano docker-compose.yml
```

Find the line `ALLOWED_ORIGINS=http://localhost:8081` and add your Pi's IP:

```
- ALLOWED_ORIGINS=http://localhost:8081,http://192.168.1.100:8081
```

Replace `192.168.1.100` with your Pi's actual IP. Then restart:

```bash
docker compose up -d
```

### BLE Bridge won't connect

1. Is your Meshtastic device **on** and in **Bluetooth range**? (10-30 meters)
2. Did you pair it? (see the Pairing section above)
3. Check the logs: `docker compose logs meshmonitor-ble-bridge`

### A container won't start

```bash
docker compose logs <service-name>
```

Example: `docker compose logs wg-easy` — the error message will tell you what's wrong.

---

## About This Project

This stack is designed to run comfortably on a Pi Zero 2W (512 MB RAM). Every service has resource limits:

| Service | Max RAM | Max CPU |
|---------|---------|---------|
| FileBrowser | 32 MB | 25% |
| wg-easy | 128 MB | 25% |
| BLE Bridge | 64 MB | 10% |
| MeshMonitor | 128 MB | 25% |

### Files in this project

```
pi02w-privacy-stack/
├── .env                 ← Your settings (don't share/commit this!)
├── .env.default         ← Template you copy to .env
├── docker-compose.yml   ← Defines all the services
├── install.sh           ← Sets up Docker and Bluetooth
├── iptables-nft-wrapper.sh  ← Fix for newer Pi OS versions
├── LICENSE
└── scripts/
    ├── backup.sh
    └── setup-maintenance.sh
```

---

## License

MIT
