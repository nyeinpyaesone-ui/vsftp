# Backup Strategy

## Overview
This document outlines the backup and recovery procedures for the UniFi Enterprise File System.

## Critical Data to Backup
1. **MongoDB Data**: User accounts, configurations, and file metadata
2. **UniFi Controller Data**: Network configurations and device settings
3. **FTP User Data**: Stored files and user configurations
4. **Environment Configuration**: `.env` files with credentials

## Automated Backup Script
```bash
#!/bin/bash
# backup.sh - Automated backup script
BACKUP_DIR="/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup MongoDB
docker exec mongodb mongodump --out $BACKUP_DIR/mongodb

# Backup UniFi Controller
docker cp unifi-controller:/unifi/data $BACKUP_DIR/unifi-data

# Backup FTP files
docker cp ftp-server:/home $BACKUP_DIR/ftp-files

# Backup environment files
cp .env $BACKUP_DIR/env-backup

# Compress backup
tar -czf backup_$(date +%Y%m%d_%H%M%S).tar.gz $BACKUP_DIR
```

## Recovery Procedures
1. Stop all services: `docker-compose down`
2. Restore MongoDB: `mongorestore <backup_path>`
3. Restore UniFi data: `docker cp <backup> unifi-controller:/unifi/data`
4. Restore FTP files: `docker cp <backup> ftp-server:/home`
5. Restart services: `docker-compose up -d`

## Backup Schedule Recommendations
- **Daily**: Incremental backups of file data
- **Weekly**: Full system backup
- **Monthly**: Off-site backup copy

## Testing
Test recovery procedures quarterly to ensure backup integrity.
