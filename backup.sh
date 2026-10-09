#!/bin/bash

# Configuration
BACKUP_DIR="/root/backups"
PROJECT_PATH="/root/project"
GDRIVE_REMOTE="gdrive:VPS-Backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
ARCHIVE_NAME="vps_backup_${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"
cd "$PROJECT_PATH" || exit 1

echo "Stopping containers briefly for a clean, consistent backup..."
docker compose stop 2>/dev/null

echo "Creating backup archive of available local data directories..."
# Build the tar command dynamically based on what actually exists
BACKUP_ITEMS=""
for dir in vaultwarden-data vikunja-data filebrowser-data n8n-data wiki-data wiki-config ghost-content uptime-kuma-data stirling-pdf-training stirling-pdf-configs; do
    if [ -d "$dir" ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS ./$dir"
    fi
done

if [ -z "$BACKUP_ITEMS" ]; then
    echo "Error: No data directories found to back up!"
    docker compose up -d 2>/dev/null
    exit 1
fi

# Create the archive
tar -czvf "$BACKUP_DIR/$ARCHIVE_NAME" $BACKUP_ITEMS

echo "Restarting containers..."
docker compose up -d 2>/dev/null

echo "Uploading backup to Google Drive..."
rclone copy "$BACKUP_DIR/$ARCHIVE_NAME" "$GDRIVE_REMOTE/"

# Cleanup local backups older than 7 days
find "$BACKUP_DIR" -name "vps_backup_*.tar.gz" -mtime +7 -delete

echo "=== Backup completed and uploaded successfully: $ARCHIVE_NAME ==="