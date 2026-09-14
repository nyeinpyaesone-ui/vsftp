#!/bin/bash

BACKUP_DIR="/backup/unifi"
DATE=$(date +%Y%m%d_%H%M%S)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create backup directory
mkdir -p $BACKUP_DIR

echo "Starting UniFi Network OS backup at $DATE..."

# Backup UniFi configuration
echo "Backing up UniFi configuration..."
docker exec unifi-network-application tar czf /tmp/unifi_backup_$DATE.tar.gz /config
docker cp unifi-network-application:/tmp/unifi_backup_$DATE.tar.gz $BACKUP_DIR/
docker exec unifi-network-application rm /tmp/unifi_backup_$DATE.tar.gz

# Backup database
echo "Backing up MongoDB database..."
docker exec unifi-db mongodump --archive=/tmp/db_backup_$DATE.archive --db unifi
docker cp unifi-db:/tmp/db_backup_$DATE.archive $BACKUP_DIR/
docker exec unifi-db rm /tmp/db_backup_$DATE.archive

# Copy to vsftpd shared storage for FTP access
echo "Copying backups to shared storage..."
mkdir -p $SCRIPT_DIR/unifi-storage/backups
cp $BACKUP_DIR/unifi_backup_$DATE.tar.gz $SCRIPT_DIR/unifi-storage/backups/
cp $BACKUP_DIR/db_backup_$DATE.archive $SCRIPT_DIR/unifi-storage/backups/

# Clean up old backups (keep last 7 days)
echo "Cleaning up old backups..."
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.archive" -mtime +7 -delete
find $SCRIPT_DIR/unifi-storage/backups -name "*.tar.gz" -mtime +7 -delete
find $SCRIPT_DIR/unifi-storage/backups -name "*.archive" -mtime +7 -delete

echo "Backup completed successfully: $DATE"
echo "Backup files location: $BACKUP_DIR"
echo "FTP accessible location: $SCRIPT_DIR/unifi-storage/backups/"
