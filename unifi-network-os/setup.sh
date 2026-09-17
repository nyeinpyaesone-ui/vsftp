#!/bin/bash
set -e

# ==============================================================================
# UniFi Network OS + vsftpd Enterprise Node - Single File Deployment
# Universal Compatibility: ARM64 (Cloud Key/Pi) & AMD64 (Server)
# ==============================================================================

# --- Configuration Constants ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DATA_DIR="${SCRIPT_DIR}/data"
readonly SECRETS_DIR="${SCRIPT_DIR}/.secrets"
readonly CONFIG_DIR="${SCRIPT_DIR}/config"
readonly COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
readonly ENV_FILE="${SCRIPT_DIR}/.env"

# --- Color Output ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- 1. Hardware Detection ---
detect_hardware() {
    log_info "Detecting hardware..."
    
    # Architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        PLATFORM="linux/arm64"
        log_info "Detected ARM64 architecture (Cloud Key/Pi)"
    elif [[ "$ARCH" == "x86_64" ]]; then
        PLATFORM="linux/amd64"
        log_info "Detected AMD64 architecture (Server/PC)"
    else
        log_error "Unsupported architecture: $ARCH"
    fi

    # RAM (in KB)
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
    log_info "Detected RAM: ${TOTAL_RAM_GB}GB"

    # Storage Type (Simple heuristic: check for mmc/sd in lsblk)
    if lsblk -d -o NAME,TYPE 2>/dev/null | grep -qE "mmc|sd"; then
        STORAGE_TYPE="flash"
        log_info "Detected Flash Storage (eMMC/SD) - Enabling protection"
    else
        STORAGE_TYPE="ssd"
        log_info "Detected SSD/HDD - Standard mode"
    fi

    # Server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if [ -z "$SERVER_IP" ]; then SERVER_IP="127.0.0.1"; fi
    log_info "Server IP: $SERVER_IP"
}

# --- 2. Resource Calculation ---
calculate_resources() {
    log_info "Calculating resource limits..."
    
    if [ $TOTAL_RAM_GB -le 2 ]; then
        # Low RAM (Cloud Key Gen2, Pi Zero)
        MONGO_MEM="300m"; MONGO_CACHE="0.25"
        UNIFI_MEM="300m"; UNIFI_HEAP="256"
        FTP_MEM="64m"
        log_warn "Low RAM detected: Using conservative limits"
    elif [ $TOTAL_RAM_GB -le 4 ]; then
        # Medium RAM
        MONGO_MEM="1g"; MONGO_CACHE="0.75"
        UNIFI_MEM="1.5g"; UNIFI_HEAP="1024"
        FTP_MEM="128m"
    else
        # High RAM
        MONGO_MEM="4g"; MONGO_CACHE="3.0"
        UNIFI_MEM="3g"; UNIFI_HEAP="2048"
        FTP_MEM="256m"
    fi
}

# --- 3. Secret Generation ---
generate_secrets() {
    log_info "Generating secure credentials..."
    mkdir -p "$SECRETS_DIR"
    chmod 700 "$SECRETS_DIR"

    DB_ROOT_PASS=$(openssl rand -base64 32)
    DB_USER_PASS=$(openssl rand -base64 32)
    FTP_PASS=$(openssl rand -base64 24)

    echo "$DB_ROOT_PASS" > "$SECRETS_DIR/db_root_pass"
    echo "$DB_USER_PASS" > "$SECRETS_DIR/db_user_pass"
    echo "$FTP_PASS" > "$SECRETS_DIR/ftp_user_pass"
    chmod 600 "$SECRETS_DIR"/*
}

# --- 4. Config Generation (Inline Templates) ---
generate_configs() {
    log_info "Generating configuration files..."
    mkdir -p "$CONFIG_DIR" "$DATA_DIR"/{db-data,unifi-config,shared-storage}

    # Generate .env
    cat > "$ENV_FILE" <<EOF
PLATFORM=${PLATFORM}
SERVER_IP=${SERVER_IP}
MONGO_MEM=${MONGO_MEM}
MONGO_CACHE=${MONGO_CACHE}
UNIFI_MEM=${UNIFI_MEM}
UNIFI_HEAP=${UNIFI_HEAP}
FTP_MEM=${FTP_MEM}
DB_ROOT_PASS=${DB_ROOT_PASS}
DB_USER_PASS=${DB_USER_PASS}
FTP_PASS=${FTP_PASS}
STORAGE_TYPE=${STORAGE_TYPE}
EOF

    # Generate mongod.conf
    cat > "$CONFIG_DIR/mongod.conf" <<EOF
storage:
  dbPath: /data/db
  wiredTiger:
    engineConfig:
      cacheSizeGB: ${MONGO_CACHE}
net:
  port: 27017
  bindIp: 0.0.0.0
EOF

    # Generate vsftpd.conf
    cat > "$CONFIG_DIR/vsftpd.conf" <<EOF
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=YES
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
pasv_enable=YES
pasv_min_port=50000
pasv_max_port=50100
local_max_rate=51200
max_clients=20
max_per_ip=5
EOF

    # Generate docker-compose.yml
    TmpfsMount=""
    if [ "$STORAGE_TYPE" == "flash" ]; then
        TmpfsMount="- /var/log:tmpfs,size=100m\n      - /tmp:tmpfs,size=50m"
    fi

    cat > "$COMPOSE_FILE" <<EOF
version: '3.8'
services:
  mongo:
    image: mongo:7.0
    platform: \${PLATFORM}
    container_name: unifi-mongo
    restart: unless-stopped
    environment:
      - MONGO_INITDB_ROOT_USERNAME=root
      - MONGO_INITDB_ROOT_PASSWORD=\${DB_ROOT_PASS}
    volumes:
      - ./data/db-data:/data/db
      - ./config/mongod.conf:/etc/mongod.conf
    command: mongod --config /etc/mongod.conf
    mem_limit: \${MONGO_MEM}
    cpus: 0.5
    networks:
      - unifi-net

  unifi:
    image: lscr.io/linuxserver/unifi-network-application:latest
    platform: \${PLATFORM}
    container_name: unifi-controller
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - MONGO_HOST=mongo
      - MONGO_PORT=27017
      - MONGO_USER=unifi
      - MONGO_PASS=\${DB_USER_PASS}
      - MONGO_DBNAME=unifi
      - MEM_LIMIT=\${UNIFI_MEM}
      - MEM_STARTUP=\${UNIFI_HEAP}m
    volumes:
      - ./data/unifi-config:/config
      $(echo -e "$TmpfsMount")
    ports:
      - 8443:8443
      - 3478:3478/udp
      - 10001:10001/udp
      - 8080:8080
      - 1900:1900/udp
      - 8843:8843
      - 8880:8880
      - 6789:6789
      - 5514:5514/udp
    depends_on:
      - mongo
    mem_limit: \${UNIFI_MEM}
    cpus: 1.0
    networks:
      - unifi-net

  vsftpd:
    image: fauria/vsftpd
    platform: \${PLATFORM}
    container_name: unifi-ftp
    restart: unless-stopped
    environment:
      - FTP_USER_1=unifi_backup,\${FTP_PASS}
      - PASV_ADDRESS=\${SERVER_IP}
      - PASV_MIN_PORT=50000
      - PASV_MAX_PORT=50100
    volumes:
      - ./data/shared-storage:/home/vsftpd/unifi_backup
      - ./config/vsftpd.conf:/etc/vsftpd/vsftpd.conf
    ports:
      - 21:21
      - 50000-50100:50000-50100
    mem_limit: \${FTP_MEM}
    cpus: 0.25
    networks:
      - unifi-net

networks:
  unifi-net:
    driver: bridge
EOF
}

# --- 5. Validation ---
validate_environment() {
    log_info "Validating environment..."
    if ! command -v docker &> /dev/null; then log_error "Docker not installed"; fi
    if ! command -v docker compose &> /dev/null; then log_error "Docker Compose not installed"; fi
    
    # Port Check (Simplified)
    for port in 8443 21 27017; do
        if ss -tuln | grep -q ":$port "; then
            log_warn "Port $port is already in use. Deployment may fail."
        fi
    done
}

# --- 6. Deployment ---
deploy() {
    log_info "Starting deployment..."
    cd "$SCRIPT_DIR"
    docker compose up -d --remove-orphans
    
    log_info "Waiting for services to start (30s)..."
    sleep 30
    
    if docker compose ps | grep -q "Up"; then
        log_info "✅ Deployment Successful!"
        echo ""
        echo "📊 Access Points:"
        echo "   UniFi Controller: https://${SERVER_IP}:8443"
        echo "   FTP Server:       ftps://${SERVER_IP}:21"
        echo "   FTP User:         unifi_backup"
        echo "   FTP Password:     $(cat $SECRETS_DIR/ftp_user_pass)"
        echo ""
        echo "💾 Shared Storage:  ${DATA_DIR}/shared-storage"
    else
        log_error "Deployment failed. Check 'docker compose logs'."
    fi
}

# --- Main Execution ---
main() {
    echo "=========================================="
    echo "UniFi Network OS + vsftpd Auto-Installer"
    echo "=========================================="
    
    detect_hardware
    calculate_resources
    generate_secrets
    generate_configs
    validate_environment
    deploy
}

main "$@"
