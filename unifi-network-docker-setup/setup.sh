#!/bin/bash
#===============================================================================
# UniFi Network OS - Auto-Dynamic Setup with Enforcement & Rate Limiting
# This script includes comprehensive gap analysis, error prevention, and 
# resource rate limiting policies to ensure stable operation.
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
LOG_FILE="${SCRIPT_DIR}/setup.log"

#===============================================================================
# GAP ANALYSIS & PRE-FLIGHT CHECKS
#===============================================================================

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

warn() {
    log "${YELLOW}WARNING: $1${NC}"
}

info() {
    log "${BLUE}INFO: $1${NC}"
}

success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

#-------------------------------------------------------------------------------
# Gap Check 1: Root Privileges Enforcement
#-------------------------------------------------------------------------------
check_root() {
    info "Checking root privileges..."
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root. Use: sudo $0"
    fi
    success "Root privileges confirmed"
}

#-------------------------------------------------------------------------------
# Gap Check 2: Docker Installation & Version
#-------------------------------------------------------------------------------
check_docker() {
    info "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        error_exit "Docker is not installed. Please install Docker first."
    fi
    
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | cut -d',' -f1)
    info "Docker version: $DOCKER_VERSION"
    
    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not running. Start it with: systemctl start docker"
    fi
    
    # Check Docker Compose plugin
    if ! docker compose version &> /dev/null; then
        error_exit "Docker Compose plugin not found. Install docker-compose-plugin."
    fi
    
    success "Docker and Compose verified"
}

#-------------------------------------------------------------------------------
# Gap Check 3: Hardware Resource Validation (Prevent Under-provisioning)
#-------------------------------------------------------------------------------
check_resources() {
    info "Validating hardware resources..."
    
    # Disk Space Check (Minimum 15GB for safe operation with backups)
    DISK_AVAILABLE=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ $DISK_AVAILABLE -lt 15 ]]; then
        error_exit "Insufficient disk space. Available: ${DISK_AVAILABLE}GB, Required: 15GB minimum"
    fi
    info "Disk space OK: ${DISK_AVAILABLE}GB available"
    
    # Memory Check (Minimum 2GB RAM recommended)
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
    
    if [[ $TOTAL_MEM_GB -lt 2 ]]; then
        warn "Low memory detected: ${TOTAL_MEM_GB}GB. Minimum 2GB recommended for stable operation."
        warn "UniFi may experience OOM kills under load. Consider adding swap space."
        
        # Check if swap exists
        SWAP_TOTAL=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
        if [[ $SWAP_TOTAL -lt 2097152 ]]; then # 2GB in KB
            error_exit "No adequate swap space. Add at least 2GB swap or upgrade RAM."
        fi
    fi
    info "Memory OK: ${TOTAL_MEM_GB}GB total"
    
    # CPU Core Check
    CPU_CORES=$(nproc)
    if [[ $CPU_CORES -lt 2 ]]; then
        error_exit "Insufficient CPU cores. Available: $CPU_CORES, Required: 2 minimum"
    fi
    info "CPU cores OK: $CPU_CORES cores"
}

#-------------------------------------------------------------------------------
# Gap Check 4: Port Conflict Detection (Critical for Service Startup)
#-------------------------------------------------------------------------------
check_ports() {
    info "Checking for port conflicts..."
    
    REQUIRED_PORTS=("8443" "8080" "8843" "3478" "10001" "6789" "21")
    CONFLICT_FOUND=false
    
    for PORT in "${REQUIRED_PORTS[@]}"; do
        if ss -tuln | grep -q ":$PORT "; then
            warn "Port $PORT is already in use!"
            CONFLICT_FOUND=true
        fi
    done
    
    # Check FTP passive port range
    for PORT in {21000..21010}; do
        if ss -tuln | grep -q ":$PORT "; then
            warn "FTP passive port $PORT is in use!"
            CONFLICT_FOUND=true
        fi
    done
    
    if [[ "$CONFLICT_FOUND" == "true" ]]; then
        error_exit "Port conflicts detected. Stop conflicting services or change ports in docker-compose.yml"
    fi
    
    success "All required ports are available"
}

#-------------------------------------------------------------------------------
# Gap Check 5: Existing Container Cleanup
#-------------------------------------------------------------------------------
cleanup_existing() {
    info "Checking for existing containers..."
    
    CONTAINERS=("unifi-mongo" "unifi-controller" "unifi-ftp")
    for CONTAINER in "${CONTAINERS[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
            warn "Removing existing container: $CONTAINER"
            docker stop "$CONTAINER" 2>/dev/null || true
            docker rm "$CONTAINER" 2>/dev/null || true
        fi
    done
    
    # Remove orphaned volumes if requested
    if [[ "${CLEAN_INSTALL:-false}" == "true" ]]; then
        warn "Clean install mode - removing old data..."
        rm -rf "${SCRIPT_DIR}/unifi-db-data"
        rm -rf "${SCRIPT_DIR}/unifi-data"
        rm -rf "${SCRIPT_DIR}/unifi-storage"
    fi
    
    success "Existing containers cleaned up"
}

#===============================================================================
# DYNAMIC CONFIGURATION GENERATION
#===============================================================================

generate_credentials() {
    info "Generating secure credentials..."
    
    # Auto-detect primary IP address
    HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}')
    if [[ -z "$HOST_IP" ]]; then
        HOST_IP="0.0.0.0"
        warn "Could not auto-detect IP, using 0.0.0.0 (all interfaces)"
    fi
    info "Detected server IP: $HOST_IP"
    
    # Generate strong random passwords
    MONGO_USER="unifi_admin"
    MONGO_PASS=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c32)
    FTP_USER="unifi"
    FTP_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c24)
    
    # Timezone detection
    TIMEZONE=$(cat /etc/timezone 2>/dev/null || echo "UTC")
    
    # Resource limits based on available hardware
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
    
    if [[ $TOTAL_MEM_GB -ge 8 ]]; then
        MEM_LIMIT=2048
        MEM_LIMIT_SOFT=4G
        CPU_LIMIT=4.0
    elif [[ $TOTAL_MEM_GB -ge 4 ]]; then
        MEM_LIMIT=1536
        MEM_LIMIT_SOFT=2G
        CPU_LIMIT=2.0
    else
        MEM_LIMIT=1024
        MEM_LIMIT_SOFT=1536M
        CPU_LIMIT=1.5
    fi
    
    # Create .env file
    cat > "$ENV_FILE" <<EOF
# Auto-generated by setup.sh - $(date)
# DO NOT EDIT MANUALLY - Changes will be overwritten

# Network Configuration
HOST_IP=${HOST_IP}
TIMEZONE=${TIMEZONE}

# MongoDB Credentials (Auto-generated)
MONGO_USER=${MONGO_USER}
MONGO_PASS=${MONGO_PASS}

# FTP Credentials (Auto-generated)
FTP_USER=${FTP_USER}
FTP_PASS=${FTP_PASS}
FTP_PASSIVE_PORTS=21000-21010

# Resource Limits (Auto-calculated based on hardware)
MEM_LIMIT=${MEM_LIMIT}
MEM_LIMIT_SOFT=${MEM_LIMIT_SOFT}
CPU_LIMIT=${CPU_LIMIT}

# Security Settings
PUID=1000
PGID=1000
EOF
    
    chmod 600 "$ENV_FILE"
    success "Credentials generated and saved to .env"
    
    # Display credentials ONCE
    echo ""
    echo "==============================================================================="
    echo -e "${YELLOW}⚠️  SAVE THESE CREDENTIALS NOW - THEY WILL NOT BE SHOWN AGAIN!${NC}"
    echo "==============================================================================="
    echo -e "${GREEN}UniFi Controller:${NC} https://${HOST_IP}:8443"
    echo -e "${GREEN}FTP Server:${NC}       ftp://${HOST_IP}:21"
    echo -e "${GREEN}FTP Username:${NC}     ${FTP_USER}"
    echo -e "${GREEN}FTP Password:${NC}     ${FTP_PASS}"
    echo -e "${GREEN}MongoDB User:${NC}     ${MONGO_USER}"
    echo -e "${GREEN}MongoDB Pass:${NC}     ${MONGO_PASS}"
    echo "==============================================================================="
    echo ""
}

#===============================================================================
# DIRECTORY STRUCTURE & PERMISSIONS
#===============================================================================

setup_directories() {
    info "Creating directory structure..."
    
    mkdir -p "${SCRIPT_DIR}/unifi-data"
    mkdir -p "${SCRIPT_DIR}/unifi-db-data"
    mkdir -p "${SCRIPT_DIR}/unifi-storage/backups"
    mkdir -p "${SCRIPT_DIR}/vsftpd-config"
    
    # Set secure permissions
    chmod 755 "${SCRIPT_DIR}/unifi-data"
    chmod 700 "${SCRIPT_DIR}/unifi-db-data"
    chmod 755 "${SCRIPT_DIR}/unifi-storage"
    chmod 700 "${SCRIPT_DIR}/unifi-storage/backups"
    
    # Ensure vsftpd config exists
    if [[ ! -f "${SCRIPT_DIR}/vsftpd-config/vsftpd.conf" ]]; then
        warn "vsftpd.conf not found, creating default..."
        cat > "${SCRIPT_DIR}/vsftpd-config/vsftpd.conf" <<'VSFTPD_EOF'
anonymous_enable=NO
local_enable=YES
chroot_local_user=YES
allow_writeable_chroot=NO
pasv_enable=YES
pasv_min_port=21000
pasv_max_port=21010
local_max_rate=51200
max_clients=10
max_per_ip=3
ssl_enable=YES
force_local_data_ssl=YES
force_local_logins_ssl=YES
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_ciphers=HIGH
require_ssl_reuse=NO
xferlog_enable=YES
dual_log_enable=YES
idle_session_timeout=300
data_connection_timeout=120
VSFTPD_EOF
    fi
    
    success "Directory structure created with secure permissions"
}

#===============================================================================
# SERVICE DEPLOYMENT WITH HEALTH CHECKS
#===============================================================================

deploy_services() {
    info "Deploying services with health checks..."
    
    cd "$SCRIPT_DIR"
    
    # Pull images first
    info "Pulling Docker images..."
    docker compose pull || error_exit "Failed to pull Docker images"
    
    # Start services
    info "Starting services..."
    docker compose up -d || error_exit "Failed to start services"
    
    # Wait for MongoDB to be healthy
    info "Waiting for MongoDB to initialize (up to 60 seconds)..."
    for i in {1..12}; do
        if docker inspect --format='{{.State.Health.Status}}' unifi-mongo 2>/dev/null | grep -q "healthy"; then
            success "MongoDB is healthy"
            break
        fi
        sleep 5
    done
    
    # Wait for UniFi Controller
    info "Waiting for UniFi Controller to initialize (up to 120 seconds)..."
    UNIFI_READY=false
    for i in {1..24}; do
        if docker inspect --format='{{.State.Health.Status}}' unifi-controller 2>/dev/null | grep -q "healthy"; then
            success "UniFi Controller is healthy"
            UNIFI_READY=true
            break
        fi
        sleep 5
    done
    
    if [[ "$UNIFI_READY" != "true" ]]; then
        warn "UniFi Controller health check timed out. Checking logs..."
        docker logs unifi-controller --tail 50
        error_exit "UniFi Controller failed to start properly. Check logs above."
    fi
    
    # Verify FTP service
    sleep 10
    if docker ps --format '{{.Names}}' | grep -q "unifi-ftp"; then
        success "vsftpd service started"
    else
        error_exit "vsftpd service failed to start"
    fi
    
    success "All services deployed successfully!"
}

#===============================================================================
# POST-DEPLOYMENT VERIFICATION
#===============================================================================

verify_deployment() {
    info "Running post-deployment verification..."
    
    # Check container status
    echo ""
    echo "Container Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Check network connectivity
    echo ""
    info "Testing internal network connectivity..."
    docker exec unifi-controller ping -c 2 mongo > /dev/null 2>&1 && success "UniFi can reach MongoDB" || warn "Network issue between containers"
    
    # Display access information
    echo ""
    echo "==============================================================================="
    echo -e "${GREEN}✅ DEPLOYMENT COMPLETE!${NC}"
    echo "==============================================================================="
    echo -e "${BLUE}Access URLs:${NC}"
    echo "  UniFi Controller: https://${HOST_IP}:8443"
    echo "  FTP Server:       ftp://${HOST_IP}:21"
    echo ""
    echo -e "${BLUE}Shared Storage Location:${NC}"
    echo "  Host Path: ${SCRIPT_DIR}/unifi-storage"
    echo "  UniFi Path: /storage"
    echo "  FTP Path: /home/vsftpd/unifi"
    echo ""
    echo -e "${YELLOW}Important Notes:${NC}"
    echo "  1. Accept the SSL certificate warning in your browser"
    echo "  2. Complete the UniFi setup wizard at https://${HOST_IP}:8443"
    echo "  3. FTP rate limited to 50KB/s to prevent DB I/O starvation"
    echo "  4. Backup files saved to: ${SCRIPT_DIR}/unifi-storage/backups"
    echo "==============================================================================="
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================

main() {
    echo "==============================================================================="
    echo "  UniFi Network OS - Auto-Dynamic Setup with Enforcement & Rate Limiting"
    echo "==============================================================================="
    echo ""
    
    # Run all pre-flight checks
    check_root
    check_docker
    check_resources
    check_ports
    cleanup_existing
    
    # Generate configuration
    generate_credentials
    setup_directories
    
    # Deploy services
    deploy_services
    
    # Verify deployment
    verify_deployment
    
    echo ""
    success "Setup completed successfully! Log file: $LOG_FILE"
}

# Execute main function
main "$@"
