#!/bin/bash
#===============================================================================
# UniFi Automated Backup Script with Rate-Limited FTP Upload
# This script backs up UniFi configuration to the shared storage and optionally
# uploads to external FTP with I/O rate limiting to prevent system overload.
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/unifi-storage/backups"
LOG_FILE="${SCRIPT_DIR}/backup.log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="unifi-backup-${TIMESTAMP}.unf"

# Load environment variables if .env exists
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    source "${SCRIPT_DIR}/.env"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

info() {
    log "${GREEN}INFO: $1${NC}"
}

warn() {
    log "${YELLOW}WARN: $1${NC}"
}

#-------------------------------------------------------------------------------
# Step 1: Trigger UniFi Backup via API or CLI
#-------------------------------------------------------------------------------
trigger_backup() {
    info "Triggering UniFi backup..."
    
    # Method 1: Using curl to UniFi API (requires authentication)
    # Note: You need to set up API credentials first
    CONTROLLER_URL="https://localhost:8443"
    
    # Check if controller is running
    if ! docker ps --format '{{.Names}}' | grep -q "unifi-controller"; then
        error_exit "UniFi controller container not running"
    fi
    
    # Try to get backup from container's backup directory
    # UniFi automatically creates backups in /config/data/backup
    info "Checking for existing backups in UniFi container..."
    
    # List recent backups
    BACKUP_COUNT=$(docker exec unifi-controller ls -1 /config/data/backup/*.unf 2>/dev/null | wc -l || echo "0")
    
    if [[ "$BACKUP_COUNT" -gt 0 ]]; then
        # Get the most recent backup
        LATEST_BACKUP=$(docker exec unifi-controller ls -t /config/data/backup/*.unf 2>/dev/null | head -1)
        info "Found existing backup: $LATEST_BACKUP"
        
        # Copy to shared storage
        docker cp "unifi-controller:${LATEST_BACKUP}" "${BACKUP_DIR}/${BACKUP_FILE}"
        info "Backup copied to shared storage: ${BACKUP_DIR}/${BACKUP_FILE}"
    else
        warn "No existing backup found. Creating new backup via API..."
        
        # Create new backup via API (requires login first)
        # This is a simplified example - production should use proper auth
        if command -v curl &> /dev/null; then
            # Note: Actual implementation requires session cookie from login
            # For now, we'll wait for auto-backup or manual trigger
            warn "Manual backup trigger required via UniFi web interface"
            warn "Or configure API credentials in the script"
        fi
        
        error_exit "No backup available. Please create one manually in UniFi UI first."
    fi
}

#-------------------------------------------------------------------------------
# Step 2: Retention Policy - Keep only last N backups
#-------------------------------------------------------------------------------
apply_retention_policy() {
    local KEEP_BACKUPS=${1:-7}
    
    info "Applying retention policy: keeping last $KEEP_BACKUPS backups..."
    
    cd "$BACKUP_DIR"
    
    # Count backup files
    BACKUP_COUNT=$(ls -1 *.unf 2>/dev/null | wc -l)
    
    if [[ $BACKUP_COUNT -gt $KEEP_BACKUPS ]]; then
        DELETE_COUNT=$((BACKUP_COUNT - KEEP_BACKUPS))
        info "Removing $DELETE_COUNT old backup(s)..."
        
        # Remove oldest backups
        ls -1t *.unf | tail -n "$DELETE_COUNT" | xargs rm -f
        info "Retention policy applied successfully"
    else
        info "Backup count ($BACKUP_COUNT) within retention limit ($KEEP_BACKUPS)"
    fi
}

#-------------------------------------------------------------------------------
# Step 3: Optional - Upload to External FTP with Rate Limiting
#-------------------------------------------------------------------------------
upload_to_external_ftp() {
    if [[ "${EXTERNAL_FTP_ENABLED:-false}" != "true" ]]; then
        info "External FTP upload disabled (set EXTERNAL_FTP_ENABLED=true to enable)"
        return 0
    fi
    
    info "Uploading backup to external FTP server with rate limiting..."
    
    EXTERNAL_FTP_HOST="${EXTERNAL_FTP_HOST:-}"
    EXTERNAL_FTP_USER="${EXTERNAL_FTP_USER:-}"
    EXTERNAL_FTP_PASS="${EXTERNAL_FTP_PASS:-}"
    
    if [[ -z "$EXTERNAL_FTP_HOST" ]]; then
        warn "EXTERNAL_FTP_HOST not configured, skipping upload"
        return 0
    fi
    
    # Use lftp with rate limiting (50KB/s)
    if command -v lftp &> /dev/null; then
        lftp -c <<EOF
open -u ${EXTERNAL_FTP_USER},${EXTERNAL_FTP_PASS} ${EXTERNAL_FTP_HOST}
set ftp:limit-rate 51200
set net:max-retries 3
set net:timeout 30
cd /backups
put ${BACKUP_DIR}/${BACKUP_FILE}
bye
EOF
        info "Backup uploaded to external FTP: $EXTERNAL_FTP_HOST"
    else
        warn "lftp not installed, using standard ftp (no rate limiting)..."
        # Fallback to standard ftp (less reliable, no rate limiting)
        ftp -inv "$EXTERNAL_FTP_HOST" <<EOF
user ${EXTERNAL_FTP_USER} ${EXTERNAL_FTP_PASS}
binary
put ${BACKUP_DIR}/${BACKUP_FILE}
bye
EOF
    fi
}

#-------------------------------------------------------------------------------
# Step 4: Verify Backup Integrity
#-------------------------------------------------------------------------------
verify_backup() {
    info "Verifying backup integrity..."
    
    BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"
    
    if [[ ! -f "$BACKUP_PATH" ]]; then
        error_exit "Backup file not found: $BACKUP_PATH"
    fi
    
    # Check file size (should be > 10KB for valid backup)
    FILE_SIZE=$(stat -c%s "$BACKUP_PATH" 2>/dev/null || stat -f%z "$BACKUP_PATH" 2>/dev/null)
    
    if [[ $FILE_SIZE -lt 10240 ]]; then
        error_exit "Backup file too small (${FILE_SIZE} bytes). Possible corruption."
    fi
    
    info "Backup verified: ${FILE_SIZE} bytes"
    
    # Calculate checksum for future verification
    if command -v sha256sum &> /dev/null; then
        CHECKSUM=$(sha256sum "$BACKUP_PATH" | awk '{print $1}')
        echo "${CHECKSUM}  ${BACKUP_FILE}" >> "${BACKUP_DIR}/checksums.txt"
        info "SHA256 checksum recorded: ${CHECKSUM}"
    fi
}

#-------------------------------------------------------------------------------
# Step 5: Send Notification (Optional)
#-------------------------------------------------------------------------------
send_notification() {
    if [[ "${NOTIFY_ENABLED:-false}" != "true" ]]; then
        return 0
    fi
    
    info "Sending backup notification..."
    
    # Example: Send email notification
    if command -v mail &> /dev/null && [[ -n "${NOTIFY_EMAIL:-}" ]]; then
        echo "UniFi backup completed successfully at $(date)" | \
            mail -s "UniFi Backup Success - ${TIMESTAMP}" "$NOTIFY_EMAIL"
        info "Email notification sent to $NOTIFY_EMAIL"
    fi
    
    # Example: Send webhook notification (Slack, Discord, etc.)
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        curl -s -X POST "$WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{
                \"text\": \"✅ UniFi Backup Complete\",
                \"attachments\": [{
                    \"color\": \"good\",
                    \"fields\": [
                        {\"title\": \"Timestamp\", \"value\": \"${TIMESTAMP}\", \"short\": true},
                        {\"title\": \"File Size\", \"value\": \"$(stat -c%s ${BACKUP_PATH} 2>/dev/null || echo 'N/A') bytes\", \"short\": true}
                    ]
                }]
            }" || warn "Failed to send webhook notification"
    fi
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------
main() {
    echo "==============================================================================="
    echo "  UniFi Automated Backup with Rate-Limited Storage"
    echo "==============================================================================="
    echo ""
    
    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"
    
    # Execute backup steps
    trigger_backup
    verify_backup
    apply_retention_policy 7  # Keep last 7 backups
    upload_to_external_ftp
    send_notification
    
    echo ""
    echo "==============================================================================="
    info "Backup completed successfully!"
    echo "  Backup File: ${BACKUP_DIR}/${BACKUP_FILE}"
    echo "  Log File: $LOG_FILE"
    echo "==============================================================================="
}

# Run main function
main "$@"
