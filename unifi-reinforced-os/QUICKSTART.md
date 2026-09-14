# UniFi Network OS - Quick Start Guide

## 🚀 60-Second Deployment

```bash
cd /workspace/unifi-reinforced-os
sudo ./scripts/setup.sh
```

That's it! The script handles everything automatically.

---

## 📋 What Gets Deployed

| Component | Purpose | Port(s) |
|-----------|---------|---------|
| **Nginx Proxy** | Frontend reverse proxy with HTTP/2, SSL, Gzip | 80, 443, 8443, 8080 |
| **UniFi Controller** | Network management backend (JVM optimized) | Internal |
| **MongoDB** | Database with WiredTiger optimization | Internal (27017) |
| **vsftpd** | FTP storage with rate limiting (50KB/s) | 21, 30000-30010 |
| **RL Orchestrator** | Q-Learning agent for auto-optimization | Internal |

---

## 🔑 Access Information

After setup completes, you'll see:

```
===============================================================================
IMPORTANT: Save these credentials securely!
===============================================================================
MONGO_ROOT_USER: root_unifi_xxxx
MONGO_ROOT_PASS: <32-char-random-password>
MONGO_USER: unifi_app_xxxx
MONGO_PASS: <32-char-random-password>
FTP_USER: unifi_storage
FTP_PASS: <24-char-random-password>
===============================================================================
```

### Web Interfaces

- **UniFi Controller**: `https://<your-server-ip>:8443`
  - Complete the setup wizard on first login
  - Adopt your UniFi devices

- **FTP Storage**: `ftp://<your-server-ip>:21`
  - Username: `unifi_storage`
  - Password: (from .env file)

---

## 📊 Auto-Dynamic Features

### Resource Allocation (Automatic)

The setup script detects your hardware and allocates:

```
Detected: 4 CPUs, 8GB RAM, 50GB disk

→ UniFi Controller:  2.0 CPU, 4096MB RAM (50% of total)
→ MongoDB:           1.5 CPU, 1024MB RAM (25% cache)
→ Nginx:             0.5 CPU, 256MB RAM
→ vsftpd:            0.5 CPU, 256MB RAM
→ RL Orchestrator:   0.5 CPU, 512MB RAM
```

### Network Optimization (Automatic)

```bash
✅ TCP BBR congestion control enabled
✅ HTTP/2 multiplexing active
✅ Gzip compression (level 6)
✅ Connection pooling (32 keepalive)
✅ Rate limiting: 10 req/s (burst 20)
```

### Reinforcement Learning (Continuous)

The RL agent monitors every 30 seconds:
- CPU usage → State: `normal`/`high_cpu`
- Memory usage → State: `normal`/`high_memory`
- Takes actions: `scale_up`, `scale_down`, `optimize_network`, `optimize_db`
- Learns optimal configuration through rewards

---

## 🛠️ Common Commands

### View Status
```bash
docker compose ps
docker stats
```

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f unifi-backend
docker compose logs -f unifi-orchestrator
```

### Restart Services
```bash
docker compose restart
```

### Stop Everything
```bash
docker compose down
```

### Update Images
```bash
docker compose pull
docker compose up -d --force-recreate
```

---

## 📁 Directory Structure

```
/workspace/unifi-reinforced-os/
├── docker-compose.yml       # Service definitions
├── .env                     # Auto-generated credentials
├── README.md                # Full documentation
├── QUICKSTART.md            # This file
├── scripts/
│   └── setup.sh            # Main deployment script
├── configs/
│   ├── nginx/nginx.conf    # Reverse proxy config
│   ├── nginx/ssl/          # SSL certificates
│   ├── mongo/mongod.conf   # Database config
│   └── vsftpd/vsftpd.conf  # FTP config
├── data/
│   ├── unifi/              # UniFi application data
│   ├── mongo/              # MongoDB database files
│   ├── shared-storage/     # Shared with FTP
│   └── backups/            # Backup archives
├── logs/
│   ├── nginx/              # Web server logs
│   └── orchestrator/       # RL agent logs
└── orchestrator/
    ├── Dockerfile          # RL agent container
    └── rl_agent.py         # Q-Learning implementation
```

---

## 🔧 Customization

### Change Resource Limits

Edit `.env` before running setup:
```bash
UNIFI_MEM_LIMIT=4096      # Increase UniFi RAM
MONGO_CACHE_SIZE=1.0      # Increase MongoDB cache
FTP_RATE_LIMIT=102400     # Double FTP speed (100KB/s)
```

### Disable RL Agent

Comment out in `docker-compose.yml`:
```yaml
# unifi-orchestrator:
#   build: ...
```

### Use Different Network Ports

Edit `docker-compose.yml` ports section:
```yaml
ports:
  - "9443:8443"  # Change HTTPS port
```

---

## 🐛 Troubleshooting

### Setup Fails at Port Check
```bash
# Find what's using the port
sudo ss -tuln | grep :8443

# Stop conflicting service or change port in docker-compose.yml
```

### UniFi Won't Start
```bash
# Check logs
docker compose logs unifi-backend

# Verify Java is running
docker exec unifi-backend pgrep -x java

# Restart
docker compose restart unifi-backend
```

### Can't Access Web Interface
```bash
# Check firewall
sudo ufw status

# Allow ports
sudo ufw allow 8443/tcp
sudo ufw allow 8080/tcp
```

### RL Agent Errors
```bash
# Check Docker socket access
docker exec unifi-orchestrator ls -la /var/run/docker.sock

# Restart agent
docker compose restart unifi-orchestrator
```

---

## 📈 Monitoring

### Real-Time Metrics
```bash
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
```

### RL Agent Performance
```bash
# Watch Q-Learning decisions
docker logs unifi-orchestrator -f | grep "Action:"

# View learned Q-Table
docker exec unifi-orchestrator cat /app/logs/orchestrator.log | grep "Q-Table" | tail -1
```

### Database Performance
```bash
docker exec unifi-database mongosh --eval "db.serverStatus().metrics"
```

---

## 🔐 Security Best Practices

1. **Save Credentials**: Copy `.env` to secure location
2. **Firewall**: Only expose required ports
3. **SSL**: Replace self-signed cert with Let's Encrypt:
   ```bash
   sudo certbot certonly --standalone -d your-domain.com
   ```
4. **Regular Updates**: Run monthly:
   ```bash
   docker compose pull && docker compose up -d
   ```
5. **Backups**: Weekly automated backups to FTP storage

---

## 📞 Need Help?

- **UniFi Issues**: [Ubiquiti Community](https://community.ui.com)
- **Docker Issues**: `docker compose logs <service>`
- **RL Agent**: Check `/workspace/unifi-reinforced-os/logs/orchestrator/`

---

**Enjoy your self-optimizing UniFi Network OS!** 🎉
