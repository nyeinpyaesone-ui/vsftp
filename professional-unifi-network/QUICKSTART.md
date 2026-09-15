# Professional UniFi Network OS - Quick Start Guide

## One-Command Deployment

```bash
cd /workspace/professional-unifi-network
sudo ./scripts/setup.sh
```

## What Happens During Setup

1. ✅ **Enforcement Checks**
   - Root privileges verified
   - Docker daemon validated
   - Hardware resources checked (20GB disk, 3GB RAM, 2 CPU)
   - Port conflicts detected (8443, 8080, 21, 27017, etc.)

2. ✅ **Auto-Dynamic Configuration**
   - Server IP auto-detected
   - Timezone auto-configured
   - Secure passwords generated (32-char random)
   - `.env` file created automatically

3. ✅ **Service Deployment**
   - MongoDB 7.0 with WiredTiger optimization
   - UniFi Network Controller
   - vsftpd with SSL/TLS enabled

## Access After Deployment

### UniFi Network Controller
- **URL**: `https://<YOUR_SERVER_IP>:8443`
- **Action**: Complete the setup wizard in your browser

### FTP Backup Server
- **Host**: `<YOUR_SERVER_IP>`
- **Port**: 21
- **Username**: `unifi_backup`
- **Password**: (shown during setup - SAVE IT!)
- **Protocol**: FTPS (FTP over SSL recommended)

## Configure UniFi Backups

1. Login to UniFi Controller at `https://<IP>:8443`
2. Go to **Settings** → **System** → **Backup**
3. Set backup location to: `/backups`
4. Enable automatic backups
5. Files will appear in `./data/ftp-backups/` and be accessible via FTP

## Verify Installation

```bash
# Check all services running
docker compose ps

# View logs
docker compose logs -f

# Test FTP connection
ftp <YOUR_SERVER_IP>
# Username: unifi_backup
# Password: (from setup output)
```

## Common Commands

```bash
# Stop all services
docker compose down

# Restart services
docker compose restart

# View UniFi logs
docker compose logs -f unifi-controller

# View FTP logs
docker compose logs -f vsftpd

# Backup .env file (IMPORTANT!)
cp .env .env.backup
```

## Security Notes

⚠️ **CRITICAL**: Save the `.env` file credentials immediately after setup!
- Contains MongoDB root password
- Contains MongoDB user password
- Contains FTP password
- If lost, you must redeploy

🔒 **Production Recommendations**:
1. Replace self-signed SSL certificates
2. Configure firewall (UFW/iptables)
3. Only expose required ports
4. Regular Docker image updates
5. Monitor disk space for backups

## Troubleshooting

**Services won't start?**
```bash
docker compose logs
# Check for port conflicts or permission issues
```

**Can't access UniFi?**
```bash
# Verify container is healthy
docker compose ps unifi-controller

# Check if port is listening
ss -tuln | grep 8443
```

**FTP connection fails?**
```bash
# Verify vsftpd is running
docker compose ps vsftpd

# Check passive ports are open
ss -tuln | grep 5000
```

## Next Steps

1. Complete UniFi initial setup wizard
2. Adopt your UniFi devices
3. Configure backup schedule
4. Test FTP backup retrieval
5. Set up monitoring/alerts

---

**Support**: Check `README.md` for detailed documentation.
