# Professional UniFi Network OS with vsftpd Integration

## Overview
Production-ready Docker deployment of UniFi Network OS with pre-configured vsftpd server for professional network data management and backup services.

## Architecture

### Services
1. **MongoDB 7.0** - Professional database layer with WiredTiger optimization
2. **UniFi Network Controller** - Backend network management system
3. **vsftpd** - Secure FTP server for backup storage access

### Network Topology
- **unifi-internal**: Isolated network (172.28.0.0/16) for MongoDB ↔ UniFi communication
- **unifi-frontend**: Front network (172.29.0.0/16) for external access to UniFi and FTP

### Storage Integration
```
./data/
├── unifi/          → UniFi configuration (/config)
├── db/             → MongoDB data (/data/db)
└── ftp-backups/    → Shared storage
    ├── Mounted to UniFi as /backups
    └── Mounted to vsftpd as /home/unifi_backup
```

## Features

### Security Enforcement
- ✅ Root privilege verification
- ✅ Secure credential generation (32-char random passwords)
- ✅ File permissions (600 for .env, 700 for DB)
- ✅ SSL/TLS for FTP (FTPS)
- ✅ Internal network isolation for database

### Resource Management
| Service | CPU Limit | Memory Limit |
|---------|-----------|--------------|
| MongoDB | 2.0 cores | 2GB |
| UniFi   | 3.0 cores | 3GB |
| vsftpd  | 0.5 cores | 256MB |

### Networking Protocols
- **TCP**: HTTPS (8443), HTTP (8080, 8880), FTP (21)
- **UDP**: STUN (3478), Discovery (10001), SSDP (1900)
- **FTP Passive Mode**: Ports 50000-50100
- **Rate Limiting**: 100KB/s per FTP connection, 20 max clients

### Auto-Dynamic Configuration
- Server IP auto-detection
- Timezone auto-detection
- Secure password generation
- Port conflict detection
- Hardware validation (20GB disk, 3GB RAM, 2 CPU cores)

## Quick Start

```bash
cd /workspace/professional-unifi-network
sudo ./scripts/setup.sh
```

## Access Points

After successful deployment:

### UniFi Network Controller
- **URL**: `https://<SERVER_IP>:8443`
- **Setup**: Complete initial wizard in browser

### FTP Backup Server
- **Host**: `<SERVER_IP>`
- **Port**: 21
- **Username**: `unifi_backup`
- **Password**: (displayed during setup)
- **Protocol**: FTPS (FTP over SSL)

## Backup Workflow

1. Configure UniFi to save backups to `/backups`
2. Backups automatically appear in `./data/ftp-backups/`
3. Access via FTP client for remote retrieval
4. Files stored persistently on host

## Hardware Requirements

### Minimum
- CPU: 2 cores
- RAM: 3GB
- Storage: 20GB SSD

### Recommended
- CPU: 4 cores
- RAM: 8GB
- Storage: 50GB NVMe

## Troubleshooting

### View Logs
```bash
docker compose logs -f unifi-controller
docker compose logs -f mongodb
docker compose logs -f vsftpd
```

### Restart Services
```bash
docker compose restart
```

### Check Status
```bash
docker compose ps
```

## Configuration Files

- `docker-compose.yml` - Service orchestration
- `.env` - Auto-generated credentials (created by setup.sh)
- `configs/mongo/mongod.conf` - Database tuning
- `configs/vsftpd/vsftpd.conf` - FTP server settings

## Production Notes

1. **Backup the .env file** - Contains all credentials
2. **Enable firewall** - Only expose required ports
3. **Use SSL certificates** - Replace snakeoil certs in production
4. **Monitor resources** - Adjust limits based on device count
5. **Regular updates** - Keep Docker images current
