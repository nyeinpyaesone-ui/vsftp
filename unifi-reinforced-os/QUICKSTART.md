# UniFi Network OS - Quick Start Guide

## 🚀 One-Command Deployment

```bash
cd /workspace/unifi-reinforced-os
sudo ./scripts/setup.sh
```

## 📋 What Gets Deployed

| Service | Container Name | Purpose | Resources |
|---------|---------------|---------|-----------|
| **Frontend** | `unifi-frontend` | Nginx reverse proxy (HTTP/2, SSL) | 0.5 CPU, 256MB RAM |
| **Backend** | `unifi-backend` | UniFi Network Controller | 2.0 CPU, 2GB RAM |
| **Database** | `unifi-database` | MongoDB with WiredTiger | 1.5 CPU, 1GB RAM |
| **Storage** | `unifi-storage` | vsftpd server (rate-limited) | 0.5 CPU, 256MB RAM |
| **Orchestrator** | `unifi-orchestrator` | Q-Learning RL agent | 0.5 CPU, 512MB RAM |

**Total**: 5.0 CPU cores, 3.75GB RAM

## 🔑 Access Information

After setup completes, save these credentials from the `.env` file:

```bash
cat /workspace/unifi-reinforced-os/.env | grep -E "PASS|USER"
```

### Web Interfaces

| Service | URL | Notes |
|---------|-----|-------|
| UniFi Controller | `https://<server-ip>:8443` | Main management UI |
| Device Gateway | `http://<server-ip>:8080` | Device communication |
| FTP Storage | `ftp://<server-ip>:21` | Backup access |

### Default Credentials

- **FTP User**: `unifi_storage`
- **FTP Password**: (shown in setup output, stored in `.env`)
- **MongoDB Root**: Auto-generated (see `.env`)
- **MongoDB App User**: Auto-generated (see `.env`)

## 📁 Directory Structure

```
/workspace/unifi-reinforced-os/
├── docker-compose.yml          # Service orchestration
├── scripts/
│   ├── setup.sh               # Auto-dynamic deployment
│   └── backup.sh              # Automated backups
├── configs/
│   ├── nginx/nginx.conf       # HTTP/2, SSL, Gzip
│   ├── mongo/mongod.conf      # WiredTiger optimization
│   └── vsftpd/vsftpd.conf     # Rate limiting config
├── orchestrator/
│   ├── Dockerfile             # RL agent container
│   └── rl_agent.py            # Q-Learning implementation
├── data/
│   ├── unifi/                 # UniFi configuration
│   ├── mongo/                 # Database files
│   ├── shared-storage/        # FTP accessible backups
│   └── backups/               # Local backup archives
└── logs/                      # Service logs
```

## 🔧 Common Operations

### View Logs
```bash
docker compose logs -f unifi-backend      # UniFi Controller
docker compose logs -f unifi-database     # MongoDB
docker compose logs -f unifi-orchestrator # RL Agent
```

### Monitor Resources
```bash
docker stats unifi-backend unifi-database
```

### Create Manual Backup
```bash
./scripts/backup.sh
```

### Restart Services
```bash
docker compose restart
```

### Stop All Services
```bash
docker compose down
```

### Complete Reset
```bash
docker compose down -v
rm -rf data/* .env
sudo ./scripts/setup.sh
```

## 🎯 Reinforcement Learning Features

The RL Orchestrator automatically:
- Monitors CPU/Memory usage every 30 seconds
- Learns optimal resource allocation via Q-Learning
- Adjusts configurations based on reward signals
- Logs decisions to `/workspace/unifi-reinforced-os/logs/orchestrator/`

### View RL Decisions
```bash
docker exec unifi-orchestrator tail -f /app/logs/orchestrator.log
```

## ⚙️ Configuration Tuning

### Adjust Resource Limits
Edit `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'    # Change this
      memory: 4096M  # Change this
```

Then restart:
```bash
docker compose up -d --force-recreate
```

### Modify FTP Rate Limit
Edit `.env`:
```bash
FTP_RATE_LIMIT=102400  # 100 KB/s
```

Restart FTP service:
```bash
docker compose restart unifi-storage
```

## 🐛 Troubleshooting

### Check Service Status
```bash
docker compose ps
```

### Port Conflicts
```bash
sudo ss -tuln | grep -E ':(80|443|8443|8080|21|27017)'
```

### Insufficient Resources
```bash
free -h    # Check RAM
df -h      # Check disk
nproc      # Check CPU cores
```

### View All Logs
```bash
docker compose logs --tail=100
```

## 📊 Hardware Requirements

| Minimum | Recommended | Enterprise |
|---------|-------------|------------|
| 2 CPU cores | 4 CPU cores | 8+ CPU cores |
| 2GB RAM | 4-8GB RAM | 16GB+ RAM |
| 20GB SSD | 50GB SSD | 100GB+ NVMe |
| < 50 devices | 50-200 devices | 200+ devices |

## 🔒 Security Notes

1. **Save Credentials**: The `.env` file contains auto-generated passwords
2. **Firewall**: Only expose ports 80, 443, 8443, 8080, 21
3. **SSL Certificates**: Replace self-signed certs for production
4. **Permissions**: Data directories are set to 700 (owner only)

## 📞 Support

- **UniFi Issues**: [community.ui.com](https://community.ui.com)
- **Docker Issues**: Check `docker compose logs`
- **RL Agent**: View orchestrator logs

---

**Next Steps**: After accessing `https://<server-ip>:8443`, complete the UniFi setup wizard to configure your network.
