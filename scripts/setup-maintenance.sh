#!/bin/bash
# Run this once to enable weekly maintenance (backup + upgrades)
# sudo password will be prompted where needed
# Schedule (every Friday):
#   1:00 AM  → backup
#   2:00 AM  → OS package upgrades (unattended-upgrades)
#   7:00 AM  → Docker container updates (Watchtower)

set -euo pipefail

# Derive project dir from this script's location: <project>/scripts/setup-maintenance.sh
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_SCRIPT="${PROJECT_DIR}/scripts/backup.sh"
BACKUP_LOG="${HOME}/backups/backup.log"

echo "=== 1/3 Installing unattended-upgrades ==="
sudo apt update -qq
sudo apt install -y unattended-upgrades
sudo systemctl enable --now unattended-upgrades

# Configure: enable auto-upgrades
sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Resolve actual distro values (single-quoted heredoc prevents bash expansion)
DISTRO_ID=$(lsb_release -is 2>/dev/null || apt-get --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo "Debian")
DISTRO_CODENAME=$(lsb_release -cs 2>/dev/null || grep -oP 'VERSION_CODENAME=\K.*' /etc/os-release || echo "trixie")

# Configure: only security updates, no prompts, no reboot
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null <<EOF
Unattended-Upgrade::Allowed-Origins {
    "${DISTRO_ID}:${DISTRO_CODENAME}-security";
};
Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
EOF

# Change apt daily timers to run weekly on Friday at 2:00 AM
sudo mkdir -p /etc/systemd/system/apt-daily.timer.d
sudo mkdir -p /etc/systemd/system/apt-daily-upgrade.timer.d

sudo tee /etc/systemd/system/apt-daily.timer.d/override.conf > /dev/null <<'EOF'
[Unit]
Description=Daily apt download activities (overridden to weekly)

[Timer]
OnCalendar=Fri 2:00
RandomizedDelaySec=0
Persistent=false
EOF

sudo tee /etc/systemd/system/apt-daily-upgrade.timer.d/override.conf > /dev/null <<'EOF'
[Unit]
Description=Daily apt upgrade activities (overridden to weekly)

[Timer]
OnCalendar=Fri 2:00
RandomizedDelaySec=0
Persistent=false
EOF

sudo systemctl daemon-reload
sudo systemctl restart apt-daily.timer apt-daily-upgrade.timer

echo "=== 2/3 Setting up backup cron (every Friday 1:00 AM) ==="
chmod +x "${BACKUP_SCRIPT}"
(
  crontab -l 2>/dev/null | grep -v backup.sh || true
  echo "# Weekly homelab backup (Friday 1:00 AM)"
  echo "0 1 * * 5 ${BACKUP_SCRIPT} >> ${BACKUP_LOG} 2>&1"
) | crontab -

echo "=== 3/3 Applying Docker stack changes (Watchtower) ==="
cd "${PROJECT_DIR}"
docker compose up -d --force-recreate watchtower

echo ""
echo "Done! Schedule:"
echo "  Fri 1:00 → Backup (cron)"
echo "  Fri 2:00 → OS upgrades (apt)"
echo "  1st of month 7:00 → Container updates (Watchtower)"
