# Quick Start Guide

## For Systems with Docker Already Running

If Docker is already installed and running on your system, follow these steps:

### 1. Navigate to the Setup Directory
```bash
cd /workspace/unifi-network-docker-setup
```

### 2. Update Server IP
Edit `docker-compose.yml` and replace `YOUR_SERVER_IP_HERE` with your actual server IP address:
```bash
nano docker-compose.yml
# or
vim docker-compose.yml
```

Also update the same IP in `vsftpd-config/vsftpd.conf`:
```bash
nano vsftpd-config/vsftpd.conf
```

### 3. Run the Setup Script
```bash
./setup.sh
```

### 4. Access UniFi Network Application
- Open your web browser
- Navigate to: `https://<your-server-ip>:8443`
- Accept the SSL certificate warning
- Complete the setup wizard

### 5. Access FTP Server
- Host: `<your-server-ip>`
- Port: 21
- Username: `unifi`
- Password: `unifi_ftp_password`

## Storage Capacity Information

### Default Storage Allocation
- **UniFi Configuration**: `./unifi-data` (mapped to `/config` in container)
- **Shared Storage**: `./unifi-storage` (accessible by both UniFi and vsftpd)
- **Database**: `./unifi-db-data` (MongoDB data)

### Expanding Storage

To expand storage capacity, edit `docker-compose.yml` and change volume mappings:

```yaml
volumes:
  - /path/to/larger/disk/unifi-data:/config
  - /path/to/larger/disk/unifi-storage:/storage
```

Or add additional volumes:

```yaml
volumes:
  - ./unifi-data:/config
  - ./unifi-storage:/storage
  - ./unifi-backups:/backups  # Additional backup storage
```

### Monitoring Storage Usage

```bash
# Check UniFi storage
docker exec unifi-network-application df -h /config

# Check shared storage
docker exec unifi-network-application df -h /storage
docker exec vsftpd-server df -h /home/vsftpd

# View detailed usage
docker exec unifi-network-application du -sh /config/*
docker exec vsftpd-server du -sh /home/vsftpd/unifi/*
```

## Hardware Recommendations

### Minimum (Up to 50 devices)
- CPU: 2 cores @ 2.0 GHz
- RAM: 2 GB
- Storage: 10 GB

### Recommended (50-200 devices)
- CPU: 4 cores @ 2.5 GHz
- RAM: 4-8 GB
- Storage: 50 GB SSD

### Enterprise (200+ devices)
- CPU: 8 cores @ 3.0 GHz+
- RAM: 16-32 GB
- Storage: 100+ GB NVMe SSD

## Backup Your Setup

Run the backup script regularly:
```bash
./backup.sh
```

Schedule automated backups with cron:
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /workspace/unifi-network-docker-setup/backup.sh
```

## Troubleshooting

### Services Won't Start
```bash
# Check Docker status
docker info

# View logs
docker-compose logs
```

### Can't Access Web Interface
```bash
# Check if ports are listening
netstat -tlnp | grep 8443

# Check firewall
iptables -L -n
```

### FTP Connection Issues
```bash
# Verify vsftpd is running
docker-compose ps vsftpd

# Check passive port range
netstat -tlnp | grep 3000
```

## Support

For more detailed information, see README.md
