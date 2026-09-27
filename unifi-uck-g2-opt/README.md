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

## FTPS configuration

The digest-pinned [delfer/alpine-ftp-server image](https://github.com/delfer/docker-alpine-ftp-server)
supports AMD64 and ARM64. Compose uses its `USERS` account format with UID/GID
1000, the existing shared storage directory, and `ADDRESS`/`MIN_PORT`/`MAX_PORT`
for passive connections. Passwords must not contain whitespace or `|` (the setup
script generates alphanumeric passwords). The config is mounted read-only at
`/etc/vsftpd/vsftpd.conf` and must be owned by root on the host (setup does this); edit it to change connection and transfer limits.

Setup creates `data/ftp-tls/vsftpd.crt` and `data/ftp-tls/vsftpd.key` if neither
exists. For manual Compose deployment, supply these files first. They are mounted
read-only, and the image's `TLS_CERT`/`TLS_KEY` settings require TLS for both login
and data on port 21. A missing or invalid certificate prevents FTP from listening.
Use **explicit FTP over TLS** in your client and trust the generated self-signed
certificate explicitly, or replace both files with a trusted certificate and key.
Renew before expiry (generated certificates last 365 days), then recreate the FTP
container. Keep the private key readable only by root.
