#!/bin/bash

echo "============================================"
echo "UniFi Network OS - Setup Script"
echo "============================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker is not running. Please start Docker first."
    echo "Run: dockerd & (as root) or systemctl start docker"
    exit 1
fi

echo "✓ Docker is running"
echo ""

# Create required directories
echo "Creating directory structure..."
mkdir -p unifi-data unifi-storage unifi-db-data vsftpd-config unifi-storage/backups
echo "✓ Directories created"
echo ""

# Check if vsftpd.conf exists
if [ ! -f "vsftpd-config/vsftpd.conf" ]; then
    echo "Creating default vsftpd configuration..."
    cat > vsftpd-config/vsftpd.conf << 'EOF'
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_sendfile=YES
message_file=.message
dual_log_enable=YES
xferlog_enable=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=YES
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
require_ssl_reuse=NO
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
ssl_ciphers=HIGH
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=30010
pasv_address=YOUR_SERVER_IP_HERE
chroot_local_user=YES
allow_writeable_chroot=YES
user_sub_token=$USER
local_root=/home/vsftpd/$USER
max_clients=50
max_per_ip=10
EOF
    echo "⚠ Please edit vsftpd-config/vsftpd.conf and set PASV_ADDRESS to your server IP"
fi

# Check if docker-compose.yml needs IP update
if grep -q "YOUR_SERVER_IP_HERE" docker-compose.yml; then
    echo "⚠ Please edit docker-compose.yml and replace YOUR_SERVER_IP_HERE with your actual server IP"
    echo ""
    echo "Your current IP addresses:"
    hostname -I 2>/dev/null || ip addr show | grep "inet " | awk '{print $2}'
    echo ""
    read -p "Press Enter after updating the IP address, or Ctrl+C to cancel..."
fi

echo ""
echo "Pulling Docker images..."
docker-compose pull

echo ""
echo "Starting UniFi Network OS services..."
docker-compose up -d

echo ""
echo "Waiting for services to initialize (this may take 2-3 minutes)..."
sleep 10

echo ""
echo "Checking service status..."
docker-compose ps

echo ""
echo "============================================"
echo "Setup Complete!"
echo "============================================"
echo ""
echo "Access UniFi Network Application:"
echo "  URL: https://localhost:8443"
echo "  (Replace localhost with your server IP for remote access)"
echo ""
echo "FTP Server Access:"
echo "  Host: localhost (or your server IP)"
echo "  Port: 21"
echo "  Username: unifi"
echo "  Password: unifi_ftp_password"
echo ""
echo "Shared Storage Location:"
echo "  Host path: $SCRIPT_DIR/unifi-storage"
echo "  FTP path: /home/vsftpd/unifi"
echo ""
echo "Important Notes:"
echo "  1. The first startup may take 3-5 minutes"
echo "  2. Accept the self-signed SSL certificate warning in your browser"
echo "  3. Change default passwords immediately after setup"
echo "  4. Configure your firewall to allow required ports"
echo ""
echo "Required Ports:"
echo "  - 8080/TCP (Device communication)"
echo "  - 8443/TCP (Web interface)"
echo "  - 3478/UDP (STUN)"
echo "  - 10001/UDP (Device discovery)"
echo "  - 27117/TCP (Database)"
echo "  - 21/TCP (FTP)"
echo "  - 30000-30010/TCP (FTP passive mode)"
echo ""
echo "View logs: docker-compose logs -f"
echo "Stop services: docker-compose down"
echo "Backup script: ./backup.sh"
echo ""
