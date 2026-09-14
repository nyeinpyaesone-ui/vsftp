# UniFi Network OS - Auto-Dynamic Docker Setup

## Overview

This is a fully automated, dynamic deployment solution for UniFi Network OS with integrated vsftpd FTP server for shared storage and backups. The setup automatically:

- **Detects server IP** address dynamically
- **Generates secure passwords** for all services
- **Checks system resources** (disk space, memory)
- **Configures optimal settings** based on hardware capacity
- **Sets up shared storage** between UniFi and FTP server

## Quick Start

```bash
cd /workspace/unifi-network-docker-setup
./setup.sh
```

That's it! The script handles everything automatically.

## Features

### Auto-Dynamic Configuration

✅ **Automatic Server IP Detection** - No manual IP configuration needed  
✅ **Secure Password Generation** - Cryptographically secure random passwords  
✅ **Resource Detection** - Checks disk space and memory availability  
✅ **Dynamic Environment Setup** - Creates `.env` file with all configurations  

### Pre-Configured Services

- **UniFi Network Application** - Latest version with health checks
- **MongoDB 7.0** - Database with automatic initialization
- **vsftpd FTP Server** - Pre-configured with SSL and passive mode

### Shared Storage Architecture

```
./unifi-storage/          # Shared storage directory
├── backups/              # UniFi automatic backups (FTP accessible)
└── logs/                 # System logs
```

Both UniFi and FTP server have access to the same storage directory.

## Hardware Requirements

### Minimum (Up to 50 devices)
- CPU: 2 cores
- RAM: 2GB
- Storage: 10GB

### Recommended (50-200 devices)
- CPU: 4 cores
- RAM: 4-8GB
- Storage: 50GB SSD

### Enterprise (200+ devices)
- CPU: 8 cores
- RAM: 16-32GB
- Storage: 100GB+ NVMe

## Access Information

After setup completes:

- **UniFi Controller**: `https://<server-ip>:8443`
- **FTP Server**: `ftp://<server-ip>:21`
- **FTP Username**: `unifi`
- **FTP Password**: (shown during setup, also in `.env` file)

## Directory Structure

```
unifi-network-docker-setup/
├── docker-compose.yml      # Service definitions
├── setup.sh               # Auto-dynamic setup script
├── backup.sh              # Automated backup script
├── .env                   # Generated environment variables
├── unifi-data/            # UniFi configuration
├── unifi-db-data/         # MongoDB data
├── unifi-storage/         # Shared storage
│   ├── backups/           # Backup files
│   └── logs/              # Logs
├── mongodb-init/          # Database initialization
└── vsftpd-config/         # FTP configuration
    └── vsftpd.conf
```

## Manual Operations

### View Logs
```bash
docker compose logs -f
```

### Stop Services
```bash
docker compose down
```

### Restart Services
```bash
docker compose restart
```

### Update UniFi
```bash
docker compose pull
docker compose up -d
```

### Backup Management

Manual backup to FTP storage:
```bash
./backup.sh
```

Scheduled backups (add to crontab):
```bash
0 2 * * * /path/to/backup.sh
```

## Security Notes

⚠️ **Save your credentials!** The setup script generates secure random passwords displayed only once during setup. They are also stored in the `.env` file.

- Change default passwords in production
- Use SSL/TLS for FTP (configured by default)
- Restrict FTP access to trusted networks
- Regularly update Docker images

## Troubleshooting

### Services won't start
```bash
# Check Docker status
docker info

# View error logs
docker compose logs
```

### Can't access UniFi controller
```bash
# Check if ports are open
netstat -tlnp | grep 8443

# Verify container is running
docker compose ps
```

### FTP connection issues
```bash
# Check FTP logs
docker logs unifi-ftp

# Verify passive ports
iptables -L -n | grep 30000
```

## Support

For UniFi-specific issues: https://community.ui.com  
For Docker issues: https://docs.docker.com  

---

**License**: MIT  
**Version**: 2.0 (Auto-Dynamic)
