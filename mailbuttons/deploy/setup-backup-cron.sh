#!/usr/bin/env bash
#
# setup-backup-cron.sh — Set up backup cron job on VPS
#
# Run from dev machine. Generates a dedicated SSH keypair on the VPS
# for backup use, then installs the cron job.
#
# Usage: ./setup-backup-cron.sh <dev-machine-ip-or-hostname>
#
set -euo pipefail

VPS_IP="79.99.45.220"
VPS_USER="root"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <dev-machine-ip-or-hostname>"
    echo ""
    echo "  This is the IP/hostname the VPS will use to reach your dev machine"
    echo "  for rsync backups (e.g., your public IP or a WireGuard address)."
    exit 1
fi

DEV_MACHINE_HOST="$1"

echo "==> Uploading backup script to VPS..."
scp "$(dirname "$0")/backup.sh" "${VPS_USER}@${VPS_IP}:/opt/kanidm/backup.sh"
ssh "${VPS_USER}@${VPS_IP}" chmod +x /opt/kanidm/backup.sh

echo ""
echo "==> Generating backup SSH keypair on VPS..."
PUBKEY=$(ssh "${VPS_USER}@${VPS_IP}" bash -s <<'REMOTE_KEYGEN'
set -euo pipefail

KEY_PATH="/root/.ssh/kanidm_backup_ed25519"

if [ -f "$KEY_PATH" ]; then
    echo "    Key already exists, reusing." >&2
else
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "kanidm-backup@vps" >&2
fi

cat "${KEY_PATH}.pub"
REMOTE_KEYGEN
)

echo ""
echo "==> Installing cron job on VPS..."
ssh "${VPS_USER}@${VPS_IP}" bash -s -- "$DEV_MACHINE_HOST" <<'REMOTE_CRON'
set -euo pipefail

DEV_HOST="$1"
CRON_LINE="0 4 * * * BACKUP_REMOTE_HOST=${DEV_HOST} /opt/kanidm/backup.sh"

# Add cron job if not already present
(crontab -l 2>/dev/null | grep -v '/opt/kanidm/backup.sh'; echo "$CRON_LINE") | crontab -

echo "    Cron job installed."
crontab -l
REMOTE_CRON

echo ""
echo "=========================================="
echo "  Backup setup complete!"
echo "=========================================="
echo ""
echo "  Add this public key to ~/.ssh/authorized_keys on your dev machine:"
echo ""
echo "  $PUBKEY"
echo ""
echo "  Then create the backup directory:"
echo "    mkdir -p ~/kanidm-backups"
echo ""
echo "  Test with:"
echo "    ssh ${VPS_USER}@${VPS_IP} BACKUP_REMOTE_HOST=${DEV_MACHINE_HOST} /opt/kanidm/backup.sh"
echo ""
