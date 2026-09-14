# UniFi Network OS - Production Docker Deployment

## Overview
Complete, production-ready UniFi Network OS deployment with vsftpd for backup storage, featuring automatic configuration, resource enforcement, and rate limiting.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Host System                              │
│  IP: Auto-detected                                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐   ┌──────────────────┐   ┌─────────────┐  │
│  │   MongoDB   │   │  UniFi Controller│   │    vsftpd   │  │
│  │  Port 27017 │──▶│  Port 8443/8080  │──▶│  Port 21    │  │
│  │  1.5 CPU    │   │  2.0 CPU         │   │  0.5 CPU    │  │
│  │  1GB RAM    │   │  2GB RAM         │   │  256MB RAM  │  │
│  └─────────────┘   └──────────────────┘   └─────────────┘  │
│         │                   │                      │        │
│         ▼                   ▼                      ▼        │
│  ┌─────────────┐   ┌──────────────────┐   ┌─────────────┐  │
│  │  db-data/   │   │  config/         │   │ storage/    │  │
│  │  (Database) │   │  (UniFi Config)  │   │ (Backups)   │  │
│  └─────────────┘   └──────────────────┘   └─────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Features

### ✅ Auto-Dynamic Configuration
- **IP Detection**: Automatically detects host server IP
- **Password Generation**: Creates secure 32-character passwords
- **Timezone**: Auto-detects system timezone
- **No Manual Config**: Zero configuration required

### 🔒 Security Enforcement
- **Root Check**: Requires sudo/root privileges
- **Secure Permissions**: `.env` file chmod 600
- **Isolated Network**: Dedicated Docker network (172.28.0.0/16)
- **Container Health Checks**: Automatic monitoring

### 📊 Resource Limits & Rate Limiting

| Service | CPU Limit | RAM Limit | Rate Limit |
|---------|-----------|-----------|------------|
| MongoDB | 1.5 cores | 1 GB | N/A |
| UniFi Controller | 2.0 cores | 2 GB | N/A |
| vsftpd | 0.5 cores | 256 MB | 50 KB/s per connection |

### 🛡️ Error Prevention
- Port conflict detection (8443, 8080, 3478, 21, etc.)
- Hardware validation (15GB disk, 2GB RAM, 2 CPU cores)
- Orphaned container cleanup
- Automatic rollback on failure

## Quick Start

### Prerequisites
- Docker 20.10+
- Docker Compose v2.0+ (or docker-compose)
- Linux host (Ubuntu/Debian/CentOS)
- Minimum 15GB free disk space

### Installation

```bash
cd /workspace/unifi-network-os
sudo ./scripts/setup.sh
```

### What Happens During Setup

1. ✅ Verifies root privileges
2. ✅ Checks Docker installation and daemon
3. ✅ Validates hardware resources
4. ✅ Scans for port conflicts
5. ✅ Cleans up orphaned containers
6. ✅ Creates directory structure
7. ✅ Generates `.env` with secure credentials
8. ✅ Pulls Docker images
9. ✅ Starts all services
10. ✅ Waits for health checks
11. ✅ Validates deployment

### Access After Setup

- **UniFi Controller**: `https://<host-ip>:8443`
- **FTP Server**: `ftp://<host-ip>:21`
  - Username: `unifi`
  - Password: (shown during setup)
- **Shared Storage**: `/workspace/unifi-network-os/storage/backups`

## Directory Structure

```
/workspace/unifi-network-os/
├── docker-compose.yml      # Service definitions
├── scripts/
│   ├── setup.sh           # Main setup script
│   └── backup.sh          # Automated backup script
├── config/                # UniFi configuration
├── db-data/               # MongoDB database
├── storage/
│   └── backups/           # Shared FTP backup location
├── logs/                  # Application logs
├── vsftpd_config/         # FTP configuration
└── .env                   # Environment variables (auto-generated)
```

## Ports Used

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| 8443 | TCP | UniFi | Web UI (HTTPS) |
| 8080 | TCP | UniFi | Device communication |
| 3478 | UDP | UniFi | STUN |
| 10001 | UDP | UniFi | Device discovery |
| 8081 | TCP | UniFi | HTTP redirect |
| 8843 | TCP | UniFi | HTTPS portal |
| 6789 | TCP | UniFi | Speed test |
| 5514 | UDP | UniFi | Syslog |
| 21 | TCP | vsftpd | FTP control |
| 30000-30010 | TCP | vsftpd | FTP passive mode |
| 27017 | TCP | MongoDB | Database (internal) |

## Hardware Recommendations

### Small Deployment (Up to 50 devices)
- CPU: 2 cores
- RAM: 4 GB
- Storage: 20 GB SSD

### Medium Deployment (50-200 devices)
- CPU: 4 cores
- RAM: 8 GB
- Storage: 50 GB SSD

### Large Deployment (200+ devices)
- CPU: 8 cores
- RAM: 16 GB
- Storage: 100 GB NVMe

## Management Commands

### View Status
```bash
cd /workspace/unifi-network-os
docker compose ps
```

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f unifi-controller
docker compose logs -f unifi-mongo
docker compose logs -f vsftpd
```

### Restart Services
```bash
docker compose restart
```

### Stop All Services
```bash
docker compose down
```

### Complete Reset
```bash
docker compose down -v
sudo rm -rf config db-data storage logs vsftpd_config .env
sudo ./scripts/setup.sh
```

## Backup Strategy

### Manual Backup via FTP
```bash
# Connect to FTP
ftp <host-ip>
# Login: unifi / <password>
# Upload files to /backups
```

### Automated Backup Script
```bash
./scripts/backup.sh
```

### Restore from Backup
1. Stop UniFi controller: `docker compose stop unifi-controller`
2. Copy backup to config directory
3. Start UniFi controller: `docker compose start unifi-controller`

## Troubleshooting

### UniFi Controller Won't Start
```bash
# Check logs
docker compose logs unifi-controller

# Verify MongoDB is healthy
docker compose ps unifi-mongo

# Restart services
docker compose restart mongo unifi-controller
```

### FTP Connection Issues
```bash
# Check passive ports
docker compose logs vsftpd

# Verify firewall rules
sudo ufw allow 30000:30010/tcp
```

### Port Conflicts
```bash
# Check what's using a port
sudo ss -tuln | grep :8443

# Stop conflicting service or change port in docker-compose.yml
```

## Security Best Practices

1. **Firewall Configuration**
   ```bash
   sudo ufw allow 8443/tcp
   sudo ufw allow 21/tcp
   sudo ufw allow 30000:30010/tcp
   ```

2. **Regular Updates**
   ```bash
   docker compose pull
   docker compose up -d
   ```

3. **Backup Credentials**
   - Save the `.env` file securely
   - Store passwords in a password manager

4. **Monitor Resources**
   ```bash
   docker stats
   ```

## Support

- UniFi Documentation: https://help.ui.com/hc/en-us/articles/115012169767
- Docker Image: https://github.com/linuxserver/docker-unifi-network-application
- Issue Reports: Check logs in `/workspace/unifi-network-os/logs/`
