# UniFi Network OS - Auto-Dynamic Setup with Enforcement & Rate Limiting

## 📋 Overview

This deployment provides a **production-ready** UniFi Network OS server with:
- ✅ **Auto-dynamic configuration** (IP detection, password generation)
- ✅ **Enforcement policies** (root checks, resource validation, port conflicts)
- ✅ **Rate limiting** (FTP I/O throttling to prevent DB starvation)
- ✅ **Gap analysis** (pre-flight checks for hardware, Docker, ports)
- ✅ **Shared storage** between UniFi and vsftpd for seamless backups

## 🚀 Quick Start

```bash
cd /workspace/unifi-network-docker-setup
sudo ./setup.sh
```

## 🔒 Security & Enforcement Features

### Pre-Flight Checks (Gap Analysis)
1. **Root Privilege Enforcement** - Aborts if not run as sudo
2. **Docker Validation** - Checks version, daemon status, Compose plugin
3. **Hardware Resources**:
   - Minimum 15GB disk space
   - Minimum 2GB RAM (with swap fallback)
   - Minimum 2 CPU cores
4. **Port Conflict Detection** - Scans ports 8443, 8080, 8843, 3478, 10001, 6789, 21
5. **Container Cleanup** - Removes orphaned containers before deployment

### Rate Limiting Policies

#### FTP Storage I/O Limits (Prevents UniFi DB Starvation)
```yaml
vsftpd:
  local_max_rate=51200        # 50 KB/s per connection
  max_clients=10              # Max concurrent connections
  max_per_ip=3                # Max connections per IP
  blkio_config:
    device_read_bps: 50mb     # Block I/O read limit
    device_write_bps: 50mb    # Block I/O write limit
```

#### Resource Limits by Hardware Tier
| Hardware | CPU Limit | Memory Limit | MongoDB Cache |
|----------|-----------|--------------|---------------|
| 2-4GB RAM | 1.5 cores | 1.5GB | 0.5GB |
| 4-8GB RAM | 2.0 cores | 2GB | 0.5GB |
| 8GB+ RAM | 4.0 cores | 4GB | 0.5GB |

## 📁 Directory Structure

```
unifi-network-docker-setup/
├── docker-compose.yml          # Service definitions with rate limits
├── setup.sh                    # Auto-dynamic setup script
├── .env                        # Generated credentials (chmod 600)
├── vsftpd-config/
│   └── vsftpd.conf             # FTP config with rate limiting
├── scripts/
│   └── backup.sh               # Automated backup with retention
├── unifi-data/                 # UniFi configuration
├── unifi-db-data/              # MongoDB database
└── unifi-storage/
    └── backups/                # Shared backup location
```

## 🔑 Access Information

After running `./setup.sh`, you'll receive:

```
UniFi Controller: https://<AUTO-DETECTED-IP>:8443
FTP Server:       ftp://<AUTO-DETECTED-IP>:21
FTP Username:     unifi
FTP Password:     <RANDOM_24_CHAR>
MongoDB User:     unifi_admin
MongoDB Pass:     <RANDOM_32_CHAR>
```

⚠️ **SAVE THESE CREDENTIALS IMMEDIATELY** - They are shown only once!

## 🛡️ Error Prevention & Gap Fixes

### Common Issues Addressed

| Issue | Prevention Method |
|-------|-------------------|
| Port conflicts | Pre-deployment scan with `ss -tuln` |
| OOM kills | Memory limits + swap validation |
| DB I/O starvation | FTP block I/O rate limiting (50MB/s) |
| Device flooding | UniFi MEM_LIMIT enforcement |
| Backup corruption | SHA256 checksum verification |
| Disk full | 15GB minimum requirement check |
| Permission errors | Automatic chmod 600/700/755 |

### Health Check Enforcement

```yaml
mongo:
  healthcheck:
    test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping').ok"]
    start_period: 40s
    
unifi-controller:
  healthcheck:
    test: ["CMD-SHELL", "curl -sfk https://localhost:8443"]
    start_period: 90s
```

## 🔄 Automated Backup

Run the backup script manually or via cron:

```bash
# Manual backup
sudo ./scripts/backup.sh

# Cron job (daily at 2 AM)
echo "0 2 * * * root /workspace/unifi-network-docker-setup/scripts/backup.sh" >> /etc/cron.d/unifi-backup
```

### Backup Features
- ✅ Automatic backup extraction from UniFi container
- ✅ SHA256 checksum verification
- ✅ Retention policy (keeps last 7 backups)
- ✅ Optional external FTP upload with rate limiting
- ✅ Email/webhook notifications

## ⚙️ Configuration Options

Edit `.env` after initial setup (optional):

```bash
# External FTP backup (disabled by default)
EXTERNAL_FTP_ENABLED=true
EXTERNAL_FTP_HOST=backup.example.com
EXTERNAL_FTP_USER=backup_user
EXTERNAL_FTP_PASS=secure_password

# Notifications
NOTIFY_ENABLED=true
NOTIFY_EMAIL=admin@example.com
WEBHOOK_URL=https://hooks.slack.com/services/xxx
```

## 📊 Monitoring & Troubleshooting

### Check Service Status
```bash
docker compose ps
docker compose logs unifi-controller
docker compose logs unifi-ftp
```

### Verify Rate Limiting
```bash
# Monitor FTP I/O
docker stats unifi-ftp

# Check MongoDB performance
docker exec unifi-mongo mongosh --eval "db.serverStatus().metrics"
```

### View Logs
```bash
tail -f setup.log
tail -f backup.log
```

## 🏗️ Hardware Requirements

### Minimum (Up to 50 devices)
- 2 CPU cores
- 2GB RAM + 2GB swap
- 15GB storage

### Recommended (50-200 devices)
- 4 CPU cores
- 4-8GB RAM
- 50GB SSD

### Enterprise (200+ devices)
- 8 CPU cores
- 16-32GB RAM
- 100GB+ NVMe

## 🔧 Advanced: Custom Rate Limits

To adjust FTP rate limiting, edit `vsftpd-config/vsftpd.conf`:

```conf
# Increase to 100 KB/s (use caution)
local_max_rate=102400

# Or decrease for slower systems
local_max_rate=25600
```

Then restart:
```bash
docker compose restart vsftpd
```

## 📝 Notes

1. **SSL Certificate Warning**: UniFi uses a self-signed certificate. Accept the warning in your browser.
2. **First Boot**: Takes 2-3 minutes for Java to initialize.
3. **Adoption**: Ensure devices can reach ports 8080, 8443, 3478, 10001.
4. **Backup Location**: Files saved to `./unifi-storage/backups/` are accessible via FTP.

## 🆘 Support

For issues:
1. Check `setup.log` for installation errors
2. Run `docker compose logs` for service errors
3. Verify hardware meets minimum requirements
4. Ensure no port conflicts exist

---

**Version**: 2.0 (Enforcement + Rate Limiting Enabled)  
**Last Updated**: Auto-dynamic with gap analysis
