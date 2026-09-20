#!/bin/bash
#===============================================================================
# UniFi Network OS - Enterprise File System Integration
# Professional Network Engineer Deployment Script
# Auto-Dynamic Configuration with Hardware Analysis & Enforcement
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

#-------------------------------------------------------------------------------
# Logging Functions
#-------------------------------------------------------------------------------
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#-------------------------------------------------------------------------------
# Enforcement: Root Privilege Check
#-------------------------------------------------------------------------------
enforce_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (sudo)"
        exit 1
    fi
    log_success "Root privileges verified"
}

#-------------------------------------------------------------------------------
# Enforcement: Docker Validation
#-------------------------------------------------------------------------------
validate_docker() {
    log_info "Validating Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Start Docker and try again."
        exit 1
    fi
    
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3)
    log_success "Docker version: $DOCKER_VERSION"
    
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose plugin not found. Install docker-compose-plugin."
        exit 1
    fi
    
    COMPOSE_VERSION=$(docker compose version | cut -d' ' -f4)
    log_success "Docker Compose version: $COMPOSE_VERSION"
}

#-------------------------------------------------------------------------------
# Hardware Analysis: Dynamic Resource Calculation
#-------------------------------------------------------------------------------
analyze_hardware() {
    log_info "Analyzing system hardware..."
    
    # Get total RAM in GB
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
    
    # Get CPU cores
    CPU_CORES=$(nproc)
    
    # Get available disk space in GB
    AVAIL_DISK_KB=$(df -P "$PROJECT_ROOT" | tail -1 | awk '{print $4}')
    AVAIL_DISK_GB=$((AVAIL_DISK_KB / 1024 / 1024))
    
    log_info "Detected: ${TOTAL_RAM_GB}GB RAM, ${CPU_CORES} CPU cores, ${AVAIL_DISK_GB}GB disk available"
    
    # Enforcement: Minimum Requirements
    if [[ $TOTAL_RAM_GB -lt 2 ]]; then
        log_error "Insufficient RAM. Minimum 2GB required, detected ${TOTAL_RAM_GB}GB"
        exit 1
    fi
    
    if [[ $CPU_CORES -lt 2 ]]; then
        log_error "Insufficient CPU. Minimum 2 cores required, detected ${CPU_CORES}"
        exit 1
    fi
    
    if [[ $AVAIL_DISK_GB -lt 15 ]]; then
        log_error "Insufficient disk space. Minimum 15GB required, detected ${AVAIL_DISK_GB}GB"
        exit 1
    fi
    
    log_success "Hardware requirements met"
    
    # Dynamic Resource Allocation (Professional Tuning)
    # MongoDB: 25% of RAM (max 2GB, min 512MB), 30% of CPU
    DB_MEM_LIMIT=$((TOTAL_RAM_GB * 25 / 100))
    [[ $DB_MEM_LIMIT -gt 2 ]] && DB_MEM_LIMIT=2
    [[ $DB_MEM_LIMIT -lt 1 ]] && DB_MEM_LIMIT=1
    DB_MEM_RESERVE=$((DB_MEM_LIMIT / 2))
    DB_CPU_LIMIT=$(echo "scale=1; $CPU_CORES * 0.3" | bc)
    DB_CPU_RESERVE=$(echo "scale=1; $DB_CPU_LIMIT / 2" | bc)
    DB_CACHE_SIZE=$(echo "scale=1; $DB_MEM_LIMIT * 0.6" | bc)
    
    # UniFi Controller: 35% of RAM (max 3GB, min 1GB), 50% of CPU
    UNIFI_MEM_LIMIT=$((TOTAL_RAM_GB * 35 / 100))
    [[ $UNIFI_MEM_LIMIT -gt 3 ]] && UNIFI_MEM_LIMIT=3
    [[ $UNIFI_MEM_LIMIT -lt 1 ]] && UNIFI_MEM_LIMIT=1
    UNIFI_MEM_STARTUP=$((UNIFI_MEM_LIMIT / 2))
    [[ $UNIFI_MEM_STARTUP -lt 1 ]] && UNIFI_MEM_STARTUP=1
    UNIFI_CPU_LIMIT=$(echo "scale=1; $CPU_CORES * 0.5" | bc)
    UNIFI_CPU_RESERVE=$(echo "scale=1; $UNIFI_CPU_LIMIT / 2" | bc)
    
    # vsftpd: Fixed lightweight allocation
    FTP_MEM_LIMIT="256M"
    FTP_MEM_RESERVE="128M"
    FTP_CPU_LIMIT="0.5"
    FTP_CPU_RESERVE="0.25"
    
    log_info "Resource allocation calculated:"
    log_info "  MongoDB: ${DB_MEM_LIMIT}GB RAM, ${DB_CPU_LIMIT} CPU"
    log_info "  UniFi: ${UNIFI_MEM_LIMIT}GB RAM, ${UNIFI_CPU_LIMIT} CPU"
    log_info "  vsftpd: ${FTP_MEM_LIMIT} RAM, ${FTP_CPU_LIMIT} CPU"
}

#-------------------------------------------------------------------------------
# Network Analysis: Auto-Detect IP & Port Conflicts
#-------------------------------------------------------------------------------
analyze_network() {
    log_info "Analyzing network configuration..."
    
    # Auto-detect primary IP (exclude loopback and docker interfaces)
    HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || \
              hostname -I | awk '{print $1}' || \
              echo "127.0.0.1")
    
    if [[ "$HOST_IP" == "127.0.0.1" ]]; then
        log_warn "Could not auto-detect public IP. Using 127.0.0.1"
    else
        log_success "Detected server IP: $HOST_IP"
    fi
    
    # Port conflict detection (portable method)
    declare -a PORTS=(8443 8080 8448 10001 3478 21 27017)
    for PORT in "${PORTS[@]}"; do
        # Try multiple methods for portability
        if command -v ss &>/dev/null; then
            if ss -tuln | grep -q ":$PORT "; then
                log_error "Port $PORT is already in use. Stop the conflicting service."
                exit 1
            fi
        elif command -v netstat &>/dev/null; then
            if netstat -tuln | grep -q ":$PORT "; then
                log_error "Port $PORT is already in use. Stop the conflicting service."
                exit 1
            fi
        elif command -v lsof &>/dev/null; then
            if lsof -i :"$PORT" &>/dev/null; then
                log_error "Port $PORT is already in use. Stop the conflicting service."
                exit 1
            fi
        else
            log_warn "Cannot check port $PORT (no ss/netstat/lsof available)"
        fi
    done
    log_success "All required ports are available"
    
    # Set FTP passive port range
    FTP_PASSIVE_MIN=30000
    FTP_PASSIVE_MAX=30010
}

#-------------------------------------------------------------------------------
# Security: Generate Strong Random Passwords
#-------------------------------------------------------------------------------
generate_credentials() {
    log_info "Generating secure credentials..."
    
    # 32-character random passwords for database
    DB_ROOT_USER="unifi_root"
    DB_ROOT_PASS=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
    DB_USER="unifi_app"
    DB_USER_PASS=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
    
    # 24-character random password for FTP
    FTP_USER="unifi_backup"
    FTP_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
    
    log_success "Credentials generated securely"
}

#-------------------------------------------------------------------------------
# Configuration: Create .env File
#-------------------------------------------------------------------------------
create_env_file() {
    log_info "Creating environment configuration..."
    
    cat > "$ENV_FILE" << EOF
# =============================================================================
# UniFi Network OS - Enterprise File System Configuration
# Auto-generated by setup.sh - $(date '+%Y-%m-%d %H:%M:%S')
# =============================================================================

# -----------------------------------------------------------------------------
# Server Configuration
# -----------------------------------------------------------------------------
HOST_IP=${HOST_IP}
TIMEZONE=$(cat /etc/timezone 2>/dev/null || echo "UTC")
STORAGE_ROOT=${PROJECT_ROOT}/data

# -----------------------------------------------------------------------------
# MongoDB Database Configuration
# -----------------------------------------------------------------------------
DB_ROOT_USER=${DB_ROOT_USER}
DB_ROOT_PASS=${DB_ROOT_PASS}
DB_USER=${DB_USER}
DB_USER_PASS=${DB_USER_PASS}
DB_CACHE_SIZE=${DB_CACHE_SIZE}
DB_MEM_LIMIT=${DB_MEM_LIMIT}g
DB_MEM_RESERVE=${DB_MEM_RESERVE}g
DB_CPU_LIMIT=${DB_CPU_LIMIT}
DB_CPU_RESERVE=${DB_CPU_RESERVE}

# -----------------------------------------------------------------------------
# UniFi Controller Configuration
# -----------------------------------------------------------------------------
UNIFI_MEM_LIMIT=${UNIFI_MEM_LIMIT}g
UNIFI_MEM_STARTUP=${UNIFI_MEM_STARTUP}g
UNIFI_CPU_LIMIT=${UNIFI_CPU_LIMIT}
UNIFI_CPU_RESERVE=${UNIFI_CPU_RESERVE}

# -----------------------------------------------------------------------------
# vsftpd FTP Server Configuration
# -----------------------------------------------------------------------------
FTP_USER=${FTP_USER}
FTP_PASS=${FTP_PASS}
FTP_PASSIVE_MIN=${FTP_PASSIVE_MIN:-30000}
FTP_PASSIVE_MAX=${FTP_PASSIVE_MAX:-30010}
FTP_MAX_CLIENTS=20
FTP_MAX_PER_IP=5
FTP_RATE_LIMIT=102400
FTP_MEM_LIMIT=${FTP_MEM_LIMIT}
FTP_MEM_RESERVE=${FTP_MEM_RESERVE}
FTP_CPU_LIMIT=${FTP_CPU_LIMIT}
FTP_CPU_RESERVE=${FTP_CPU_RESERVE}
EOF

    chmod 600 "$ENV_FILE"
    log_success "Environment file created: $ENV_FILE"
}

#-------------------------------------------------------------------------------
# Setup: Create Directory Structure with Proper Permissions
#-------------------------------------------------------------------------------
setup_directories() {
    log_info "Creating directory structure..."
    
    mkdir -p "$PROJECT_ROOT/data"/{db-data,db-config,unifi-config,shared-storage,ftp-logs}
    
    # Set ownership to non-root for container security
    chown -R 1000:1000 "$PROJECT_ROOT/data"
    chmod -R 750 "$PROJECT_ROOT/data"
    
    log_success "Directory structure created with secure permissions"
}

#-------------------------------------------------------------------------------
# Deployment: Pull Images and Start Services
#-------------------------------------------------------------------------------
deploy_services() {
    log_info "Pulling Docker images..."
    cd "$PROJECT_ROOT"
    docker compose pull
    
    log_info "Starting services..."
    docker compose up -d
    
    log_info "Waiting for services to initialize (60 seconds)..."
    sleep 60
    
    # Health check verification
    if docker compose ps | grep -q "unifi-db.*healthy"; then
        log_success "MongoDB is healthy"
    else
        log_warn "MongoDB health check pending"
    fi
    
    if docker compose ps | grep -q "unifi-controller.*healthy"; then
        log_success "UniFi Controller is healthy"
    else
        log_warn "UniFi Controller still starting..."
    fi
    
    if docker compose ps | grep -q "vsftpd-server.*healthy"; then
        log_success "vsftpd Server is healthy"
    else
        log_warn "vsftpd Server health check pending"
    fi
}

#-------------------------------------------------------------------------------
# Display: Show Access Information
#-------------------------------------------------------------------------------
display_info() {
    echo ""
    echo "==============================================================================="
    echo -e "${GREEN}✓ UniFi Network OS Enterprise Setup Complete!${NC}"
    echo "==============================================================================="
    echo ""
    echo -e "${BLUE}Server IP:${NC} $HOST_IP"
    echo ""
    echo -e "${YELLOW}Access URLs:${NC}"
    echo "  UniFi Controller: https://$HOST_IP:8443"
    echo "  FTP Server:       ftps://$HOST_IP:21"
    echo ""
    echo -e "${YELLOW}Database Credentials (Save These!):${NC}"
    echo "  Root User:  $DB_ROOT_USER"
    echo "  Root Pass:  [REDACTED - Check .env file]"
    echo "  App User:   $DB_USER"
    echo "  App Pass:   [REDACTED - Check .env file]"
    echo ""
    echo -e "${YELLOW}FTP Credentials (Save These!):${NC}"
    echo "  Username:   $FTP_USER"
    echo "  Password:   [REDACTED - Check .env file]"
    echo "  Protocol:   FTPS (FTP over SSL/TLS)"
    echo ""
    echo -e "${YELLOW}Storage Locations:${NC}"
    echo "  Shared Storage: $PROJECT_ROOT/data/shared-storage"
    echo "  UniFi Config:   $PROJECT_ROOT/data/unifi-config"
    echo "  Database:       $PROJECT_ROOT/data/db-data"
    echo ""
    echo -e "${RED}IMPORTANT: Credentials stored securely in .env file. Keep it safe!${NC}"
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------
main() {
    echo "==============================================================================="
    echo "  UniFi Network OS - Enterprise File System Integration"
    echo "  Professional Network Engineer Deployment"
    echo "==============================================================================="
    echo ""
    
    enforce_root
    validate_docker
    analyze_hardware
    analyze_network
    generate_credentials
    create_env_file
    setup_directories
    deploy_services
    display_info
}

main "$@"
