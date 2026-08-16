#!/bin/bash

if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script as root or with sudo."
    echo "It will use sudo internally where needed."
    exit 1
fi

# Check for .env file
if [ ! -f .env ]; then
    echo "Warning: .env file not found."
    if [ -f .env.default ]; then
        echo "Copying .env.default to .env..."
        cp .env.default .env
        echo "Please edit .env with your passwords before running 'docker compose up -d'"
    else
        echo "Error: .env.default not found."
        exit 1
    fi
fi

# Create filebrowser directories
mkdir -p files filebrowser
if [ ! -f filebrowser/config.yaml ]; then
    echo "Creating filebrowser/config.yaml from filebrowser.config.example..."
    cp filebrowser.config.example filebrowser/config.yaml
fi

# Update package list and system
echo "Updating system..."
sudo apt-get update && sudo apt-get upgrade -y

# Install required dependencies
echo "Installing dependencies..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    bluez \
    bluez-tools

# Add Docker's official GPG key
echo "Adding Docker GPG key..."
sudo mkdir -m 0755 -p /etc/apt/keyrings

# Docker's official signing key fingerprint (published at
# https://download.docker.com/linux/debian/gpg)
DOCKER_GPG_FINGERPRINT="9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88"

# Download the key to a temp location and verify its fingerprint before
# installing it, so a compromised/mistyped URL can't poison apt.
TMP_DIR="$(mktemp -d)"
if ! curl -fsSL https://download.docker.com/linux/debian/gpg | \
        gpg --dearmor -o "${TMP_DIR}/docker.gpg"; then
    echo "ERROR: Failed to download Docker GPG key."
    rm -rf "${TMP_DIR}"
    exit 1
fi

ACTUAL_FPR="$(gpg --batch --with-colons --show-keys "${TMP_DIR}/docker.gpg" | awk -F: '$1=="fpr" {print $10; exit}')"
EXPECTED_FPR="$(echo "${DOCKER_GPG_FINGERPRINT}" | tr -d ' ')"

if [ "${ACTUAL_FPR}" != "${EXPECTED_FPR}" ]; then
    echo "ERROR: Docker GPG key fingerprint verification failed!"
    echo "  Expected: ${EXPECTED_FPR}"
    echo "  Got:      ${ACTUAL_FPR:-<none>}"
    echo "Refusing to install the Docker repository key."
    rm -rf "${TMP_DIR}"
    exit 1
fi

echo "Docker GPG key fingerprint verified: ${DOCKER_GPG_FINGERPRINT}"
sudo install -m 0644 "${TMP_DIR}/docker.gpg" /etc/apt/keyrings/docker.gpg
rm -rf "${TMP_DIR}"

# Set up Docker repository (detect the real architecture instead of
# hardcoding arm64, so 32-bit armhf systems install the right packages)
ARCH="$(dpkg --print-architecture)"
echo "Setting up Docker repository (arch=${ARCH})..."
echo \
  "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  bookworm stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package list again
sudo apt-get update

# Install Docker
echo "Installing Docker..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker service
echo "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group
echo "Adding user to docker group..."
sudo usermod -aG docker $USER

# Enable Bluetooth service (required for MeshMonitor BLE bridge)
echo "Enabling Bluetooth service..."
sudo systemctl enable bluetooth
sudo systemctl start bluetooth

# Reduce swappiness to minimize SD card wear (zram handles swap)
echo "Setting vm.swappiness=10..."
echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl -w vm.swappiness=10 > /dev/null

echo "Installation complete!"
echo "Please log out and log back in for docker group changes to take effect"
echo ""
echo "=== NEXT STEPS ==="
echo "1. Edit .env and set BLE_ADDRESS to your Meshtastic device's MAC address."
echo "   To find it, run:"
echo "     docker run --rm --privileged -v /var/run/dbus:/var/run/dbus \\"
echo "       ghcr.io/yeraze/meshtastic-ble-bridge:latest --scan"
echo ""
echo "2. If your device requires pairing, run:"
echo "     bluetoothctl"
echo "     scan on"
echo "     pair AA:BB:CC:DD:EE:FF"
echo "     trust AA:BB:CC:DD:EE:FF"
echo "     exit"
echo ""
echo "3. Then start all services:"
echo "     docker compose up -d"
echo ""
IP=$(hostname -I | awk '{print $1}')
echo "Access FileBrowser at http://$IP:8080"
echo "Access MeshMonitor at http://$IP:8081"
