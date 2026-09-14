# UniFi Network OS - Quick Start Guide

## 30-Second Setup

```bash
cd /workspace/unifi-network-os
sudo ./scripts/setup.sh
```

That's it! The script handles everything automatically.

## What You Get

✅ **UniFi Network Controller** - Manage all your UniFi devices  
✅ **MongoDB Database** - Stores configuration and statistics  
✅ **vsftpd Server** - Backup storage with rate limiting  
✅ **Auto-Configuration** - No manual setup required  

## After Installation

### 1. Access UniFi Controller
Open your browser: `https://<your-server-ip>:8443`

You'll see the UniFi setup wizard. Follow these steps:
1. Click "Start New Setup"
2. Create your admin account
3. Configure network settings
4. Adopt your UniFi devices

### 2. Access FTP Backup Server
```bash
ftp <your-server-ip>
# Username: unifi
# Password: (shown during setup - SAVE IT!)
```

### 3. View Your Credentials
If you missed the credentials during setup:
```bash
cat /workspace/unifi-network-os/.env
```

## Common Commands

### Check Status
```bash
cd /workspace/unifi-network-os
docker compose ps
```

### View Logs
```bash
# Live logs for all services
docker compose logs -f

# Just UniFi controller
docker compose logs -f unifi-controller
```

### Create Backup
```bash
./scripts/backup.sh create
```

### List Backups
```bash
./scripts/backup.sh list
```

### Restore Backup
```bash
./scripts/backup.sh restore /path/to/backup.tar.gz
```

### Restart Services
```bash
docker compose restart
```

### Stop Everything
```bash
docker compose down
```

### Complete Reset (WARNING: Deletes all data)
```bash
docker compose down -v
sudo rm -rf config db-data storage logs .env
sudo ./scripts/setup.sh
```

## Troubleshooting

### Can't Access Web Interface?
1. Wait 2-3 minutes after setup (UniFi takes time to initialize)
2. Check if container is running: `docker compose ps`
3. View logs: `docker compose logs unifi-controller`

### Port Already in Use?
The setup script checks for conflicts. If you see an error:
```bash
# Find what's using the port
sudo ss -tuln | grep :8443

# Stop the conflicting service or change ports in docker-compose.yml
```

### Low Resources Warning?
The script checks for minimum requirements:
- 15GB free disk space
- 2GB RAM
- 2 CPU cores

If you have less, UniFi may run slowly or fail to start.

### FTP Connection Failed?
1. Ensure ports 21 and 30000-30010 are open in firewall
2. Check vsftpd logs: `docker compose logs vsftpd`
3. Verify credentials in `.env` file

## Hardware Sizing

| Devices | CPU | RAM | Storage |
|---------|-----|-----|---------|
| 1-50 | 2 cores | 4 GB | 20 GB |
| 50-200 | 4 cores | 8 GB | 50 GB |
| 200+ | 8 cores | 16 GB | 100 GB |

## Next Steps

1. ✅ Complete UniFi setup wizard at `https://<ip>:8443`
2. ✅ Adopt your UniFi access points/switches/gateways
3. ✅ Configure your wireless networks
4. ✅ Set up automated backups: `./scripts/backup.sh create`
5. ✅ Monitor system health: `docker stats`

## Need Help?

- Full documentation: `cat README.md`
- UniFi official docs: https://help.ui.com
- Check logs: `/workspace/unifi-network-os/logs/`

---

**Remember**: Save your passwords from the `.env` file in a secure location!
