#!/bin/bash

#==============================================================================
# UniFi Network OS - Production-Ready Auto-Dynamic Setup Script
# Enforces: Security, Resource Limits, Rate Limiting, Error Handling
#==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
LOG_FILE="${SCRIPT_DIR}/logs/setup_$(date +%Y%m%d_%H%M%S).log"

# Minimum Requirements
MIN_DISK_GB=15
MIN_RAM_MB=2048
MIN_CPU_CORES=2

#==============================================================================
# Logging Functions
#==============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

info() { log "INFO" "${BLUE}$*${NC}"; }
success() { log "SUCCESS" "${GREEN}$*${NC}"; }
warn() { log "WARNING" "${YELLOW}$*${NC}"; }
error() { log "ERROR" "${RED}$*${NC}"; exit 1; }

#==============================================================================
# Enforcement Functions
#==============================================================================

enforce_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
    success "Root privileges verified"
}

enforce_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Start Docker with: systemctl start docker"
    fi
    
    if ! docker compose version &> /dev/null; then
        if ! docker-compose version &> /dev/null; then
            error "Docker Compose is not installed."
        fi
    fi
    
    local docker_version=$(docker --version | awk '{print $3}' | cut -d',' -f1)
    success "Docker ${docker_version} verified"
}

enforce_hardware() {
    info "Checking hardware resources..."
    
    # Disk space check
    local disk_available=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $disk_available -lt $MIN_DISK_GB ]]; then
        error "Insufficient disk space. Required: ${MIN_DISK_GB}GB, Available: ${disk_available}GB"
    fi
    success "Disk space OK: ${disk_available}GB available"
    
    # RAM check
    local ram_total=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $ram_total -lt $MIN_RAM_MB ]]; then
        warn "Low RAM. Required: ${MIN_RAM_MB}MB, Available: ${ram_total}MB. Performance may be degraded."
    else
        success "RAM OK: ${ram_total}MB available"
    fi
    
    # CPU cores check
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt $MIN_CPU_CORES ]]; then
        warn "Low CPU cores. Recommended: ${MIN_CPU_CORES}, Available: ${cpu_cores}"
    else
        success "CPU OK: ${cpu_cores} cores available"
    fi
}

enforce_ports() {
    info "Checking for port conflicts..."
    local ports=("8443" "8080" "3478" "10001" "8081" "8843" "6789" "5514" "21")
    local conflict=false
    
    for port in "${ports[@]}"; do
        if ss -tuln | grep -q ":${port} "; then
            warn "Port ${port} is already in use"
            conflict=true
        fi
    done
    
    if [[ "$conflict" == "true" ]]; then
        error "Port conflicts detected. Please free up the required ports."
    fi
    success "No port conflicts detected"
}

enforce_cleanup() {
    info "Cleaning up orphaned containers..."
    docker rm -f unifi-mongo unifi-controller unifi-ftp 2>/dev/null || true
    success "Cleanup complete"
}

#==============================================================================
# Dynamic Configuration Generation
#==============================================================================

generate_secure_password() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9!@#$%' | head -c 32
}

detect_host_ip() {
    local ip=""
    
    # Try to get IP from default route
    ip=$(ip route | awk '/default/ { print $9 }' | head -n1)
    
    # Fallback: Get first non-loopback IP
    if [[ -z "$ip" ]]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    
    # Final fallback
    if [[ -z "$ip" ]]; then
        ip="127.0.0.1"
        warn "Could not detect host IP, using 127.0.0.1"
    fi
    
    echo "$ip"
}

generate_env_file() {
    info "Generating secure environment configuration..."
    
    local host_ip=$(detect_host_ip)
    local mongo_password=$(generate_secure_password)
    local ftp_password=$(generate_secure_password)
    local tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
    
    cat > "$ENV_FILE" << EOF
# UniFi Network OS - Auto-Generated Environment File
# Generated: $(date)
# DO NOT EDIT - Regenerate by running setup.sh again

# Network Configuration
HOST_IP=${host_ip}
TZ=${tz}

# MongoDB Configuration
MONGO_USER=unifi
MONGO_PASSWORD=${mongo_password}

# FTP Configuration
FTP_USER=unifi
FTP_PASSWORD=${ftp_password}
FTP_RATE_LIMIT=51200

# Memory Configuration (in MB)
MEM_LIMIT=2048
MEM_STARTUP=1024
EOF

    chmod 600 "$ENV_FILE"
    success "Environment file generated: ${ENV_FILE}"
    
    # Display credentials (only once!)
    echo ""
    echo "=========================================="
    echo "⚠️  SAVE THESE CREDENTIALS NOW! ⚠️"
    echo "=========================================="
    echo "Host IP:          ${host_ip}"
    echo "MongoDB Password: ${mongo_password}"
    echo "FTP Password:     ${ftp_password}"
    echo "FTP User:         unifi"
    echo "=========================================="
    echo ""
}

#==============================================================================
# Directory Structure Setup
#==============================================================================

setup_directories() {
    info "Creating directory structure..."
    
    mkdir -p "${SCRIPT_DIR}"/{config,db-data,storage/backups,logs,vsftpd_config}
    chmod 755 "${SCRIPT_DIR}"/{config,db-data,storage,logs}
    chmod 700 "${SCRIPT_DIR}/storage/backups"
    
    success "Directory structure created"
}

#==============================================================================
# Docker Deployment
#==============================================================================

deploy_containers() {
    info "Pulling Docker images..."
    cd "$SCRIPT_DIR"
    
    if command -v docker compose &> /dev/null; then
        docker compose pull
    else
        docker-compose pull
    fi
    
    success "Images pulled successfully"
    
    info "Starting containers..."
    if command -v docker compose &> /dev/null; then
        docker compose up -d
    else
        docker-compose up -d
    fi
    
    success "Containers started"
}

#==============================================================================
# Health Check & Validation
#==============================================================================

wait_for_services() {
    info "Waiting for services to become healthy (max 180 seconds)..."
    local max_wait=180
    local interval=10
    local elapsed=0
    
    while [[ $elapsed -lt $max_wait ]]; do
        local mongo_status=$(docker inspect --format='{{.State.Health.Status}}' unifi-mongo 2>/dev/null || echo "starting")
        local unifi_status=$(docker inspect --format='{{.State.Health.Status}}' unifi-controller 2>/dev/null || echo "starting")
        
        if [[ "$mongo_status" == "healthy" && "$unifi_status" == "healthy" ]]; then
            success "All services are healthy!"
            return 0
        fi
        
        info "Waiting... (Mongo: ${mongo_status}, UniFi: ${unifi_status})"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    error "Services failed to become healthy within ${max_wait} seconds"
}

validate_deployment() {
    info "Validating deployment..."
    
    # Check container status
    local containers=$(docker ps --filter "name=unifi" --format "{{.Names}}: {{.Status}}")
    echo "$containers"
    
    # Check if UniFi is accessible
    sleep 10
    if curl -k -s -o /dev/null -w "%{http_code}" https://localhost:8443 | grep -q "200\|302"; then
        success "UniFi Controller is accessible at https://localhost:8443"
    else
        warn "UniFi Controller may still be initializing..."
    fi
    
    # Check FTP
    if docker exec unifi-ftp ls /home/unifi/backups &> /dev/null; then
        success "FTP server is operational"
    else
        warn "FTP server may need more time to initialize"
    fi
}

#==============================================================================
# Main Execution
#==============================================================================

main() {
    echo ""
    echo "=============================================="
    echo "  UniFi Network OS - Production Setup"
    echo "  Auto-Dynamic with Full Enforcement"
    echo "=============================================="
    echo ""
    
    enforce_root
    enforce_docker
    enforce_hardware
    enforce_ports
    enforce_cleanup
    
    setup_directories
    generate_env_file
    
    deploy_containers
    wait_for_services
    validate_deployment
    
    echo ""
    success "=============================================="
    success "  Setup Complete!"
    success "=============================================="
    echo ""
    echo "Access Points:"
    echo "  • UniFi Controller: https://${HOST_IP:-<host-ip>}:8443"
    echo "  • FTP Server:       ftp://${HOST_IP:-<host-ip>}:21"
    echo "  • Shared Storage:   ${SCRIPT_DIR}/storage/backups"
    echo ""
    echo "Next Steps:"
    echo "  1. Open https://${HOST_IP:-<host-ip>}:8443 in your browser"
    echo "  2. Complete the UniFi setup wizard"
    echo "  3. Adopt your UniFi devices"
    echo "  4. Configure backups to /storage/backups"
    echo ""
    echo "Logs: ${LOG_FILE}"
    echo ""
}

# Trap errors
trap 'error "Script failed at line ${LINENO}"' ERR

main "$@"
