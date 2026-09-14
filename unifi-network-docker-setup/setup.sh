#!/bin/bash

# UniFi Network OS Auto-Dynamic Setup Script
# This script automatically configures and deploys UniFi Network with vsftpd

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to generate secure random password
generate_password() {
    openssl rand -base64 32 | tr -d '\n'
}

# Function to detect server IP
detect_server_ip() {
    # Try to get the primary non-loopback IP address
    local ip=""
    
    # Try different methods to get IP
    if command -v hostname &> /dev/null; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}' | head -n1)
    fi
    
    if [ -z "$ip" ] && command -v ip &> /dev/null; then
        ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
    fi
    
    if [ -z "$ip" ]; then
        ip="127.0.0.1"
        log_warning "Could not auto-detect server IP, using 127.0.0.1"
    fi
    
    echo "$ip"
}

# Function to check available disk space
check_disk_space() {
    local required_gb=$1
    local available_kb=$(df -k . | tail -1 | awk '{print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        log_error "Insufficient disk space. Required: ${required_gb}GB, Available: ${available_gb}GB"
        exit 1
    fi
    
    log_info "Available disk space: ${available_gb}GB"
}

# Function to check available memory
check_memory() {
    local required_mb=$1
    local total_mem_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    
    if [ -n "$total_mem_kb" ]; then
        local total_mem_mb=$((total_mem_kb / 1024))
        log_info "Total system memory: ${total_mem_mb}MB"
        
        if [ "$total_mem_mb" -lt "$required_mb" ]; then
            log_warning "System memory (${total_mem_mb}MB) is below recommended (${required_mb}MB)"
        fi
    fi
}

# Function to create necessary directories
create_directories() {
    log_info "Creating directory structure..."
    
    mkdir -p unifi-data
    mkdir -p unifi-db-data
    mkdir -p unifi-storage/backups
    mkdir -p unifi-storage/logs
    mkdir -p mongodb-init
    mkdir -p vsftpd-logs
    
    # Set appropriate permissions
    chmod 755 unifi-data unifi-db-data unifi-storage mongodb-init vsftpd-logs
    chmod 755 unifi-storage/backups unifi-storage/logs
    
    log_success "Directory structure created"
}

# Function to create .env file with dynamic values
create_env_file() {
    log_info "Generating environment configuration..."
    
    local server_ip=$(detect_server_ip)
    local mongo_pass=$(generate_password)
    local mongo_root_pass=$(generate_password)
    local ftp_pass=$(generate_password)
    
    cat > .env << ENVEOF
# UniFi Network OS Auto-Generated Configuration
# Generated: $(date)

# Server Configuration
SERVER_IP=${server_ip}
TZ=${TZ:-UTC}

# MongoDB Configuration
MONGO_ROOT_USER=unifi_root
MONGO_ROOT_PASSWORD=${mongo_root_pass}
MONGO_PASSWORD=${mongo_pass}

# FTP Configuration
FTP_USER=unifi
FTP_PASSWORD=${ftp_pass}
PASV_ADDRESS=${server_ip}
PASV_MIN_PORT=30000
PASV_MAX_PORT=30010
FTP_LOGGING=YES

# UniFi Memory Settings (adjust based on device count)
# For up to 50 devices: 1024MB
# For 50-200 devices: 2048MB
# For 200+ devices: 4096MB
MEM_LIMIT=1024
MEM_STARTUP=1024

# Port Configuration
UNIFI_HTTP_PORT=8080
UNIFI_HTTPS_PORT=8443
UNIFI_UDP_PORT=3478
UNIFI_STUN_PORT=10001
UNIFI_DISPLAY_PORT=8081
UNIFI_RTSP_PORT=8843
UNIFI_SYSLOG_PORT=5514
ENVEOF

    log_success "Environment file created at .env"
    log_info "Server IP detected: ${server_ip}"
    
    # Display credentials securely
    echo ""
    log_warning "IMPORTANT - Save these credentials securely:"
    echo "  MongoDB Root Password: ${mongo_root_pass}"
    echo "  MongoDB User Password: ${mongo_pass}"
    echo "  FTP Password: ${ftp_pass}"
    echo ""
}

# Function to create MongoDB initialization script
create_mongodb_init() {
    log_info "Creating MongoDB initialization script..."
    
    cat > mongodb-init/01-unifi-user.js << 'MONGOEOF'
// UniFi Database User Initialization
db = db.getSiblingDB('unifi');

// Create user with appropriate roles
db.createUser({
  user: "unifi",
  pwd: "placeholder_password",
  roles: [
    { role: "readWrite", db: "unifi" },
    { role: "dbAdmin", db: "unifi" }
  ]
});

// Create indexes for optimal performance
db.createCollection("device");
db.device.createIndex({ mac: 1 }, { unique: true });
db.createCollection("user");
db.user.createIndex({ mac: 1 });
db.createCollection("event");
db.event.createIndex({ time: -1 });
MONGOEOF

    log_success "MongoDB initialization script created"
}

# Function to verify Docker installation
verify_docker() {
    log_info "Verifying Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        echo "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    log_success "Docker and Docker Compose verified"
}

# Function to pull images
pull_images() {
    log_info "Pulling Docker images..."
    
    docker pull lscr.io/linuxserver/unifi-network-application:latest
    docker pull mongo:7.0
    docker pull fauria/vsftpd:latest
    
    log_success "All images pulled successfully"
}

# Function to start services
start_services() {
    log_info "Starting UniFi Network services..."
    
    # Use docker compose or docker-compose depending on availability
    if docker compose version &> /dev/null; then
        docker compose up -d
    else
        docker-compose up -d
    fi
    
    log_success "Services started"
}

# Function to display status
display_status() {
    echo ""
    log_info "Waiting for services to initialize (this may take 2-3 minutes)..."
    sleep 10
    
    echo ""
    log_info "Service Status:"
    if docker compose version &> /dev/null; then
        docker compose ps
    else
        docker-compose ps
    fi
    
    echo ""
    log_success "UniFi Network OS setup complete!"
    echo ""
    echo "=============================================="
    echo "Access Information:"
    echo "=============================================="
    echo "  UniFi Controller: https://$(detect_server_ip):8443"
    echo "  FTP Server: ftp://$(detect_server_ip):21"
    echo "  FTP Username: unifi"
    echo "  FTP Password: (see .env file)"
    echo ""
    echo "Storage Locations:"
    echo "  UniFi Config: $(pwd)/unifi-data"
    echo "  Database: $(pwd)/unifi-db-data"
    echo "  Shared Storage: $(pwd)/unifi-storage"
    echo "  Backups: $(pwd)/unifi-storage/backups"
    echo ""
    echo "=============================================="
    echo ""
}

# Main execution
main() {
    echo "=============================================="
    echo "  UniFi Network OS Auto-Dynamic Setup"
    echo "=============================================="
    echo ""
    
    # Run pre-checks
    verify_docker
    check_disk_space 10
    check_memory 2048
    
    # Setup steps
    create_directories
    create_env_file
    create_mongodb_init
    pull_images
    start_services
    
    # Display final status
    display_status
    
    log_info "Setup completed successfully!"
    log_info "To view logs: docker compose logs -f"
    log_info "To stop services: docker compose down"
    log_info "To restart services: docker compose restart"
}

# Run main function
main "$@"
