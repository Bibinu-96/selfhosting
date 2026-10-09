#!/bin/bash

# Configuration
RESTORE_TEMP="/tmp/restore_temp"
PROJECT_PATH="/root/project"
GDRIVE_REMOTE="gdrive:VPS-Backups"

echo "=== Available Backups on Google Drive ==="
rclone ls "$GDRIVE_REMOTE"
echo "========================================"

# Prompt user for the backup filename
read -p "Enter the exact backup filename to restore (e.g., vps_backup_2026-10-08_19-19-23.tar.gz): " ARCHIVE_NAME

if [ -z "$ARCHIVE_NAME" ]; then
    echo "Error: No filename provided. Exiting."
    exit 1
fi

echo "Creating temp directory..."
mkdir -p "$RESTORE_TEMP"

echo "Downloading $ARCHIVE_NAME from Google Drive..."
rclone copyto "$GDRIVE_REMOTE/$ARCHIVE_NAME" "$RESTORE_TEMP/backup.tar.gz"

if [ ! -f "$RESTORE_TEMP/backup.tar.gz" ]; then
    echo "Error: Failed to download the backup file. Check the filename and try again."
    exit 1
fi

echo "Stopping running Docker containers..."
cd "$PROJECT_PATH" || exit 1
docker compose stop 2>/dev/null

echo "Ensuring all local data directories exist..."
mkdir -p ./vaultwarden-data ./vikunja-data ./filebrowser-data ./n8n-data ./wiki-data ./wiki-config ./ghost-content ./uptime-kuma-data ./stirling-pdf-training ./stirling-pdf-configs

echo "Extracting backup archive..."
tar -xzvf "$RESTORE_TEMP/backup.tar.gz" -C "$PROJECT_PATH" 2>/dev/null

echo "Fixing file permissions for container users..."
# Node.js / Java based apps need UID 1000
[ -d "./n8n-data" ] && chown -R 1000:1000 ./n8n-data 2>/dev/null
[ -d "./ghost-content" ] && chown -R 1000:1000 ./ghost-content 2>/dev/null
[ -d "./wiki-data" ] && chown -R 1000:1000 ./wiki-data 2>/dev/null
[ -d "./wiki-config" ] && chown -R 1000:1000 ./wiki-config 2>/dev/null
[ -d "./uptime-kuma-data" ] && chown -R 1000:1000 ./uptime-kuma-data 2>/dev/null
[ -d "./stirling-pdf-training" ] && chown -R 1000:1000 ./stirling-pdf-training 2>/dev/null
[ -d "./stirling-pdf-configs" ] && chown -R 1000:1000 ./stirling-pdf-configs 2>/dev/null

# Root-based apps
[ -d "./vaultwarden-data" ] && { chown -R root:root ./vaultwarden-data 2>/dev/null; chmod -R 755 ./vaultwarden-data 2>/dev/null; }
[ -d "./vikunja-data" ] && { chown -R root:root ./vikunja-data 2>/dev/null; chmod -R 755 ./vikunja-data 2>/dev/null; }

echo "Cleaning up temporary files..."
rm -rf "$RESTORE_TEMP"

echo "Starting Docker containers..."
docker compose up -d

echo "=== Restore completed successfully! ==="