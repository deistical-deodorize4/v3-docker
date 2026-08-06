#!/bin/bash
# Weekly backup of Pi Zero 2W homelab config
# Runs at 1:00 AM Friday via cron (see setup-maintenance.sh)
# Restore: tar xzf /path/to/backup.tar.gz -C /path/to/project

set -e

# Derive paths from this script's location: <project>/scripts/backup.sh
SOURCE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="${HOME}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M)
BACKUP_FILE="${BACKUP_DIR}/homelab-config-${TIMESTAMP}.tar.gz"
KEEP_LAST=4

mkdir -p "${BACKUP_DIR}"

# Backup: config files, .env, WireGuard keys, iptables wrapper
tar czf "${BACKUP_FILE}" \
  --exclude="node_modules" \
  --exclude="*.log" \
  -C "$(dirname "${SOURCE_DIR}")" "$(basename "${SOURCE_DIR}")"

# Keep only the last KEEP_LAST backups
ls -t "${BACKUP_DIR}"/homelab-config-*.tar.gz 2>/dev/null \
  | tail -n +$((KEEP_LAST + 1)) \
  | xargs -r rm

echo "Backup saved: ${BACKUP_FILE}"
echo "Size: $(du -h "${BACKUP_FILE}" | cut -f1)"
