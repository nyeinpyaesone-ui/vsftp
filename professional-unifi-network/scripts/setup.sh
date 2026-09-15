# Professional UniFi Network OS - Auto-Dynamic Setup
# Enforces security, validates hardware, configures networking protocols

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Enforcement: Root privileges required
enforce_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (sudo)"
        exit 1
    fi
    log_success "Root privileges verified"
}

# Enforcement: Docker validation
enforce_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose plugin not found"
        exit 1
    fi
    
    log_success "Docker $(docker --version) validated"
}

# Enforcement: Hardware resources
enforce_hardware() {
    local min_disk=20  # GB
    local min_ram=3    # GB
    local min_cpu=2
    
    # Check disk space
    local available_disk=$(df -BG "$PROJECT_ROOT" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_disk -lt $min_disk ]]; then
        log_error "Insufficient disk space: ${available_disk}GB available, ${min_disk}GB required"
        exit 1
    fi
    log_success "Disk space verified: ${available_disk}GB available"
    
    # Check RAM
    local total_ram=$(free -g | awk '/^Mem:/ {print $2}')
    if [[ $total_ram -lt $min_ram ]]; then
        log_warn "Low RAM: ${total_ram}GB available, ${min_ram}GB recommended"
    else
        log_success "RAM verified: ${total_ram}GB available"
    fi
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt $min_cpu ]]; then
        log_warn "Low CPU cores: ${cpu_cores} available, ${min_cpu} recommended"
    else
        log_success "CPU verified: ${cpu_cores} cores available"
    fi
}

# Enforcement: Port availability
enforce_ports() {
    local ports=(8443 8080 3478 10001 1900 8843 8880 21 27017)
    local conflict=false
    
    for port in "${ports[@]}"; do
        if ss -tuln | grep -q ":$port "; then
            log_warn "Port $port is already in use"
            conflict=true
        fi
    done
    
    if [[ "$conflict" == "true" ]]; then
        log_error "Port conflicts detected. Please free up the ports and retry."
        exit 1
    fi
    
    log_success "All required ports are available"
}

# Auto-detect server IP
detect_server_ip() {
    local ip=""
    
    # Try to get IP from default route
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    
    # Fallback: get first non-loopback IP
    if [[ -z "$ip" ]]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    
    # Final fallback
    if [[ -z "$ip" ]]; then
        ip="127.0.0.1"
        log_warn "Could not auto-detect IP, using $ip"
    fi
    
    echo "$ip"
}

# Generate secure random password
generate_password() {
    local length=${1:-32}
    openssl rand -base64 "$length" | tr -dc 'a-zA-Z0-9!@#$%' | head -c "$length"
}

# Create environment file with dynamic values
create_env_file() {
    local server_ip=$(detect_server_ip)
    local timezone=$(cat /etc/timezone 2>/dev/null || echo "UTC")
    
    # Generate secure credentials
    local mongo_root_user="unifi_admin"
    local mongo_root_pass=$(generate_password 32)
    local mongo_user="unifi_controller"
    local mongo_pass=$(generate_password 32)
    local ftp_user="unifi_backup"
    local ftp_pass=$(generate_password 24)
    
    # FTP passive mode port range
    local ftp_pasv_min=50000
    local ftp_pasv_max=50100
    
    cat > "$ENV_FILE" << EOF
# Professional UniFi Network OS - Auto-Generated Configuration
# Generated: $(date)

# Server Configuration
SERVER_IP=${server_ip}
TIMEZONE=${timezone}

# MongoDB Credentials
MONGO_ROOT_USER=${mongo_root_user}
MONGO_ROOT_PASSWORD=${mongo_root_pass}
MONGO_USER=${mongo_user}
MONGO_PASS=${mongo_pass}

# FTP Server Credentials
FTP_USER=${ftp_user}
FTP_PASS=${ftp_pass}
FTP_PASV_MIN=${ftp_pasv_min}
FTP_PASV_MAX=${ftp_pasv_max}
EOF
    
    chmod 600 "$ENV_FILE"
    log_success "Environment file created at $ENV_FILE"
    
    # Display credentials (user should save them)
    echo ""
    echo -e "${YELLOW}=== SAVE THESE CREDENTIALS ===${NC}"
    echo "Server IP: $server_ip"
    echo "MongoDB Root: $mongo_root_user / $mongo_root_pass"
    echo "MongoDB User: $mongo_user / $mongo_pass"
    echo "FTP User: $ftp_user / $ftp_pass"
    echo "UniFi Controller: https://${server_ip}:8443"
    echo "FTP Server: ftp://${server_ip}:21"
    echo -e "${YELLOW}===============================${NC}"
    echo ""
}

# Create directory structure with proper permissions
setup_directories() {
    log_info "Creating directory structure..."
    
    mkdir -p "$PROJECT_ROOT/data/{unifi,db,ftp-backups}"
    mkdir -p "$PROJECT_ROOT/configs/{vsftpd,mongo}"
    
    # Set secure permissions
    chmod 700 "$PROJECT_ROOT/data/db"
    chmod 755 "$PROJECT_ROOT/data/unifi"
    chmod 755 "$PROJECT_ROOT/data/ftp-backups"
    
    log_success "Directory structure created with secure permissions"
}

# Create MongoDB configuration
create_mongo_config() {
    cat > "$PROJECT_ROOT/configs/mongo/mongod.conf" << 'EOF'
storage:
  dbPath: /data/db
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1.5
      journalCompressor: zlib
systemLog:
  destination: file
  path: /dev/stdout
  logAppend: true
net:
  port: 27017
  bindIp: 0.0.0.0
security:
  authorization: enabled
EOF
    log_success "MongoDB configuration created"
}

# Create vsftpd configuration
create_vsftpd_config() {
    cat > "$PROJECT_ROOT/configs/vsftpd/vsftpd.conf" << 'EOF'
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
ftpd_banner=Welcome to UniFi Backup FTP Server
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=YES
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1_2=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
pasv_enable=YES
pasv_min_port=50000
pasv_max_port=50100
max_clients=20
max_per_ip=5
local_max_rate=102400
EOF
    log_success "vsftpd configuration created"
}

# Cleanup function for rollback
cleanup_on_failure() {
    log_error "Setup failed. Cleaning up..."
    cd "$PROJECT_ROOT"
    docker compose down 2>/dev/null || true
    log_info "Cleanup completed. Please check logs and retry."
}

# Main setup function
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Professional UniFi Network OS Setup${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Run all enforcement checks
    enforce_root
    enforce_docker
    enforce_hardware
    enforce_ports
    
    # Setup components
    setup_directories
    create_env_file
    create_mongo_config
    create_vsftpd_config
    
    # Pull images
    log_info "Pulling Docker images..."
    cd "$PROJECT_ROOT"
    docker compose pull
    
    # Start services
    log_info "Starting services..."
    docker compose up -d
    
    # Wait for services to be healthy
    log_info "Waiting for services to initialize (60 seconds)..."
    sleep 60
    
    # Health check
    if docker compose ps | grep -q "unifi-controller.*healthy\|unifi-controller.*Up"; then
        log_success "UniFi Network OS deployed successfully!"
        echo ""
        echo -e "${GREEN}Access your UniFi Controller at:${NC}"
        echo "https://$(grep SERVER_IP $ENV_FILE | cut -d= -f2):8443"
        echo ""
        echo -e "${GREEN}FTP Backup Server:${NC}"
        echo "ftp://$(grep SERVER_IP $ENV_FILE | cut -d= -f2):21"
        echo "Username: $(grep FTP_USER $ENV_FILE | cut -d= -f2)"
        echo ""
        echo "Backup location: $PROJECT_ROOT/data/ftp-backups/"
    else
        log_error "Services failed to start properly"
        docker compose logs
        cleanup_on_failure
        exit 1
    fi
}

# Trap errors
trap cleanup_on_failure ERR

# Execute main
main "$@"
