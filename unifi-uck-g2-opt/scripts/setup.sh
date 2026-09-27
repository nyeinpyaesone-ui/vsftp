#!/bin/bash
set -e

# Exit with status 1 if the script is not running as root.
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Error: Root privileges required"
        exit 1
    fi
}

# Require the Docker CLI and a reachable daemon; exit with status 1 on failure.
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

# Record and print RAM, CPU count, and free disk space for the current directory.
# Exit with status 1 if RAM is below 1 GB or free disk space is below 5 GB.
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

# Set SERVER_IP from the route to 1.1.1.1, falling back to hostname IP or loopback.
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

# Generate and export database and FTP passwords, overwriting their files in
# .secrets relative to the current directory and setting file permissions to 600.
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

# Write the detected IP, timezone, and generated credentials to .env in the
# current directory, then restrict its permissions to 600.
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

# Create data directories relative to the current directory and assign UniFi
# configuration and shared storage ownership to UID and GID 1000.
setup_directories() {
    mkdir -p data/{db-data,unifi-config,shared-storage}
    chown -R 1000:1000 data/unifi-config
    chown -R 1000:1000 data/shared-storage
}

# Create a persistent certificate for explicit FTPS. Existing certificates are kept.
setup_ftp_tls() {
    local tls_dir="data/ftp-tls"
    install -d -m 700 "$tls_dir"
    if [[ ! -e "$tls_dir/vsftpd.crt" && ! -e "$tls_dir/vsftpd.key" ]]; then
        (umask 077; openssl req -x509 -nodes -newkey rsa:3072 -days 365 \
            -keyout "$tls_dir/vsftpd.key" -out "$tls_dir/vsftpd.crt" \
            -subj "/CN=${SERVER_IP}" -addext "subjectAltName=IP:${SERVER_IP}")
    fi
    # Fail before deployment if either file is missing or invalid.
    openssl x509 -in "$tls_dir/vsftpd.crt" -noout -checkend 0
    openssl pkey -in "$tls_dir/vsftpd.key" -noout -check
    if ! cmp -s <(openssl x509 -in "$tls_dir/vsftpd.crt" -pubkey -noout) \
                <(openssl pkey -in "$tls_dir/vsftpd.key" -pubout); then
        echo "Error: FTPS certificate and private key do not match" >&2
        exit 1
    fi
    chown root:root "$tls_dir" "$tls_dir/vsftpd.crt" "$tls_dir/vsftpd.key"
    chmod 600 "$tls_dir/vsftpd.key"
    # vsftpd only loads configuration owned by its startup user (root).
    chown root:root configs/vsftpd/vsftpd.conf
}

# Pull and start the current Compose project, then wait 15 seconds for startup.
deploy() {
    echo "Deploying containers..."
    docker compose pull
    docker compose up -d
    echo "Waiting for services..."
    sleep 15
}

# Require the controller and FTP containers to appear Up in Compose status,
# exiting with status 1 otherwise; print access details and the FTP password.
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

# Validate prerequisites, generate configuration and storage, then deploy and
# verify the Cloud Key stack using the current working directory.
main() {
    check_root
    check_docker
    detect_hardware
    detect_ip
    generate_secrets
    create_env
    setup_directories
    setup_ftp_tls
    deploy
    verify
}

main
