#!/bin/bash
# Automated backup to remote server over Tailscale
# Configure BACKUP_HOST and BACKUP_PATH below or via environment

set -euo pipefail

# Configuration - adjust these for your setup
BACKUP_HOST="${BACKUP_HOST:-}"
BACKUP_USER="${BACKUP_USER:-$USER}"
BACKUP_PATH="${BACKUP_PATH:-}"
LOG_FILE="$HOME/.local/state/backup.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Skip unless configured
if [[ -z "${BACKUP_HOST}" || -z "${BACKUP_PATH}" ]]; then
    echo "$(date): Backup skipped - set BACKUP_HOST and BACKUP_PATH" >> "$LOG_FILE"
    exit 0
fi

# Check connectivity
if ! ping -c 1 -W 2 "$BACKUP_HOST" &>/dev/null; then
    echo "$(date): Backup skipped - ${BACKUP_HOST} not reachable" >> "$LOG_FILE"
    exit 0
fi

# Directories to backup
SOURCES=(
    "$HOME/Documents"
    "$HOME/Projects"
    "$HOME/arch-hyprland-setup"
    "$HOME/.config"
)

# Exclude patterns (caches, build artifacts, large app data)
EXCLUDES=(
    --exclude='*.cache'
    --exclude='*Cache*'
    --exclude='node_modules'
    --exclude='__pycache__'
    --exclude='.git/objects'
    --exclude='*.pyc'
    --exclude='.venv'
    --exclude='target'
    --exclude='chromium'
    --exclude='Slack'
    --exclude='Code/Cache*'
)

echo "$(date): Starting backup to ${BACKUP_HOST}" >> "$LOG_FILE"

for src in "${SOURCES[@]}"; do
    if [[ -e "$src" ]]; then
        rsync -avz --delete "${EXCLUDES[@]}" \
            "$src" "${BACKUP_USER}@${BACKUP_HOST}:${BACKUP_PATH}/" 2>> "$LOG_FILE"
    fi
done

echo "$(date): Backup completed" >> "$LOG_FILE"
