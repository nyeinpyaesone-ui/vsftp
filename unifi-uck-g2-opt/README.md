# UniFi Cloud Key Gen2 Enterprise Node

## Architecture
- MongoDB 7.0 (ARM64, 256MB cache)
- UniFi Network Controller (ARM64, 256MB heap)
- vsftpd Server (ARM64, 64MB limit)

## Requirements
- UCK-G2 Hardware (1GB RAM, ARM64)
- Docker Engine 24.0+
- Root access

## Deployment
```bash
cd /workspace/unifi-uck-g2-opt
sudo ./scripts/setup.sh
```

## Access
- UniFi: https://<IP>:8443
- FTP: ftps://<IP>:21 (user: unifi_backup)

## Storage
- Shared: ./data/shared-storage
