# UniFi Network OS - Reinforcement Learning Edition

## Production-Ready Auto-Dynamic Deployment with Q-Learning Optimization

### 🚀 Key Features

#### **Reinforcement Learning Engine**
- **Q-Learning Algorithm**: Dynamically optimizes resource allocation based on real-time metrics
- **Auto-Scaling**: Automatically adjusts CPU/memory limits based on load patterns
- **Reward-Based Optimization**: Learns optimal configurations through positive/negative rewards
- **State Tracking**: Monitors CPU, memory, and network states for intelligent decisions

#### **Network Protocol Optimization**
- **TCP BBR Congestion Control**: Google's modern congestion algorithm for high throughput
- **HTTP/2 Support**: Multiplexed connections for reduced latency
- **Gzip Compression**: 60-80% bandwidth reduction for text-based content
- **Connection Pooling**: Keepalive connections for database and backend services

#### **Security Enforcement**
- Root privilege verification
- Secure credential generation (32-character random passwords)
- Isolated network segments (public/internal)
- SSL/TLS encryption for all services
- Rate limiting on FTP and HTTP endpoints

#### **Resource Management**
- Dynamic CPU/Memory allocation based on detected hardware
- Block I/O rate limiting for storage operations
- Per-container resource caps and reservations
- Automatic garbage collection for logs

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    PUBLIC NETWORK                            │
│  Port 80/443/8443/8080/21/30000-30010                        │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────▼────────┐   ┌────────▼────────┐   ┌──────▼───────┐
│  Nginx Proxy   │   │   vsftpd        │   │  RL Agent    │
│  (Frontend)    │   │   (Storage)     │   │  (Monitor)   │
│  - HTTP/2      │   │  - Rate Limit   │   │  - Q-Learn   │
│  - SSL Term    │   │  - 50KB/s       │   │  - Auto-Scale│
│  - Gzip        │   │  - Max 10 conn  │   │              │
└───────┬────────┘   └─────────────────┘   └──────▲───────┘
        │                                          │
┌───────▼──────────────────────────────────────────┴───────┐
│                  INTERNAL NETWORK                         │
│              (Isolated, No External Access)               │
├───────────────────────────────────────────────────────────┤
│  ┌──────────────────┐         ┌──────────────────────┐   │
│  │ UniFi Controller │◄────────│   MongoDB            │   │
│  │ (Backend)        │         │   (Database)         │   │
│  │ - JVM Tuned      │         │   - WiredTiger       │   │
│  │ - 2GB RAM        │         │   - 0.5GB Cache      │   │
│  └──────────────────┘         └──────────────────────┘   │
└───────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────▼─────────────────────┐
        │         SHARED STORAGE VOLUME             │
        │  /data/shared-storage                     │
        │  - UniFi backups                          │
        │  - FTP accessible                         │
        └───────────────────────────────────────────┘
```

---

## Quick Start

### Prerequisites
- Docker 20.10+ with Compose plugin
- Linux host (Ubuntu 20.04+, Debian 11+, CentOS 8+)
- Minimum: 2 CPU cores, 2GB RAM, 20GB disk
- Root/sudo access

### Installation

```bash
cd /workspace/unifi-reinforced-os
sudo ./scripts/setup.sh
```

The script will automatically:
1. ✅ Verify root privileges
2. ✅ Check Docker installation
3. ✅ Validate hardware resources
4. ✅ Detect server IP
5. ✅ Generate secure credentials
6. ✅ Optimize TCP stack (BBR)
7. ✅ Deploy all services
8. ✅ Perform health checks

### Access After Deployment

| Service | URL | Credentials |
|---------|-----|-------------|
| UniFi Controller | `https://<server-ip>:8443` | Setup wizard on first login |
| Device Gateway | `http://<server-ip>:8080` | Internal use |
| FTP Storage | `ftp://<server-ip>:21` | See `.env` file |

---

## Configuration Files

### Environment Variables (`.env`)
Auto-generated with secure values:
```bash
SERVER_IP=<auto-detected>
MONGO_ROOT_USER=root_unifi_<random>
MONGO_ROOT_PASS=<32-char-random>
MONGO_USER=unifi_app_<random>
MONGO_PASS=<32-char-random>
UNIFI_MEM_LIMIT=2048  # Dynamic based on RAM
FTP_USER=unifi_storage
FTP_PASS=<24-char-random>
RL_LEARNING_RATE=0.1
RL_DISCOUNT_FACTOR=0.9
```

### Resource Allocation (Dynamic)
Based on detected hardware:
- **UniFi Controller**: 50% of total RAM (min 1GB, max 4GB)
- **MongoDB**: 25% of total RAM for cache (min 0.25GB)
- **Nginx**: 256MB fixed
- **vsftpd**: 256MB fixed
- **RL Orchestrator**: 512MB fixed

### Network Settings
- **Public Network**: 172.28.0.0/24
- **Internal Network**: 172.29.0.0/24 (isolated)
- **TCP Congestion**: BBR (if available)
- **Max Connections**: 65535

---

## Reinforcement Learning Details

### Q-Learning Implementation

The RL agent (`orchestrator/rl_agent.py`) uses:

**State Space**:
- `normal`: CPU < 1.5GHz, Memory < 1.5GB
- `high_cpu`: CPU usage > 1.5GHz
- `high_memory`: Memory usage > 1.5GB

**Action Space**:
- `scale_up`: Increase resource limits
- `scale_down`: Decrease resource limits
- `maintain`: Keep current configuration
- `optimize_network`: Tune TCP parameters
- `optimize_db`: Adjust MongoDB cache

**Reward Function**:
- Normal state: +10
- High CPU/Memory: -5
- Error state: -10

**Learning Parameters**:
- Learning Rate (α): 0.1
- Discount Factor (γ): 0.9
- Exploration Rate (ε): 0.2

### Monitoring RL Agent

```bash
# View RL logs
docker logs unifi-orchestrator -f

# View Q-Table (updated every 5 minutes)
docker exec unifi-orchestrator cat /app/logs/orchestrator.log | grep "Q-Table"
```

---

## Performance Tuning

### TCP Stack Optimization
Applied automatically by setup script:
```bash
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15
```

### JVM Tuning (UniFi)
```bash
MEM_STARTUP=1024  # Initial heap
MEM_LIMIT=2048    # Max heap
```

### MongoDB WiredTiger
```yaml
cacheSizeGB: 0.25  # 25% of system RAM
journalCompressor: zlib
blockCompressor: zlib
prefixCompression: true
```

---

## Backup & Recovery

### Automated Backup Script
```bash
./scripts/backup.sh
```

Features:
- SHA256 checksum verification
- 7-day retention policy
- Automatic FTP upload to shared storage
- Timestamped archives

### Manual Backup
```bash
# Stop services
docker compose down

# Backup data directory
tar -czvf unifi-backup-$(date +%Y%m%d).tar.gz data/

# Restart
docker compose up -d
```

---

## Troubleshooting

### Check Service Status
```bash
docker compose ps
docker compose logs unifi-backend
docker compose logs mongo-db
```

### Resource Monitoring
```bash
docker stats unifi-backend unifi-database
```

### Reset RL Agent
```bash
docker restart unifi-orchestrator
```

### Common Issues

**Port Conflicts**:
```bash
sudo ss -tuln | grep -E ':(80|443|8443|8080|21|27017)'
```

**Insufficient Resources**:
```bash
free -h
df -h
nproc
```

**Docker Daemon Issues**:
```bash
sudo systemctl status docker
sudo journalctl -u docker
```

---

## Security Considerations

1. **Change Default Passwords**: Update credentials in `.env` after initial setup
2. **Firewall Rules**: Only expose required ports
3. **SSL Certificates**: Replace self-signed certs with Let's Encrypt for production
4. **Regular Updates**: Keep Docker images updated
5. **Log Rotation**: Configured to prevent disk exhaustion

---

## Hardware Recommendations

| Scale | CPU | RAM | Storage | Devices |
|-------|-----|-----|---------|---------|
| Small | 2 cores | 2GB | 20GB SSD | < 50 |
| Medium | 4 cores | 4GB | 50GB SSD | 50-200 |
| Large | 8 cores | 8GB | 100GB NVMe | 200-500 |
| Enterprise | 16 cores | 16GB | 500GB NVMe | 500+ |

---

## License & Credits

- UniFi Network Application: Ubiquiti Inc.
- MongoDB: Server Side Public License
- Nginx: BSD License
- vsftpd: GPL License
- RL Agent: Custom implementation (MIT License)

---

## Support

For issues related to:
- **UniFi Controller**: [Ubiquiti Community](https://community.ui.com)
- **Docker Setup**: GitHub Issues
- **RL Agent**: Check orchestrator logs
