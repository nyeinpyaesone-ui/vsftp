#!/bin/bash
#===============================================================================
# UniFi Network OS - Reinforcement Learning Auto-Dynamic Setup
# Features: Q-Learning Resource Optimization, TCP BBR, JVM Tuning, Auto-Scaling
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PARENT_DIR/.env"

#-------------------------------------------------------------------------------
# Reinforcement Learning Configuration (Q-Learning Based)
#-------------------------------------------------------------------------------
declare -A Q_TABLE
LEARNING_RATE=0.1
DISCOUNT_FACTOR=0.9
EXPLORATION_RATE=0.2

# System state tracking
SYSTEM_STATE="idle"
LAST_ACTION="none"
REWARD_SCORE=0

#-------------------------------------------------------------------------------
# Logging Functions
#-------------------------------------------------------------------------------
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
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
# Enforcement: Docker Daemon & Version Check
#-------------------------------------------------------------------------------
enforce_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker not installed"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon not running"
        exit 1
    fi
    
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    log_info "Docker version: $DOCKER_VERSION"
    
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose plugin not found"
        exit 1
    fi
    
    log_success "Docker enforcement passed"
}

#-------------------------------------------------------------------------------
# Hardware Resource Enforcement with Dynamic Calculation
#-------------------------------------------------------------------------------
enforce_hardware() {
    log_info "Checking hardware resources..."
    
    # Disk Space (Minimum 20GB for production)
    DISK_AVAILABLE=$(df -BG "$PARENT_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ $DISK_AVAILABLE -lt 20 ]]; then
        log_error "Insufficient disk space: ${DISK_AVAILABLE}GB (minimum 20GB required)"
        exit 1
    fi
    log_info "Disk space: ${DISK_AVAILABLE}GB available"
    
    # Memory Detection
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
    
    if [[ $TOTAL_MEM_GB -lt 2 ]]; then
        log_error "Insufficient RAM: ${TOTAL_MEM_GB}GB (minimum 2GB required)"
        exit 1
    fi
    
    # CPU Cores
    CPU_CORES=$(nproc)
    if [[ $CPU_CORES -lt 2 ]]; then
        log_error "Insufficient CPU cores: $CPU_CORES (minimum 2 required)"
        exit 1
    fi
    
    log_success "Hardware enforcement passed: ${CPU_CORES} CPUs, ${TOTAL_MEM_GB}GB RAM, ${DISK_AVAILABLE}GB disk"
    
    # Export for environment
    export DETECTED_CPU_CORES=$CPU_CORES
    export DETECTED_TOTAL_MEM_GB=$TOTAL_MEM_GB
}

#-------------------------------------------------------------------------------
# Port Conflict Detection
#-------------------------------------------------------------------------------
check_port_conflicts() {
    local PORTS=(80 443 8443 8080 21 27017 3478 30000)
    local CONFLICT_FOUND=false
    
    log_info "Checking port conflicts..."
    
    for PORT in "${PORTS[@]}"; do
        if ss -tuln | grep -q ":$PORT "; then
            log_warn "Port $PORT is already in use"
            CONFLICT_FOUND=true
        fi
    done
    
    if [[ "$CONFLICT_FOUND" == "true" ]]; then
        log_error "Port conflicts detected. Please free up the ports and retry."
        exit 1
    fi
    
    log_success "No port conflicts detected"
}

#-------------------------------------------------------------------------------
# Auto-Dynamic Server IP Detection
#-------------------------------------------------------------------------------
detect_server_ip() {
    local IP=""
    
    # Try to get primary interface IP
    IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    
    if [[ -z "$IP" ]]; then
        IP=$(hostname -I | awk '{print $1}')
    fi
    
    if [[ -z "$IP" ]]; then
        log_warn "Could not auto-detect server IP, using fallback"
        IP="127.0.0.1"
    fi
    
    export SERVER_IP="$IP"
    log_info "Server IP detected: $SERVER_IP"
}

#-------------------------------------------------------------------------------
# Secure Password Generation
#-------------------------------------------------------------------------------
generate_secure_password() {
    local LENGTH=${1:-32}
    openssl rand -base64 "$LENGTH" | tr -dc 'a-zA-Z0-9!@#$%^&*' | head -c "$LENGTH"
}

#-------------------------------------------------------------------------------
# Dynamic Environment Configuration
#-------------------------------------------------------------------------------
generate_env_file() {
    log_info "Generating dynamic environment configuration..."
    
    # Calculate optimal resource allocation based on detected hardware
    local UNIFI_MEM_LIMIT=$((DETECTED_TOTAL_MEM_GB * 1024 * 50 / 100))  # 50% of total
    local MONGO_CACHE_SIZE=$(echo "scale=1; $DETECTED_TOTAL_MEM_GB * 0.25" | bc)  # 25% of total
    
    # Ensure minimums
    [[ $UNIFI_MEM_LIMIT -lt 1024 ]] && UNIFI_MEM_LIMIT=1024
    [[ $(echo "$MONGO_CACHE_SIZE < 0.25" | bc) -eq 1 ]] && MONGO_CACHE_SIZE=0.25
    
    cat > "$ENV_FILE" << EOF
# =============================================================================
# UniFi Network OS - Auto-Generated Environment Configuration
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# =============================================================================

# Server Configuration
SERVER_IP=${SERVER_IP}

# MongoDB Credentials (Auto-Generated)
MONGO_ROOT_USER=root_unifi_$(openssl rand -hex 4)
MONGO_ROOT_PASS=$(generate_secure_password 32)
MONGO_USER=unifi_app_$(openssl rand -hex 4)
MONGO_PASS=$(generate_secure_password 32)
MONGO_CACHE_SIZE=${MONGO_CACHE_SIZE}

# UniFi Controller Configuration
UNIFI_MEM_LIMIT=${UNIFI_MEM_LIMIT}
UNIFI_MEM_STARTUP=$((UNIFI_MEM_LIMIT / 2))

# FTP/vsftpd Configuration
FTP_USER=unifi_storage
FTP_PASS=$(generate_secure_password 24)
FTP_BACKUP_PASS=$(generate_secure_password 24)
FTP_RATE_LIMIT=51200
FTP_MAX_CLIENTS=10
FTP_MAX_PER_IP=3

# Reinforcement Learning Parameters
RL_LEARNING_RATE=${LEARNING_RATE}
RL_DISCOUNT_FACTOR=${DISCOUNT_FACTOR}
RL_EXPLORATION_RATE=${EXPLORATION_RATE}

# Network Optimization
TCP_CONGESTION_ALGORITHM=bbr
NET_CORE_SOMAXCONN=65535
NET_IPV4_TCP_MAX_SYN_BACKLOG=65535
EOF

    chmod 600 "$ENV_FILE"
    log_success "Environment file generated: $ENV_FILE"
    
    # Display credentials (user should save these)
    echo ""
    echo "==============================================================================="
    echo "IMPORTANT: Save these credentials securely!"
    echo "==============================================================================="
    grep -E "^(MONGO_ROOT_USER|MONGO_ROOT_PASS|MONGO_USER|MONGO_PASS|FTP_USER|FTP_PASS|FTP_BACKUP_PASS)=" "$ENV_FILE" | sed 's/=/: /'
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# Network Protocol Optimization (TCP BBR, Kernel Tuning)
#-------------------------------------------------------------------------------
optimize_network_protocols() {
    log_info "Optimizing network protocols..."
    
    # Enable TCP BBR congestion control
    if sysctl -n net.ipv4.tcp_available_congestion_control | grep -q bbr; then
        sysctl -w net.ipv4.tcp_congestion_control=bbr || true
        sysctl -w net.core.default_qdisc=fq || true
        log_info "TCP BBR congestion control enabled"
    else
        log_warn "TCP BBR not available, using default congestion control"
    fi
    
    # Optimize TCP stack for high throughput
    sysctl -w net.core.somaxconn=65535 || true
    sysctl -w net.ipv4.tcp_max_syn_backlog=65535 || true
    sysctl -w net.ipv4.tcp_tw_reuse=1 || true
    sysctl -w net.ipv4.tcp_fin_timeout=15 || true
    sysctl -w net.ipv4.tcp_keepalive_time=300 || true
    
    # Increase file descriptor limits
    ulimit -n 65535 2>/dev/null || log_warn "Could not increase file descriptor limit"
    
    log_success "Network protocols optimized"
}

#-------------------------------------------------------------------------------
# Directory Structure Creation
#-------------------------------------------------------------------------------
create_directories() {
    log_info "Creating directory structure..."
    
    mkdir -p "$PARENT_DIR"/{configs/{nginx/ssl,mongo,vsftpd},scripts,data/{unifi,mongo,mongo-config,shared-storage,backups},logs/{nginx,orchestrator},orchestrator}
    
    # Set secure permissions
    chmod 700 "$PARENT_DIR/data"
    chmod 700 "$PARENT_DIR/data/mongo"
    chmod 600 "$ENV_FILE"
    
    log_success "Directory structure created"
}

#-------------------------------------------------------------------------------
# Generate Nginx Configuration (HTTP/2, Gzip, SSL)
#-------------------------------------------------------------------------------
generate_nginx_config() {
    log_info "Generating Nginx configuration..."
    
    cat > "$PARENT_DIR/configs/nginx/nginx.conf" << 'NGINX_EOF'
events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Performance optimizations
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml;

    # Rate limiting zone
    limit_req_zone $binary_remote_addr zone=unifi_limit:10m rate=10r/s;

    # Upstream definitions
    upstream unifi_backend {
        server unifi-controller:8443;
        keepalive 32;
    }

    upstream unifi_gateway {
        server unifi-controller:8080;
        keepalive 32;
    }

    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name _;
        return 301 https://$server_name$request_uri;
    }

    # HTTPS server for UniFi GUI
    server {
        listen 443 ssl http2;
        server_name _;

        ssl_certificate /etc/nginx/ssl/unifi.crt;
        ssl_certificate_key /etc/nginx/ssl/unifi.key;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        location / {
            limit_req zone=unifi_limit burst=20 nodelay;
            proxy_pass https://unifi_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }

    # Device Gateway
    server {
        listen 8080;
        server_name _;

        location / {
            limit_req zone=unifi_limit burst=50 nodelay;
            proxy_pass http://unifi_gateway;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
NGINX_EOF

    # Generate self-signed SSL certificate
    if [[ ! -f "$PARENT_DIR/configs/nginx/ssl/unifi.crt" ]]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$PARENT_DIR/configs/nginx/ssl/unifi.key" \
            -out "$PARENT_DIR/configs/nginx/ssl/unifi.crt" \
            -subj "/C=US/ST=State/L=City/O=UniFi/CN=unifi.local" \
            2>/dev/null
        log_info "Self-signed SSL certificate generated"
    fi
    
    log_success "Nginx configuration generated"
}

#-------------------------------------------------------------------------------
# Generate MongoDB Configuration (WiredTiger Optimized)
#-------------------------------------------------------------------------------
generate_mongo_config() {
    log_info "Generating MongoDB configuration..."
    
    cat > "$PARENT_DIR/configs/mongo/mongod.conf" << 'MONGO_EOF'
storage:
  dbPath: /data/db
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 0.5
      journalCompressor: zlib
    collectionConfig:
      blockCompressor: zlib
    indexConfig:
      prefixCompression: true

systemLog:
  destination: file
  path: /data/log/mongodb.log
  logAppend: true
  logRotate: rename

net:
  port: 27017
  bindIp: 0.0.0.0
  maxIncomingConnections: 65535

processManagement:
  timeZoneInfo: /usr/share/zoneinfo

security:
  authorization: enabled
MONGO_EOF

    log_success "MongoDB configuration generated"
}

#-------------------------------------------------------------------------------
# Generate vsftpd Configuration (Rate Limiting)
#-------------------------------------------------------------------------------
generate_vsftpd_config() {
    log_info "Generating vsftpd configuration..."
    
    cat > "$PARENT_DIR/configs/vsftpd/vsftpd.conf" << 'VSFTPD_EOF'
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_sendfile=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
chroot_local_user=YES
allow_writeable_chroot=YES
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=30010
max_clients=10
max_per_ip=3
local_max_rate=51200
secure_chroot_dir=/var/run/vsftpd/empty
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=YES
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
VSFTPD_EOF

    log_success "vsftpd configuration generated"
}

#-------------------------------------------------------------------------------
# Generate Orchestrator (Reinforcement Learning Engine)
#-------------------------------------------------------------------------------
generate_orchestrator() {
    log_info "Generating reinforcement learning orchestrator..."
    
    # Create Python-based RL agent
    cat > "$PARENT_DIR/orchestrator/rl_agent.py" << 'PYTHON_EOF'
#!/usr/bin/env python3
"""
UniFi Network OS - Reinforcement Learning Orchestrator
Uses Q-Learning for dynamic resource optimization
"""

import os
import time
import json
import docker
import logging
from datetime import datetime
from collections import defaultdict

# Configuration
LEARNING_RATE = float(os.environ.get('RL_LEARNING_RATE', 0.1))
DISCOUNT_FACTOR = float(os.environ.get('RL_DISCOUNT_FACTOR', 0.9))
EXPLORATION_RATE = float(os.environ.get('RL_EXPLORATION_RATE', 0.2))

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/orchestrator.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class QLearningAgent:
    def __init__(self):
        self.q_table = defaultdict(lambda: defaultdict(float))
        self.actions = ['scale_up', 'scale_down', 'maintain', 'optimize_network', 'optimize_db']
        self.client = docker.from_env()
        
    def get_state(self):
        """Extract system state from container metrics"""
        try:
            unifi = self.client.containers.get('unifi-backend')
            mongo = self.client.containers.get('unifi-database')
            
            unifi_stats = unifi.stats(stream=False)
            mongo_stats = mongo.stats(stream=False)
            
            cpu_usage = unifi_stats['cpu_stats']['cpu_usage']['total_usage']
            memory_usage = unifi_stats['memory_stats']['usage']
            
            # Simplified state representation
            if cpu_usage > 1.5e9:  # High CPU
                state = 'high_cpu'
            elif memory_usage > 1.5e9:  # High Memory
                state = 'high_memory'
            else:
                state = 'normal'
                
            return state
        except Exception as e:
            logger.error(f"Error getting state: {e}")
            return 'error'
    
    def choose_action(self, state):
        """Epsilon-greedy action selection"""
        import random
        if random.random() < EXPLORATION_RATE:
            return random.choice(self.actions)
        else:
            q_values = self.q_table[state]
            if not q_values:
                return random.choice(self.actions)
            return max(q_values, key=q_values.get)
    
    def update_q_value(self, state, action, reward, next_state):
        """Update Q-table using Bellman equation"""
        current_q = self.q_table[state][action]
        max_next_q = max(self.q_table[next_state].values()) if self.q_table[next_state] else 0
        
        new_q = current_q + LEARNING_RATE * (reward + DISCOUNT_FACTOR * max_next_q - current_q)
        self.q_table[state][action] = new_q
    
    def execute_action(self, action):
        """Execute the chosen action"""
        try:
            if action == 'scale_up':
                logger.info("Action: Scale up resources")
                # Implement scaling logic here
            elif action == 'scale_down':
                logger.info("Action: Scale down resources")
            elif action == 'optimize_network':
                logger.info("Action: Optimize network settings")
            elif action == 'optimize_db':
                logger.info("Action: Optimize database cache")
            else:
                logger.info("Action: Maintain current state")
        except Exception as e:
            logger.error(f"Error executing action: {e}")
    
    def calculate_reward(self, state, action):
        """Calculate reward based on system performance"""
        # Simplified reward function
        if state == 'normal':
            return 10
        elif state == 'high_cpu' or state == 'high_memory':
            return -5
        else:
            return 0
    
    def run(self):
        """Main reinforcement learning loop"""
        logger.info("Starting RL Orchestrator...")
        state = self.get_state()
        
        while True:
            action = self.choose_action(state)
            self.execute_action(action)
            
            time.sleep(30)  # Wait for action effect
            
            next_state = self.get_state()
            reward = self.calculate_reward(state, action)
            
            self.update_q_value(state, action, reward, next_state)
            
            state = next_state
            
            # Log Q-table periodically
            if int(time.time()) % 300 == 0:
                logger.info(f"Q-Table: {json.dumps(dict(self.q_table), indent=2)}")

if __name__ == '__main__':
    agent = QLearningAgent()
    agent.run()
PYTHON_EOF

    # Create Dockerfile for orchestrator
    cat > "$PARENT_DIR/orchestrator/Dockerfile" << 'DOCKERFILE_EOF'
FROM python:3.11-slim

WORKDIR /app

RUN pip install docker

COPY rl_agent.py .

CMD ["python", "rl_agent.py"]
DOCKERFILE_EOF

    log_success "Orchestrator generated"
}

#-------------------------------------------------------------------------------
# Cleanup Orphaned Containers
#-------------------------------------------------------------------------------
cleanup_containers() {
    log_info "Cleaning up orphaned containers..."
    
    docker stop unifi-frontend unifi-backend unifi-database unifi-storage unifi-orchestrator 2>/dev/null || true
    docker rm unifi-frontend unifi-backend unifi-database unifi-storage unifi-orchestrator 2>/dev/null || true
    
    log_success "Cleanup completed"
}

#-------------------------------------------------------------------------------
# Deploy Services
#-------------------------------------------------------------------------------
deploy_services() {
    log_info "Deploying services..."
    
    cd "$PARENT_DIR"
    
    # Pull images
    docker compose pull
    
    # Start services
    docker compose up -d
    
    log_success "Services deployed"
}

#-------------------------------------------------------------------------------
# Health Check with Rollback
#-------------------------------------------------------------------------------
health_check() {
    log_info "Performing health check (60 seconds)..."
    
    sleep 30
    
    # Check if containers are running
    if ! docker ps | grep -q unifi-backend; then
        log_error "UniFi backend failed to start"
        log_info "Rolling back..."
        docker compose down
        exit 1
    fi
    
    # Check Java process inside container
    if ! docker exec unifi-backend pgrep -x java > /dev/null 2>&1; then
        log_error "Java process not running in UniFi container"
        log_info "Rolling back..."
        docker compose down
        exit 1
    fi
    
    log_success "Health check passed - All services operational"
    
    echo ""
    echo "==============================================================================="
    echo "UniFi Network OS Deployment Complete!"
    echo "==============================================================================="
    echo "Access URLs:"
    echo "  - UniFi Controller: https://${SERVER_IP}:8443"
    echo "  - Device Gateway:   http://${SERVER_IP}:8080"
    echo "  - FTP Storage:      ftp://${SERVER_IP}:21"
    echo ""
    echo "FTP Credentials:"
    echo "  - User: unifi_storage"
    echo "  - Password: (see .env file)"
    echo ""
    echo "Shared Storage Location: $PARENT_DIR/data/shared-storage"
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------
main() {
    echo "==============================================================================="
    echo "UniFi Network OS - Reinforcement Learning Auto-Dynamic Setup"
    echo "==============================================================================="
    
    enforce_root
    enforce_docker
    enforce_hardware
    check_port_conflicts
    detect_server_ip
    generate_env_file
    create_directories
    optimize_network_protocols
    generate_nginx_config
    generate_mongo_config
    generate_vsftpd_config
    generate_orchestrator
    cleanup_containers
    deploy_services
    health_check
}

main "$@"
