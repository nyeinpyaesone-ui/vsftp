# UniFi Network OS - Plug & Play Setup

## 🚀 Quick Start

```bash
cd /workspace/unifi-pnp-os
sudo ./scripts/setup.sh
```

That's it! The script automatically:
- ✅ Detects your server IP address
- ✅ Analyzes hardware (RAM/CPU/Disk) and tunes resources
- ✅ Generates secure random passwords
- ✅ Checks for port conflicts
- ✅ Deploys MongoDB, UniFi Controller, and vsftpd
- ✅ Configures shared storage for backups

## 📊 Architecture

```
┌─────────────────────────────────────────────────────┐
│                 Docker Host                         │
│                                                     │
│  ┌─────────────┐    ┌─────────────────────────┐    │
│  │   vsftpd    │    │      UniFi Controller   │    │
│  │  (FTP/S)    │◄──►│     (Frontend App)      │    │
│  │ Port: 21    │    │     Ports: 8443, 8080   │    │
│  └──────┬──────┘    └───────────┬─────────────┘    │
│         │                       │                   │
│         │    ┌──────────────────┘                   │
│         │    │                                      │
│  ┌──────▼──────▼──────┐    ┌────────────────────┐  │
│  │   Shared Volume    │    │     MongoDB        │  │
│  │  (Backup Storage)  │    │   (Database)       │  │
│  │ ./data/shared_ftp  │    │   Port: 27017      │  │
│  └────────────────────┘    └────────────────────┘  │
│                                                     │
│  Networks:                                          │
│  • unifi-frontend (Public)                          │
│  • unifi-internal (Private: DB ↔ App)               │
└─────────────────────────────────────────────────────┘
```

## 🔧 Auto-Detection Features

### Hardware Profiling
- **RAM**: Automatically allocates 25% to MongoDB, 33% to UniFi
- **CPU**: Sets limits based on available cores
- **Disk**: Validates minimum 10GB free space

### Network Detection
- Auto-discovers primary network interface IP
- Configures FTP passive mode with correct external IP
- Sets up isolated internal network for database security

### Security Enforcement
- Root privilege check required
- Port conflict detection (8443, 8080, 21, 27017)
- Secure random password generation (32-char for DB, 24-char for FTP)

## 📡 Access Information

After setup completes, you'll see:
- **UniFi Controller**: `https://<SERVER_IP>:8443`
- **FTP Server**: `ftps://<SERVER_IP>:21`
- **FTP Credentials**: Displayed in terminal (save these!)

## 📁 Directory Structure

```
unifi-pnp-os/
├── docker-compose.yml      # Service orchestration
├── scripts/
│   └── setup.sh           # Auto-dynamic installer
├── configs/
│   ├── vsftpd.conf        # FTP configuration
│   └── vsftpd.user_list   # FTP allowed users
└── data/
    ├── unifi/             # UniFi application data
    ├── db/                # MongoDB database files
    └── shared_ftp/        # Shared backup storage
```

## 🔒 Rate Limiting & Resources

| Service | CPU Limit | RAM Limit | I/O Rate |
|---------|-----------|-----------|----------|
| MongoDB | 2.0 cores | 2 GB | - |
| UniFi | 3.0 cores | 3 GB | - |
| vsftpd | 0.5 cores | 256 MB | 100 KB/s |

**FTP Connection Limits:**
- Max clients: 20
- Max per IP: 5
- Passive ports: 40000-40100

## 🛠️ Manual Operations

### View Logs
```bash
docker compose logs -f
```

### Restart Services
```bash
docker compose restart
```

### Backup Data
Files in `./data/shared_ftp/` are automatically accessible via FTP and contain UniFi backups.

### Update
```bash
docker compose pull
docker compose up -d
```

## ⚠️ Requirements

- **Docker**: Version 20.10+
- **Docker Compose**: Version 2.0+
- **RAM**: Minimum 2GB (4GB+ recommended)
- **Disk**: Minimum 10GB free space
- **OS**: Linux with root/sudo access
