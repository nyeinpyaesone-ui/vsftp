#!/bin/bash

#==============================================================================
# UniFi Network OS - Automated Backup Script with SHA256 Verification
# Backs up UniFi config to shared storage and optionally uploads via FTP
#==============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${BASE_DIR}/.env"
BACKUP_DIR="${BASE_DIR}/storage/backups"
CONFIG_DIR="${BASE_DIR}/config"
LOG_DIR="${BASE_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="unifi_backup_${TIMESTAMP}"
RETENTION_DAYS=7

# Load environment variables
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    echo "ERROR: .env file not found. Run setup.sh first."
    exit 1
fi

# Logging
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "${LOG_DIR}/backup.log"
}

info() { log "INFO" "$@"; }
success() { log "SUCCESS" "$@"; }
warn() { log "WARNING" "$@"; }
error() { log "ERROR" "$@"; exit 1; }

#==============================================================================
# Backup Functions
#==============================================================================

create_backup() {
    info "Creating backup: ${BACKUP_NAME}"
    
    local temp_backup="/tmp/${BACKUP_NAME}.tar.gz"
    
    # Create compressed backup of config directory
    tar -czf "$temp_backup" -C "$BASE_DIR" config/
    
    # Generate SHA256 checksum
    sha256sum "$temp_backup" > "${temp_backup}.sha256"
    
    # Move to backup directory
    mv "$temp_backup" "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    mv "${temp_backup}.sha256" "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.sha256"
    
    success "Backup created: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    echo "  Size: $(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)"
    echo "  SHA256: $(cat "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.sha256" | awk '{print $1}')"
}

verify_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
    fi
    
    if [[ ! -f "${backup_file}.sha256" ]]; then
        warn "Checksum file not found for: $backup_file"
        return 1
    fi
    
    info "Verifying backup integrity..."
    cd "$(dirname "$backup_file")"
    
    if sha256sum -c "$(basename "${backup_file}.sha256")" &> /dev/null; then
        success "Backup verification passed: $(basename "$backup_file")"
        return 0
    else
        error "Backup verification FAILED: $(basename "$backup_file")"
        return 1
    fi
}

upload_to_ftp() {
    local backup_file="$1"
    local checksum_file="${backup_file}.sha256"
    
    if [[ -z "${FTP_USER:-}" || -z "${FTP_PASSWORD:-}" ]]; then
        warn "FTP credentials not configured. Skipping FTP upload."
        return 0
    fi
    
    info "Uploading backup to FTP server..."
    
    # Use curl for FTP upload
    if curl -T "$backup_file" \
         -u "${FTP_USER}:${FTP_PASSWORD}" \
         "ftp://${HOST_IP:-localhost}/backups/" &> /dev/null; then
        success "Uploaded backup to FTP: $(basename "$backup_file")"
    else
        warn "FTP upload failed for backup file"
    fi
    
    if curl -T "$checksum_file" \
         -u "${FTP_USER}:${FTP_PASSWORD}" \
         "ftp://${HOST_IP:-localhost}/backups/" &> /dev/null; then
        success "Uploaded checksum to FTP: $(basename "$checksum_file")"
    else
        warn "FTP upload failed for checksum file"
    fi
}

cleanup_old_backups() {
    info "Cleaning up backups older than ${RETENTION_DAYS} days..."
    
    local deleted=0
    while IFS= read -r -d '' file; do
        rm -f "$file" "${file}.sha256"
        ((deleted++)) || true
    done < <(find "$BACKUP_DIR" -name "unifi_backup_*.tar.gz" -mtime +${RETENTION_DAYS} -print0 2>/dev/null)
    
    if [[ $deleted -gt 0 ]]; then
        success "Deleted $deleted old backup(s)"
    else
        info "No old backups to delete"
    fi
}

restore_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
    fi
    
    # Verify first
    verify_backup "$backup_file" || exit 1
    
    info "Restoring from backup: $(basename "$backup_file")"
    
    # Stop UniFi controller
    info "Stopping UniFi controller..."
    cd "$BASE_DIR"
    docker compose stop unifi-controller || true
    
    # Extract backup
    info "Extracting backup..."
    tar -xzf "$backup_file" -C "$BASE_DIR"
    
    # Start UniFi controller
    info "Starting UniFi controller..."
    docker compose start unifi-controller
    
    success "Restore completed! UniFi controller is starting..."
    info "Wait 2-3 minutes for full initialization."
}

list_backups() {
    echo ""
    echo "Available Backups:"
    echo "=================="
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        echo "No backups found."
        return
    fi
    
    local count=0
    while IFS= read -r -d '' file; do
        ((count++)) || true
        local size=$(du -h "$file" | cut -f1)
        local date=$(stat -c '%y' "$file" | cut -d' ' -f1)
        local verified="❓"
        
        if sha256sum -c "${file}.sha256" &> /dev/null 2>&1; then
            verified="✅"
        else
            verified="❌"
        fi
        
        printf "%3d. [%s] %s - %s (%s)\n" "$count" "$verified" "$date" "$(basename "$file")" "$size"
    done < <(find "$BACKUP_DIR" -name "unifi_backup_*.tar.gz" -print0 2>/dev/null | sort -z -r)
    
    echo ""
    echo "Total: $count backup(s)"
}

#==============================================================================
# Main Execution
#==============================================================================

show_help() {
    cat << EOF
UniFi Network OS - Backup Management Tool

Usage: $(basename "$0") [COMMAND]

Commands:
  create      Create a new backup (default)
  verify      Verify latest backup integrity
  upload      Upload latest backup to FTP
  list        List all available backups
  restore     Restore from specified backup file
  cleanup     Remove old backups (older than $RETENTION_DAYS days)
  help        Show this help message

Examples:
  $(basename "$0")                    # Create new backup
  $(basename "$0") create             # Create new backup
  $(basename "$0") verify             # Verify latest backup
  $(basename "$0") list               # List all backups
  $(basename "$0") restore /path/to/backup.tar.gz
  $(basename "$0") cleanup            # Delete old backups

EOF
}

main() {
    local command="${1:-create}"
    
    case "$command" in
        create)
            create_backup
            upload_to_ftp "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
            cleanup_old_backups
            ;;
        verify)
            local latest=$(ls -t "${BACKUP_DIR}"/unifi_backup_*.tar.gz 2>/dev/null | head -n1)
            if [[ -n "$latest" ]]; then
                verify_backup "$latest"
            else
                error "No backups found to verify"
            fi
            ;;
        upload)
            local latest=$(ls -t "${BACKUP_DIR}"/unifi_backup_*.tar.gz 2>/dev/null | head -n1)
            if [[ -n "$latest" ]]; then
                upload_to_ftp "$latest"
            else
                error "No backups found to upload"
            fi
            ;;
        list)
            list_backups
            ;;
        restore)
            if [[ -z "${2:-}" ]]; then
                error "Please specify a backup file to restore"
            fi
            restore_backup "$2"
            ;;
        cleanup)
            cleanup_old_backups
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $command. Use 'help' for usage information."
            ;;
    esac
}

main "$@"
