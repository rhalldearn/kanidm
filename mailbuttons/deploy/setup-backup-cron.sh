#!/usr/bin/env bash
#
# setup-backup-cron.sh — Set up pull-based backup cron on local server
#
# Run on the local backup server (192.168.1.10). Installs the backup
# script and cron job that pulls from the VPS.
#
# Prerequisites: SSH key access from this machine to root@79.99.45.220
#   ssh-copy-id root@79.99.45.220
#
# Usage: ./setup-backup-cron.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/opt/kanidm"
BACKUP_SCRIPT="${INSTALL_DIR}/backup.sh"

echo "==> Verifying SSH access to VPS..."
if ssh -o BatchMode=yes -o ConnectTimeout=10 root@79.99.45.220 "echo 'OK'" &>/dev/null; then
    echo "    SSH access confirmed."
else
    echo "ERROR: Cannot SSH to root@79.99.45.220 from this machine."
    echo "       Run: ssh-copy-id root@79.99.45.220"
    exit 1
fi

echo "==> Installing backup script..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp "${SCRIPT_DIR}/backup.sh" "$BACKUP_SCRIPT"
sudo chmod +x "$BACKUP_SCRIPT"

echo "==> Creating backup directory..."
mkdir -p /home/richard/kanidm-backups

echo "==> Creating log file..."
sudo touch /var/log/kanidm-backup.log
sudo chown richard:richard /var/log/kanidm-backup.log

echo "==> Installing cron job (04:00 UTC daily)..."
CRON_LINE="0 4 * * * ${BACKUP_SCRIPT}"
(crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "$CRON_LINE") | crontab -

echo "    Cron job installed:"
crontab -l | grep kanidm

echo ""
echo "=========================================="
echo "  Backup setup complete!"
echo "=========================================="
echo ""
echo "  Backups will pull from VPS daily at 04:00 UTC."
echo "  Local backups stored in: /home/richard/kanidm-backups/"
echo "  Log file: /var/log/kanidm-backup.log"
echo ""
echo "  Test with:"
echo "    ${BACKUP_SCRIPT}"
echo ""
