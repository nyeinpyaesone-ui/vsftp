#!/bin/bash
###############################################################################
# UniFi Network OS - Plug & Play Auto-Dynamic Setup
# Features: Auto-HW Detection, Smart Networking, vsftpd Integration
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting UniFi Network OS Plug & Play Setup...${NC}"

# 1. Root Enforcement
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}❌ Error: Please run as root (sudo ./setup.sh)${NC}"
  exit 1
fi

# 2. Auto-Detect Hardware Resources
echo -e "${YELLOW}🔍 Detecting hardware resources...${NC}"
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
CPU_CORES=$(nproc --all)
DISK_AVAIL_KB=$(df -k . | tail -1 | awk '{print $4}')
DISK_AVAIL_GB=$((DISK_AVAIL_KB / 1024 / 1024))

echo "   Detected: ${CPU_CORES} CPUs, ${TOTAL_RAM_GB}GB RAM, ${DISK_AVAIL_GB}GB Disk Free"

# Resource Profiling Logic
if [ "$TOTAL_RAM_GB" -lt 2 ]; then
    echo -e "${RED}❌ Critical: Minimum 2GB RAM required. Detected: ${TOTAL_RAM_GB}GB${NC}"
    exit 1
fi

if [ "$DISK_AVAIL_GB" -lt 10 ]; then
    echo -e "${RED}❌ Critical: Minimum 10GB Disk space required. Detected: ${DISK_AVAIL_GB}GB${NC}"
    exit 1
fi

# Calculate Optimal Limits
MONGO_CACHE_MB=$(( (TOTAL_RAM_GB * 1024) / 4 )) # 25% of RAM for Mongo
UNIFI_HEAP_MB=$(( (TOTAL_RAM_GB * 1024) / 3 )) # 33% of RAM for UniFi
if [ "$MONGO_CACHE_MB" -gt 2048 ]; then MONGO_CACHE_MB=2048; fi # Cap at 2GB
if [ "$UNIFI_HEAP_MB" -gt 3072 ]; then UNIFI_HEAP_MB=3072; fi   # Cap at 3GB

echo "   ➤ Tuned Mongo Cache: ${MONGO_CACHE_MB}MB"
echo "   ➤ Tuned UniFi Heap: ${UNIFI_HEAP_MB}MB"

# 3. Auto-Detect Network Interface & IP
echo -e "${YELLOW}🌐 Detecting primary network interface...${NC}"
# Try to get IP via route, fallback to hostname
SERVER_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || hostname -i | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="127.0.0.1"
    echo -e "${YELLOW}   ⚠️  Could not auto-detect IP, defaulting to localhost${NC}"
else
    echo "   ➤ Server IP: ${SERVER_IP}"
fi

# 4. Port Conflict Check
echo -e "${YELLOW}🚦 Checking port availability...${NC}"
PORTS=(8443 8080 8448 21 27017)
for port in "${PORTS[@]}"; do
    if ss -tuln | grep -q ":$port "; then
        echo -e "${RED}❌ Port $port is already in use. Please stop the conflicting service.${NC}"
        exit 1
    fi
done
echo "   ➤ All required ports are available."

# 5. Generate Secure Credentials
echo -e "${YELLOW}🔐 Generating secure credentials...${NC}"
MONGO_ROOT_PASS=$(openssl rand -base64 32)
MONGO_USER_PASS=$(openssl rand -base64 32)
FTP_PASS=$(openssl rand -base64 24)
TIMESTAMP=$(date +%s)

# 6. Create Directory Structure
echo -e "${YELLOW}📂 Creating persistent storage volumes...${NC}"
mkdir -p data/unifi/data
mkdir -p data/unifi/log
mkdir -p data/db
mkdir -p data/shared_ftp
chmod -R 755 data/

# 7. Write Dynamic .env File
echo -e "${YELLOW}⚙️  Generating dynamic configuration (.env)...${NC}"
cat > .env <<EOF
# Auto-Generated Configuration - $(date)
SERVER_IP=${SERVER_IP}

# Database Settings
MONGO_ROOT_PASSWORD=${MONGO_ROOT_PASS}
MONGO_USER_PASSWORD=${MONGO_USER_PASS}
MONGO_CACHE_SIZE=${MONGO_CACHE_MB}

# UniFi Settings
UNIFI_HEAP_SIZE=${UNIFI_HEAP_MB}
TZ=UTC

# FTP Settings
FTP_USERNAME=unifi_backup
FTP_PASSWORD=${FTP_PASS}
FTP_DATA_DIR=/home/unifi_backup

# Versions
MONGO_VERSION=7.0
UNIFI_VERSION=latest
VSFTPD_VERSION=latest
EOF

# 8. Write vsftpd Config
cat > configs/vsftpd.conf <<EOF
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
ssl_tlsv1_2=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
# Rate Limiting
local_max_rate=102400
max_clients=20
max_per_ip=5
userlist_enable=YES
userlist_file=/etc/vsftpd.user_list
userlist_deny=NO
EOF
echo "unifi_backup" > configs/vsftpd.user_list

# 9. Start Services
echo -e "${GREEN}🐳 Deploying Docker containers...${NC}"
docker compose pull
docker compose up -d

# 10. Final Health Check
echo -e "${YELLOW}⏳ Waiting for services to initialize (30s)...${NC}"
sleep 30

if docker compose ps | grep -q "unifi.*Up"; then
    echo -e "${GREEN}✅ SUCCESS! UniFi Network OS is running.${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📡 ACCESS POINTS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🌐 UniFi Controller : https://${SERVER_IP}:8443"
    echo "  📂 FTP Backup Server: ftps://${SERVER_IP}:21"
    echo ""
    echo "  🔑 CREDENTIALS (SAVE THESE)"
    echo "  ---------------------------"
    echo "  FTP User            : unifi_backup"
    echo "  FTP Password        : ${FTP_PASS}"
    echo "  Mongo Root Pass     : ${MONGO_ROOT_PASS}"
    echo "  Mongo User Pass     : ${MONGO_USER_PASS}"
    echo ""
    echo "  💾 STORAGE PATHS"
    echo "  ----------------"
    echo "  Shared FTP Folder : $(pwd)/data/shared_ftp"
    echo "  UniFi Data        : $(pwd)/data/unifi"
    echo "  Database          : $(pwd)/data/db"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo -e "${RED}❌ Deployment failed. Check logs with: docker compose logs${NC}"
    exit 1
fi
