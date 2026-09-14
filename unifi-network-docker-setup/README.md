# UniFi Network OS - Auto-Dynamic Enforced Docker Setup

## Overview

This is a **fully automated, self-enforcing** deployment solution for UniFi Network OS with integrated vsftpd server for shared storage and backups. The setup script enforces strict security and hardware requirements before deployment.

## Features

### Auto-Dynamic Capabilities
- ✅ **Automatic IP Detection** - Dynamically detects server IP address
- ✅ **Secure Password Generation** - Generates cryptographically secure passwords for MongoDB and FTP
- ✅ **Resource Validation** - Enforces minimum hardware requirements (10GB disk, 1.5GB RAM)
- ✅ **Port Conflict Detection** - Checks for port availability before deployment
- ✅ **Health Check Enforcement** - Validates service health before completing setup

### Security Enforcements
- 🔒 **Root Privilege Required** - Ensures proper permissions for Docker operations
- 🔒 **Strict Directory Permissions** - Sets appropriate file system permissions
- 🔒 **SSL/TLS Enabled** - Pre-configured SSL for both UniFi and FTP
- 🔒 **No Anonymous FTP** - Disabled anonymous access by default

### Architecture
- **UniFi Network Controller** - Manages UniFi devices
- **MongoDB 7.0** - Database backend with health checks
- **vsftpd Server** - FTP server for shared storage and backups
- **Shared Storage Volume** - Both UniFi and FTP access `/unifi-storage`

## Quick Start

```bash
cd /workspace/unifi-network-docker-setup
sudo ./setup.sh
```

That's it! The script will:
1. Verify root privileges
2. Check Docker installation
3. Validate hardware resources
4. Check port availability
5. Generate secure credentials
6. Create directory structure
7. Deploy containers
8. Verify health checks
9. Display access information

## Access Information

After successful deployment:

| Service | URL | Credentials |
|---------|-----|-------------|
| UniFi Controller | `https://<SERVER_IP>:8443` | Setup wizard on first login |
| FTP Server | `ftp://<SERVER_IP>:21` | User: `unifi`, Password: (shown during setup) |
| Shared Storage | `/workspace/unifi-network-docker-setup/unifi-storage` | N/A |

## Hardware Requirements

### Minimum (Enforced)
- **CPU**: 2 cores
- **RAM**: 1.5 GB
- **Disk**: 10 GB free space
- **OS**: Linux with Docker installed

### Recommended
- **CPU**: 4 cores
- **RAM**: 4-8 GB
- **Disk**: 50 GB SSD
- **Network**: Gigabit Ethernet

## Ports Used

| Port | Protocol | Service |
|------|----------|---------|
| 8443 | TCP | UniFi HTTPS Interface |
| 8080 | TCP | UniFi HTTP Portal |
| 3478 | UDP | STUN |
| 10001 | UDP | UniFi Discovery |
| 8843 | TCP | RTSP |
| 21 | TCP | FTP Control |
| 30000-30010 | TCP | FTP Passive Mode |
| 27017 | TCP | MongoDB (internal) |

## File Structure

```
/workspace/unifi-network-docker-setup/
├── setup.sh              # Main enforcement script
├── docker-compose.yml    # Service definitions
├── .env                  # Auto-generated credentials (created by setup.sh)
├── unifi-data/           # UniFi configuration
├── unifi-db-data/        # MongoDB data
├── unifi-storage/        # Shared storage (backups, FTP files)
│   └── backups/          # UniFi backup location
├── vsftpd-config/        # FTP configuration
│   └── vsftpd.conf       # FTP server config
├── vsftpd-data/          # FTP user directories
│   └── unifi/            # FTP user home
└── vsftpd-logs/          # FTP logs
```

## Management Commands

```bash
# View logs
docker compose logs -f

# View specific service logs
docker compose logs -f unifi-network
docker compose logs -f mongodb
docker compose logs -f vsftpd

# Stop services
docker compose down

# Restart services
docker compose restart

# Backup UniFi configuration
# Files are automatically saved to: ./unifi-storage/backups/

# Access FTP manually
ftp <SERVER_IP>
# Username: unifi
# Password: (from setup output)
```

## Troubleshooting

### Setup Fails at Root Check
```bash
sudo ./setup.sh
```

### Port Conflicts
Check which process is using a port:
```bash
sudo ss -tuln | grep :8443
sudo lsof -i :8443
```

### Health Check Timeout
If UniFi takes longer to start:
```bash
docker compose logs -f unifi-network
# Wait for "INFO: Server startup complete"
```

### Reset Deployment
```bash
docker compose down -v
rm .env
sudo ./setup.sh
```

## Automated Backups

The setup includes automatic backup capability:
- UniFi stores backups in `./unifi-storage/backups/`
- FTP server provides remote access to these backups
- Both services share the same storage volume

To manually trigger a backup from the UniFi interface:
1. Go to Settings → System → Backup
2. Click "Download" or configure automatic backups

## Security Notes

1. **Save Credentials**: The `.env` file contains all passwords. Store it securely.
2. **Firewall**: Configure your firewall to allow only necessary ports.
3. **SSL Certificates**: Replace snakeoil certificates with valid ones for production.
4. **Regular Updates**: Keep Docker images updated for security patches.

## Support

For issues:
1. Check logs: `docker compose logs -f`
2. Verify resources: `docker stats`
3. Review hardware requirements above
4. Ensure Docker daemon is running: `systemctl status docker`

---

**Version**: 2.0 (Enforced Auto-Dynamic)  
**Last Updated**: 2024  
**License**: MIT
