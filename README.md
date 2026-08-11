## What You Get

| Service | Port | 
|---------|------|
|FileBrowser | `8080` | 
|Wg-easy | `51822` | 
|MeshMonitor | `8081` | 
|BLE Bridge | — | 
|Watchtower | — |


## Step-by-Step Guide
### Step 1: Clone

```bash
git clone
cd v3-docker
```

---

### Step 2: Run the installer

```bash
chmod +x install.sh
./install.sh
```

The script will:
- Update your system packages
- Install Docker 
- Verify Docker's GPG key fingerprint 
- Install Bluetooth support 
- Enable the Bluetooth service
- Copy `.env.default` to `.env`

⚠️ After the installer finishes, log out and log back in (or reboot):

```bash
exit
# SSH back in
```

This is required so your user can run Docker commands.

---

### Step 3: Edit your settings



```bash
nano .env
```

**Change these values:**

| Setting | What it is |
|---------|------------|
| `TZ` | Your timezone. E.g: `America/New_York`, `Europe/London`, `Asia/Tokyo`. [(Full list)](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) |
| `INIT_HOST` | Your Pi's public IP or Dynamic DNS hostname|
| `INIT_DNS` | Your Pi's local IP address|
| `WG_ADMIN_USERNAME` | wg-easy admin username |
| `WG_ADMIN_PASSWORD` | wg-easy admin password. Leave empty to create it manually via the setup wizard on first start. Remove it from `.env` after first successful start |

Leave `BLE_ADDRESS` empty for now

> **Router port forwarding (only if you use the VPN from outside your home):**
> On your router, forward **UDP port `51820`** to your Pi's IP. Without this, VPN clients can only connect while on your home network.

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

> **BLE bridge behavior:** the `meshmonitor-ble-bridge` container needs `BLE_ADDRESS` to know which device to connect to. Until you set it, the container exits immediately (it has nothing to do) and keeps restarting — this is expected. MeshMonitor will show no node data until `BLE_ADDRESS` is set and the device is within Bluetooth range. After editing `.env`, recreate the containers with `docker compose up -d --force-recreate meshmonitor-ble-bridge`.

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
watchtower              Up                  ...
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
| FileBrowser | `http://<YOUR_PI_IP>:8080` |
| WireGuard (wg-easy) | `http://127.0.0.1:51822` (see note below) |
| MeshMonitor | `http://<YOUR_PI_IP>:8081` |

**WireGuard (wg-easy) note:** the admin UI is bound to `127.0.0.1` only, so from another machine use an SSH tunnel:

```bash
ssh -L 51822:127.0.0.1:51822 <pi-user>@<YOUR_PI_IP>
# then open http://localhost:51822
```

> If you see `bind [127.0.0.1]:51822: Address already in use`, that port is taken on **your** computer. Pick any other free port for the local side, e.g.:
> ```bash
> ssh -L 9999:127.0.0.1:51822 <pi-user>@<YOUR_PI_IP>
> # then open http://localhost:9999
> ```

Log in with the admin username/password set in `.env` (`WG_ADMIN_USERNAME` / `WG_ADMIN_PASSWORD`), or with the account you create in the setup wizard on first start.

After the admin account is created, remove the `WG_ADMIN_PASSWORD` (and `INIT_*`) lines from `.env` so the password isn't sitting in plaintext on disk.

For VPN clients to connect from outside your home, make sure **UDP 51820** is forwarded on your router to the Pi's IP (see Step 3).

**FileBrowser:** first login uses `admin` / `admin` — change it right after (Settings → Profile).

**MeshMonitor login:**

- Username: `admin`
- Password: `changeme`

Change this password right after logging in (click your username → Change Password).

---

## Running Alongside the Telegram Hub

This stack runs fine on the same Pi as the **pi02w-hub** Telegram bot. Both start automatically on boot:

- **This stack** — `install.sh` enables the Docker service and every container has `restart: unless-stopped`, so `docker compose up -d` needs to be run once and everything comes back after a reboot.
- **The hub** — installed as a systemd service (`pi02w-hub.service`) that starts at boot too.

Their schedules don't overlap: Watchtower updates containers on the 1st of the month at 7:00 AM, and the hub sends its morning weather report at 9:00 AM.

### Browse the hub's data from FileBrowser

FileBrowser mounts the hub's `data/` directory as a **read-only** `pi02w-hub` folder, so you can grab CSVs and logs from the browser without SSH.

The path is set with `HUB_DATA_DIR` in `.env` (defaults to `/home/pi/pi02w-hub/data`). If the hub lives somewhere else, point it there:

```ini
HUB_DATA_DIR=/path/to/pi02w-hub/data
```

After changing `.env`, recreate FileBrowser:

```bash
docker compose up -d --force-recreate filebrowser
```

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

### Logs

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

Containers are **pinned to specific versions** in `docker-compose.yml` and **Watchtower** automatically updates them on the 1st of every month at 7:00 AM. To update manually:

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


### Files in this project

```
v3-docker/
├── .env                 
├── .env.default         
├── docker-compose.yml   
├── install.sh           
├── iptables-nft-wrapper.sh 
├── LICENSE
└── scripts/
    ├── backup.sh
    └── setup-maintenance.sh
```

---

## License

MIT
