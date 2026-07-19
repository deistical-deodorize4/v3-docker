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
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo "Setting up Docker repository..."
echo \
  "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
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
