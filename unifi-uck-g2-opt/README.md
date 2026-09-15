# UniFi Cloud Key Gen2 Enterprise Node

UniFi Network Controller + Secure vsftpd Server optimized for UCK-G2 (ARM64, 1GB RAM).

## Storage Capacity

| Volume | Mount Point | Limit | Purpose |
|--------|-------------|-------|---------|
| db-data | /data/db | 2GB | MongoDB database |
| unifi-config | /config | 3GB | UniFi configuration |
| shared-storage | /backups & /home/unifi_backup | Shared | Backup exchange |

## Resource Allocation

| Service | Memory | CPU | Storage |
|---------|--------|-----|---------|
| MongoDB | 300MB | 0.5 | 2GB |
| UniFi | 300MB | 1.0 | 3GB |
| vsftpd | 64MB | 0.25 | 500MB |

## Deployment

```bash
cd /workspace/unifi-uck-g2-opt
sudo ./scripts/setup.sh
```

## Access

- **UniFi**: https://<IP>:8443
- **FTP**: ftps://<IP>:21 (user: unifi_backup)

## Storage Management

```bash
./scripts/storage-info.sh
```
