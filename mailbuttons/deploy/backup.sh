#!/usr/bin/env bash
#
# backup.sh — Pull Kanidm backups from VPS to local server
#
# Runs on the local backup server (192.168.1.10) via cron at 04:00 UTC
# (1hr after Kanidm's 03:00 online backup).
#
set -euo pipefail

VPS_IP="79.99.45.220"
VPS_USER="root"
VPS_BACKUP_DIR="/opt/kanidm/data/backups"
LOCAL_BACKUP_DIR="/home/richard/kanidm-backups"
LOG="/var/log/kanidm-backup.log"

log() {
    echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') $*" >> "$LOG"
}

log "=== Backup started ==="

mkdir -p "$LOCAL_BACKUP_DIR"

# Pull backups from VPS
if rsync -avz "${VPS_USER}@${VPS_IP}:${VPS_BACKUP_DIR}/" "${LOCAL_BACKUP_DIR}/"; then
    log "Pull from $VPS_IP successful."
else
    log "ERROR: Pull from $VPS_IP failed."
    exit 1
fi

# Clean local backups older than 30 days
find "$LOCAL_BACKUP_DIR" -name "*.gz" -mtime +30 -delete 2>/dev/null || true
log "Local cleanup complete (removed files older than 30 days)."

log "=== Backup finished ==="
