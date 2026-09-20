# UniFi Network OS - Quick Start Guide

## One-Command Deployment

```bash
cd /workspace/unifi-enterprise-fs
sudo ./scripts/setup.sh
```

## What You Get

✅ **Auto-Detected Configuration**
- Server IP automatically detected
- Hardware resources analyzed and optimized
- Secure passwords generated

✅ **Three Production Services**
1. **MongoDB 7.0** - Database backend (isolated network)
2. **UniFi Controller** - Network management frontend
3. **vsftpd** - Secure FTP backup server

✅ **Shared Storage Integration**
- UniFi backups → `/data/shared-storage/`
- FTP access → same directory via `ftps://`

## After Setup

### Access UniFi Controller
```
https://<YOUR_SERVER_IP>:8443
```
Complete the setup wizard in your browser.

### Access FTP Server
```
Host: <YOUR_SERVER_IP>
Port: 21 (FTPS)
Username: unifi_backup
Password: (shown in terminal output)
```

### Configure UniFi Backups
1. Go to **Settings** → **System** → **Backup**
2. Set backup location to `/storage/backups`
3. Enable automatic backups
4. Backups appear in shared storage for FTP download

## Save Your Credentials!

The setup script displays all passwords once. Store them securely:
- Database root password
- Database user password  
- FTP password

## Verify Services

```bash
# Check all containers are running
docker compose ps

# View logs if needed
docker compose logs -f
```

## Next Steps

1. Complete UniFi Controller setup wizard at `https://<IP>:8443`
2. Adopt your UniFi devices
3. Configure automatic backups to `/storage/backups`
4. Test FTP access with your preferred client
5. Set up firewall rules for production use

---

**Need Help?** See `README.md` for complete documentation.
