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

# Create nginx directories and default page
if [ ! -d nginx/html ]; then
    echo "Creating nginx directories..."
    mkdir -p nginx/html
fi
if [ ! -f nginx/html/index.html ]; then
    cat > nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pi Zero 2W Server</title>
    <style>
        body { font-family: sans-serif; max-width: 600px; margin: 50px auto; padding: 0 20px; text-align: center; }
        h1 { color: #333; }
        p { color: #666; }
    </style>
</head>
<body>
    <h1>Pi Zero 2W Server</h1>
    <p>NGINX is running. Place your site files in nginx/html.</p>
</body>
</html>
EOF
fi

# Create filebrowser directories
mkdir -p files filebrowser

# Create syncthing directories
mkdir -p syncthing/config

# Update package list and system
echo "Updating system..."
sudo apt-get update && sudo apt-get upgrade -y

# Install required dependencies
echo "Installing dependencies..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

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

# Reduce swappiness to minimize SD card wear (zram handles swap)
echo "Setting vm.swappiness=10..."
echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl -w vm.swappiness=10 > /dev/null

echo "Installation complete!"
echo "Please log out and log back in for docker group changes to take effect"
echo "Then run 'docker compose up -d' to start all services."
IP=$(hostname -I | awk '{print $1}')
echo "Access Pi-hole admin at http://$IP:8081/admin"
echo "Access FileBrowser at http://$IP:8080"
echo "Access nginx landing page at http://$IP"
echo "Syncthing web UI at http://localhost:8384 (SSH tunnel: ssh -L 8384:localhost:8384 pi@$IP)"
echo "Pi-hole DNS is on port 53 (configure devices to use $IP as DNS server)"