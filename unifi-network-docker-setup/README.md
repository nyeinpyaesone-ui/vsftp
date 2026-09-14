# UniFi Network OS Docker Setup Guide

This guide provides instructions for installing UniFi Network OS in a Docker container with vsftpd pre-configured for file storage.

## Prerequisites

- Docker installed and running on your host system
- At least 2GB of available RAM
- At least 10GB of available disk space
- Ports available: 8080, 8443, 3478 (UDP), 10001 (UDP), 27117

## Docker Compose Configuration

Create a `docker-compose.yml` file with the following configuration:

```yaml
version: '3.8'

services:
  unifi-network:
    image: lscr.io/linuxserver/unifi-network-application:latest
    container_name: unifi-network-application
    environment:
      - PUID=1000
      - PGID=1000
      - MEM_LIMIT=2048
      - MEM_STARTUP=1024
      - MONGO_HOST=unifi-db
      - MONGO_PORT=27017
      - MONGO_DBNAME=unifi
      - MONGO_USER=unifi
      - MONGO_PASS=unifi_password
    volumes:
      - ./unifi-data:/config
      - ./unifi-storage:/storage
    ports:
      - 8080:8080
      - 8443:8443
      - 3478:3478/udp
      - 10001:10001/udp
      - 27117:27117
    depends_on:
      - unifi-db
    restart: unless-stopped
    networks:
      - unifi-network

  unifi-db:
    image: mongo:6.0
    container_name: unifi-db
    environment:
      - MONGO_INITDB_DATABASE=unifi
      - MONGO_INITDB_ROOT_USERNAME=unifi
      - MONGO_INITDB_ROOT_PASSWORD=unifi_password
    volumes:
      - ./unifi-db-data:/data/db
    restart: unless-stopped
    networks:
      - unifi-network

  vsftpd:
    image: fauria/vsftpd
    container_name: vsftpd-server
    environment:
      - FTP_USER=unifi
      - FTP_PASS=unifi_ftp_password
      - PASV_ADDRESS=<YOUR_SERVER_IP>
      - PASV_MIN_PORT=30000
      - PASV_MAX_PORT=30010
    volumes:
      - ./unifi-storage:/home/vsftpd/unifi
      - ./vsftpd-config:/etc/vsftpd
    ports:
      - 21:21
      - 30000-30010:30000-30010
    restart: unless-stopped
    networks:
      - unifi-network

networks:
  unifi-network:
    driver: bridge
```

## Installation Steps

### Step 1: Create Directory Structure

```bash
mkdir -p unifi-data unifi-storage unifi-db-data vsftpd-config
```

### Step 2: Create Docker Compose File

Save the above docker-compose.yml in your project directory.

### Step 3: Configure vsftpd

Create `vsftpd-config/vsftpd.conf`:

```conf
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
pasv_address=<YOUR_SERVER_IP>
chroot_local_user=YES
allow_writeable_chroot=YES
user_sub_token=$USER
local_root=/home/vsftpd/$USER
max_clients=50
max_per_ip=10
```

### Step 4: Start the Services

```bash
docker-compose up -d
```

### Step 5: Verify Services are Running

```bash
docker-compose ps
```

### Step 6: Access UniFi Network Application

1. Open your web browser
2. Navigate to: `https://<your-server-ip>:8443`
3. Accept the self-signed certificate warning
4. Complete the initial setup wizard

## Storage Capacity Configuration

### UniFi Network OS Storage

The UniFi Network application stores:
- Configuration backups
- Firmware updates
- Site data
- Logs
- Statistics data

Default storage location: `/config` (mapped to `./unifi-data`)
Additional storage: `/storage` (mapped to `./unifi-storage`)

### vsftpd Storage Integration

The vsftpd server is configured to share the same storage volume as UniFi:
- FTP users can access files in `/home/vsftpd/unifi`
- This is mapped to `./unifi-storage` on the host
- UniFi can backup configurations to this location

### Adjusting Storage Capacity

To increase storage capacity:

1. **Option A**: Use bind mounts to larger host directories
   ```yaml
   volumes:
     - /path/to/larger/storage:/config
     - /path/to/larger/backup:/storage
   ```

2. **Option B**: Use Docker volumes with size limits
   ```yaml
   volumes:
     unifi-config:
       driver: local
       driver_opts:
         type: none
         o: bind
         device: /path/to/storage
   ```

3. **Option C**: Add additional storage volumes
   ```yaml
   volumes:
     - ./unifi-data:/config
     - ./unifi-storage:/storage
     - ./unifi-backups:/backups
   ```

## Hardware Requirements

### Minimum Requirements
- CPU: Dual-core 2.0 GHz
- RAM: 2 GB
- Storage: 10 GB

### Recommended Requirements
- CPU: Quad-core 2.5 GHz or higher
- RAM: 4-8 GB
- Storage: 50+ GB SSD

### For Large Deployments (100+ devices)
- CPU: 8 cores 3.0 GHz+
- RAM: 16-32 GB
- Storage: 100+ GB NVMe SSD

## Monitoring Storage Usage

### Check UniFi Storage
```bash
docker exec unifi-network-application df -h /config
docker exec unifi-network-application du -sh /config/*
```

### Check vsftpd Storage
```bash
docker exec vsftpd-server df -h /home/vsftpd
docker exec vsftpd-server du -sh /home/vsftpd/unifi/*
```

### Monitor via Docker Stats
```bash
docker stats unifi-network-application unifi-db vsftpd-server
```

## Backup Configuration

### Automated Backups Script

Create `backup.sh`:

```bash
#!/bin/bash

BACKUP_DIR="/backup/unifi"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup UniFi configuration
docker exec unifi-network-application tar czf /tmp/unifi_backup_$DATE.tar.gz /config
docker cp unifi-network-application:/tmp/unifi_backup_$DATE.tar.gz $BACKUP_DIR/

# Backup database
docker exec unifi-db mongodump --archive=/tmp/db_backup_$DATE.archive --db unifi
docker cp unifi-db:/tmp/db_backup_$DATE.archive $BACKUP_DIR/

# Copy to vsftpd storage
cp $BACKUP_DIR/unifi_backup_$DATE.tar.gz ./unifi-storage/backups/
cp $BACKUP_DIR/db_backup_$DATE.archive ./unifi-storage/backups/

echo "Backup completed: $DATE"
```

## Troubleshooting

### Common Issues

1. **Cannot access web interface**
   - Check if ports are open: `netstat -tlnp | grep 8443`
   - Verify container is running: `docker-compose ps`
   - Check logs: `docker-compose logs unifi-network`

2. **FTP connection issues**
   - Ensure passive ports are open in firewall
   - Verify PASV_ADDRESS is set correctly
   - Check vsftpd logs: `docker-compose logs vsftpd`

3. **Storage full errors**
   - Clean old backups: `docker exec unifi-network-application rm -rf /config/backup/*`
   - Increase volume size
   - Archive old data

4. **Database connection errors**
   - Wait for MongoDB to fully start
   - Check credentials match in both services
   - Restart database: `docker-compose restart unifi-db`

## Security Considerations

1. Change default passwords immediately
2. Use strong passwords for FTP and MongoDB
3. Enable SSL/TLS for all connections
4. Regularly update containers
5. Restrict network access using firewall rules
6. Consider using a reverse proxy with Let's Encrypt certificates

## Network Ports Reference

| Port | Protocol | Purpose |
|------|----------|---------|
| 8080 | TCP | Device communication |
| 8443 | TCP | Web interface |
| 3478 | UDP | STUN |
| 10001 | UDP | Device discovery |
| 27117 | TCP | Database access |
| 21 | TCP | FTP control |
| 30000-30010 | TCP | FTP passive mode |
