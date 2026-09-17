# UniFi Network OS - Enterprise File System Integration

## Professional Network Engineer Deployment with vsftpd Pre-configured Server

This solution provides a production-ready, auto-dynamic Docker deployment of UniFi Network OS integrated with a pre-configured vsftpd FTP server for shared storage and backup operations.

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    FRONTEND NETWORK (Public)                     │
│  ┌──────────────┐         ┌──────────────┐                      │
│  │   UniFi      │◄───────►│    vsftpd    │                      │
│  │  Controller  │         │    Server    │                      │
│  │  (Port 8443) │         │  (Port 21)   │                      │
│  └──────┬───────┘         └──────▲───────┘                      │
│         │                        │                               │
├─────────┼────────────────────────┼──────────────────────────────┤
│         │                SHARED STORAGE                         │
│         │         /data/shared-storage                          │
│         │        (UniFi Backups ↔ FTP Access)                   │
├─────────▼───────────────────────────────────────────────────────┤
│                   INTERNAL NETWORK (Isolated)                    │
│  ┌──────────────┐                                               │
│  │   MongoDB    │◄────── No External Access                     │
│  │  Database    │                                               │
│  │  (Port 27017)│                                               │
│  └──────────────┘                                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Key Features

### Auto-Dynamic Configuration
- **IP Auto-Detection**: Automatically detects server's primary network interface IP
- **Hardware Analysis**: Scans RAM, CPU, and disk space to optimize resource allocation
- **Dynamic Resource Limits**: Calculates optimal CPU/RAM limits based on available hardware
- **Secure Credential Generation**: Creates strong random passwords for all services

### Professional Network Engineering
- **Network Isolation**: Separate internal network for database (security best practice)
- **Port Conflict Detection**: Validates all required ports before deployment
- **Resource Enforcement**: Hard limits on CPU/memory per container
- **Health Checks**: Automated service health monitoring with auto-recovery

### Security & Compliance
- **Root Privilege Enforcement**: Script requires sudo for proper permission handling
- **SSL/TLS Encryption**: FTPS (FTP over SSL) for secure file transfers
- **Anonymous Access Disabled**: FTP requires authentication
- **Secure Permissions**: Data directories owned by non-root user (UID 1000)

### Performance Optimization
- **WiredTiger Cache**: MongoDB cache sized dynamically (60% of allocated RAM)
- **JVM Tuning**: UniFi controller memory limits optimized for Java heap
- **Connection Rate Limiting**: FTP limited to 100KB/s, 20 max clients, 5 per IP
- **Logging Rotation**: JSON log drivers with size limits to prevent disk exhaustion

---

## 📦 Components

| Service | Image | Purpose | Network |
|---------|-------|---------|---------|
| **MongoDB** | `mongo:7.0` | Backend database for UniFi | Internal Only |
| **UniFi Controller** | `lscr.io/linuxserver/unifi-network-application` | Frontend management UI | Frontend + Internal |
| **vsftpd** | `fauria/vsftpd:latest` | FTP/S backup storage server | Frontend |

---

## 🚀 Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose Plugin v2.0+
- Linux host with 2+ CPU cores, 2GB+ RAM, 15GB+ disk
- Root/sudo access

### Installation

```bash
# Navigate to project directory
cd /workspace/unifi-enterprise-fs

# Run automated setup (requires sudo)
sudo ./scripts/setup.sh
```

### What Happens During Setup

1. ✅ **Root Check**: Verifies script runs with elevated privileges
2. ✅ **Docker Validation**: Confirms Docker daemon and Compose plugin
3. ✅ **Hardware Analysis**: Detects RAM, CPU, disk; enforces minimums
4. ✅ **Network Scan**: Auto-detects IP, checks port conflicts
5. ✅ **Credential Generation**: Creates secure random passwords
6. ✅ **Environment Config**: Writes `.env` file with all variables
7. ✅ **Directory Setup**: Creates volume mounts with proper permissions
8. ✅ **Service Deployment**: Pulls images, starts containers
9. ✅ **Health Verification**: Waits for services to become healthy

---

## 🔐 Access Information

After successful setup, the script displays:

### UniFi Network Controller
- **URL**: `https://<SERVER_IP>:8443`
- **Setup**: Complete initial wizard in browser
- **Ports**: 8443 (HTTPS), 8080 (HTTP redirect), 3478 (STUN), 10001 (Discovery)

### FTP Storage Server
- **URL**: `ftps://<SERVER_IP>:21`
- **Username**: `unifi_backup`
- **Password**: (Displayed during setup - save it!)
- **Protocol**: FTPS (FTP over explicit SSL/TLS)
- **Passive Ports**: 30000-30010

### Database (Internal)
- **Host**: `unifi-db` (internal network)
- **Port**: 27017
- **Credentials**: Displayed during setup (for disaster recovery)

---

## 📁 Directory Structure

```
unifi-enterprise-fs/
├── docker-compose.yml          # Service orchestration
├── .env                        # Auto-generated credentials (gitignored)
├── README.md                   # This documentation
├── scripts/
│   └── setup.sh               # Automated deployment script
└── data/                       # Persistent storage (created by setup)
    ├── db-data/               # MongoDB database files
    ├── db-config/             # MongoDB configuration
    ├── unifi-config/          # UniFi application config
    ├── shared-storage/        # ← Shared between UniFi & FTP
    └── ftp-logs/              # vsftpd access logs
```

### Shared Storage Workflow

1. UniFi Controller writes backups to `/storage/backups` (inside container)
2. This maps to `./data/shared-storage/` on host
3. vsftpd serves this directory at `/home/unifi_backup/`
4. FTP clients connect to download/upload backups securely

---

## ⚙️ Configuration Details

### Dynamic Resource Allocation

The setup script analyzes your hardware and allocates resources proportionally:

| Service | RAM Allocation | CPU Allocation |
|---------|---------------|----------------|
| MongoDB | 25% of total (max 2GB) | 30% of cores |
| UniFi | 35% of total (max 3GB) | 50% of cores |
| vsftpd | Fixed 256MB | Fixed 0.5 core |

**Example**: On a 4-core, 8GB system:
- MongoDB: 2GB RAM, 1.2 CPU
- UniFi: 2.8GB RAM, 2.0 CPU
- vsftpd: 256MB RAM, 0.5 CPU

### Network Ports

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| 8443 | TCP | UniFi | HTTPS web interface |
| 8080 | TCP | UniFi | HTTP portal redirect |
| 8448 | TCP | UniFi | Mobile app portal |
| 10001 | UDP | UniFi | Device discovery |
| 3478 | UDP | UniFi | STUN server |
| 21 | TCP | vsftpd | FTP control |
| 30000-30010 | TCP | vsftpd | FTP passive data |
| 27017 | TCP | MongoDB | Database (internal only) |

---

## 🔧 Management Commands

```bash
# View running containers
docker compose ps

# View logs
docker compose logs -f unifi-controller
docker compose logs -f vsftpd-server
docker compose logs -f unifi-db

# Restart a service
docker compose restart unifi-controller

# Stop all services
docker compose down

# Stop and remove volumes (WARNING: deletes data)
docker compose down -v
```

---

## 🛡️ Security Best Practices Implemented

1. **Database Isolation**: MongoDB not exposed to public network
2. **FTPS Required**: All FTP transfers encrypted via SSL/TLS
3. **No Anonymous FTP**: Authentication mandatory
4. **Strong Passwords**: 32-char DB passwords, 24-char FTP password
5. **File Permissions**: Data directories `chmod 750`, owned by UID 1000
6. **Environment Protection**: `.env` file restricted to root-only read
7. **Resource Limits**: Prevents container resource exhaustion attacks
8. **Log Rotation**: Prevents disk fill attacks via logging

---

## 📊 Monitoring & Health Checks

Each service includes Docker health checks:

- **MongoDB**: Runs `db.adminCommand('ping')` every 10s
- **UniFi**: HTTP POST to `/api/login` every 30s
- **vsftpd**: TCP connection test to port 21 every 30s

Check health status:
```bash
docker inspect --format='{{.State.Health.Status}}' unifi-db
docker inspect --format='{{.State.Health.Status}}' unifi-controller
docker inspect --format='{{.State.Health.Status}}' vsftpd-server
```

---

## 🔄 Backup Strategy

### Automated UniFi Backups
1. Configure automatic backups in UniFi Controller UI
2. Set backup location to `/storage/backups`
3. Backups automatically appear in `./data/shared-storage/`

### FTP Download
```bash
# Connect securely
lftp -u unifi_backup,<PASSWORD> ftps://<SERVER_IP>

# Download latest backup
get /unifi_backup/autobackup/unifi-backup-*.unf
```

### Manual Backup Script Example
```bash
#!/bin/bash
# Save as backup-unifi.sh
FTP_HOST="<SERVER_IP>"
FTP_USER="unifi_backup"
FTP_PASS="<PASSWORD>"

lftp -c "open -u $FTP_USER,$FTP_PASS ftps://$FTP_HOST; \
         mirror /unifi_backup /local/backup/location"
```

---

## 🐛 Troubleshooting

### Common Issues

**Container won't start:**
```bash
# Check logs
docker compose logs <service-name>

# Verify .env file exists and has correct values
cat .env
```

**Cannot access UniFi UI:**
```bash
# Check if port 8443 is listening
ss -tuln | grep 8443

# Verify firewall allows traffic
sudo ufw allow 8443/tcp
```

**FTP connection fails:**
```bash
# Ensure passive ports are open in firewall
sudo ufw allow 30000:30010/tcp

# Test FTP connection
ftp -p <SERVER_IP>
```

**Database connection errors:**
```bash
# Verify internal network connectivity
docker exec unifi-controller ping -c 3 unifi-db

# Check MongoDB health
docker exec unifi-db mongosh --eval "db.adminCommand('ping')"
```

---

## 📈 Performance Tuning

For high-load environments (100+ devices):

1. **Increase RAM**: Edit `.env` and raise `UNIFI_MEM_LIMIT`
2. **SSD Storage**: Ensure `./data` is on SSD for database performance
3. **CPU Priority**: Adjust `DB_CPU_LIMIT` and `UNIFI_CPU_LIMIT`
4. **Network MTU**: Optimize Docker network MTU for your infrastructure

---

## 📝 License & Credits

- UniFi Network Application by Ubiquiti Inc.
- MongoDB by MongoDB Inc.
- vsftpd by Chris Evans
- Docker Compose configuration for educational/professional use

---

## 🆘 Support

For issues related to:
- **UniFi Controller**: Consult [UniFi Community](https://community.ui.com)
- **MongoDB**: See [MongoDB Docs](https://docs.mongodb.com)
- **Docker/Compose**: Check [Docker Docs](https://docs.docker.com)
- **This Setup**: Review logs and verify system requirements
