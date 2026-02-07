#!/usr/bin/env bash
#
# backup.sh — Sync Kanidm backups from VPS to dev machine
#
# Runs on the VPS via cron at 04:00 UTC (1hr after Kanidm's 03:00 backup).
# Uses a dedicated SSH key for push-based backup to the dev machine.
#
set -euo pipefail

BACKUP_DIR="/opt/kanidm/data/backups"
REMOTE_USER="richard"
REMOTE_HOST="${BACKUP_REMOTE_HOST:-}"  # Set in cron env or edit here
REMOTE_DIR="/home/richard/kanidm-backups"
SSH_KEY="/root/.ssh/kanidm_backup_ed25519"
LOG="/var/log/kanidm-backup.log"

log() {
    echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') $*" >> "$LOG"
}

log "=== Backup started ==="

if [ -z "$REMOTE_HOST" ]; then
    log "ERROR: BACKUP_REMOTE_HOST not set. Skipping remote sync."
    exit 1
fi

# Sync backups to dev machine
if rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new" \
    "$BACKUP_DIR/" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"; then
    log "Remote sync to $REMOTE_HOST successful."
else
    log "ERROR: Remote sync to $REMOTE_HOST failed."
    exit 1
fi

# Clean local backups older than 7 days (Kanidm keeps 'versions' count,
# but this is a safety net for any orphaned files)
find "$BACKUP_DIR" -name "*.gz" -mtime +7 -delete 2>/dev/null || true
log "Local cleanup complete."

log "=== Backup finished ==="
