#!/bin/bash
#===============================================================================
# UniFi Network OS - Automated Backup Script
# Features: SHA256 Verification, FTP Upload, 7-Day Retention
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PARENT_DIR/.env"
BACKUP_DIR="$PARENT_DIR/data/backups"
SHARED_STORAGE="$PARENT_DIR/data/shared-storage"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="unifi-backup-${TIMESTAMP}.tar.gz"

# Load environment variables
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    echo -e "${RED}[ERROR]${NC} Environment file not found: $ENV_FILE"
    exit 1
fi

log_info() { echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }

#-------------------------------------------------------------------------------
# Create Backup Archive
#-------------------------------------------------------------------------------
create_backup() {
    log_info "Creating backup archive..."
    
    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"
    
    # Create tarball of UniFi data
    tar -czf "$BACKUP_DIR/$BACKUP_NAME" \
        -C "$PARENT_DIR/data" \
        unifi mongo mongo-config 2>/dev/null || {
        log_error "Failed to create backup archive"
        exit 1
    }
    
    # Generate SHA256 checksum
    sha256sum "$BACKUP_DIR/$BACKUP_NAME" > "$BACKUP_DIR/${BACKUP_NAME}.sha256"
    
    log_success "Backup created: $BACKUP_NAME"
    log_info "Checksum: $(cat "$BACKUP_DIR/${BACKUP_NAME}.sha256" | awk '{print $1}')"
}

#-------------------------------------------------------------------------------
# Verify Backup Integrity
#-------------------------------------------------------------------------------
verify_backup() {
    log_info "Verifying backup integrity..."
    
    cd "$BACKUP_DIR"
    
    if sha256sum -c "${BACKUP_NAME}.sha256" > /dev/null 2>&1; then
        log_success "Backup integrity verified (SHA256 match)"
        return 0
    else
        log_error "Backup integrity check failed!"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Upload to FTP Storage
#-------------------------------------------------------------------------------
upload_to_ftp() {
    log_info "Uploading backup to FTP storage..."
    
    local FTP_HOST="${SERVER_IP:-localhost}"
    local FTP_USER="${FTP_USER:-unifi_storage}"
    local FTP_PASS="${FTP_PASS}"
    
    # Copy to shared storage (mounted by vsftpd)
    cp "$BACKUP_DIR/$BACKUP_NAME" "$SHARED_STORAGE/"
    cp "$BACKUP_DIR/${BACKUP_NAME}.sha256" "$SHARED_STORAGE/"
    
    log_success "Backup uploaded to FTP storage: $SHARED_STORAGE"
}

#-------------------------------------------------------------------------------
# Cleanup Old Backups (Retention Policy)
#-------------------------------------------------------------------------------
cleanup_old_backups() {
    log_info "Cleaning up backups older than $RETENTION_DAYS days..."
    
    find "$BACKUP_DIR" -name "unifi-backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name "unifi-backup-*.sha256" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$SHARED_STORAGE" -name "unifi-backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$SHARED_STORAGE" -name "unifi-backup-*.sha256" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    local remaining=$(ls -1 "$BACKUP_DIR"/unifi-backup-*.tar.gz 2>/dev/null | wc -l)
    log_info "Remaining backups: $remaining"
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------
main() {
    echo "==============================================================================="
    echo "UniFi Network OS - Automated Backup"
    echo "==============================================================================="
    
    create_backup
    verify_backup || exit 1
    upload_to_ftp
    cleanup_old_backups
    
    echo ""
    log_success "Backup completed successfully!"
    echo "Location: $BACKUP_DIR/$BACKUP_NAME"
    echo "FTP Access: ftp://$SERVER_IP/ (user: $FTP_USER)"
    echo "==============================================================================="
}

main "$@"
