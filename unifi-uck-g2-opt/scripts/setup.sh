#!/bin/bash
set -e

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Error: Root privileges required"
        exit 1
    fi
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker not installed"
        exit 1
    fi
    if ! docker info &> /dev/null; then
        echo "Error: Docker daemon not running"
        exit 1
    fi
}

detect_hardware() {
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
    CPU_CORES=$(nproc)
    DISK_AVAIL=$(df -k . | tail -1 | awk '{print $4}')
    
    if [ "$TOTAL_RAM_GB" -lt 1 ]; then
        echo "Error: Minimum 1GB RAM required (Detected: ${TOTAL_RAM_GB}GB)"
        exit 1
    fi
    if [ "$DISK_AVAIL" -lt 5242880 ]; then
        echo "Error: Minimum 5GB free disk space required"
        exit 1
    fi
    
    echo "Hardware: ${TOTAL_RAM_GB}GB RAM, ${CPU_CORES} Cores, ${DISK_AVAIL}KB Free"
}

detect_ip() {
    SERVER_IP=$(ip route get 1.1.1.1 | awk '{print $7}' | head -1)
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
    fi
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="127.0.0.1"
    fi
    echo "Server IP: ${SERVER_IP}"
}

generate_secrets() {
    DB_ROOT_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)
    DB_USER_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)
    FTP_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 24)
    
    mkdir -p .secrets
    echo -n "$DB_ROOT_PASS" > .secrets/db_root_pass
    echo -n "$DB_USER_PASS" > .secrets/db_user_pass
    echo -n "$FTP_PASS" > .secrets/ftp_user_pass
    chmod 600 .secrets/*
    
    export DB_ROOT_PASS DB_USER_PASS FTP_PASS
}

create_env() {
    TIMEZONE=$(cat /etc/timezone 2>/dev/null || echo "UTC")
    
    cat > .env <<EOF
SERVER_IP=${SERVER_IP}
TIMEZONE=${TIMEZONE}
DB_ROOT_USER=admin
DB_ROOT_PASS=${DB_ROOT_PASS}
DB_USER=unifi
DB_USER_PASS=${DB_USER_PASS}
FTP_PASS=${FTP_PASS}
EOF
    chmod 600 .env
}

setup_directories() {
    mkdir -p data/{db-data,unifi-config,shared-storage}
    chown -R 1000:1000 data/unifi-config
    chown -R 1000:1000 data/shared-storage
}

deploy() {
    echo "Deploying containers..."
    docker compose pull
    docker compose up -d
    echo "Waiting for services..."
    sleep 15
}

verify() {
    if docker compose ps | grep -q "unifi-controller.*Up"; then
        echo "✓ UniFi Controller running"
    else
        echo "✗ UniFi Controller failed"
        exit 1
    fi
    
    if docker compose ps | grep -q "unifi-ftp.*Up"; then
        echo "✓ vsftpd Server running"
    else
        echo "✗ vsftpd Server failed"
        exit 1
    fi
    
    echo ""
    echo "=== DEPLOYMENT COMPLETE ==="
    echo "UniFi: https://${SERVER_IP}:8443"
    echo "FTP: ftps://${SERVER_IP}:21"
    echo "FTP User: unifi_backup"
    echo "FTP Pass: $(cat .secrets/ftp_user_pass)"
    echo "==========================="
}

main() {
    check_root
    check_docker
    detect_hardware
    detect_ip
    generate_secrets
    create_env
    setup_directories
    deploy
    verify
}

main
