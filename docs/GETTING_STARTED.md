# Getting Started Guide

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM minimum (8GB recommended)
- 10GB free disk space
- Go 1.19+ (for building the server)

## Quick Start

### 1. Clone and Setup
```bash
git clone <repository-url>
cd unifi-enterprise-fs
```

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env with your settings
nano .env
```

### 3. Run Setup Script
```bash
chmod +x unifi-enterprise-fs/scripts/setup.sh
./unifi-enterprise-fs/scripts/setup.sh
```

### 4. Build the Server
```bash
go build -o bin/server ./cmd/server/main.go
```

### 5. Start Services
```bash
cd unifi-enterprise-fs
docker-compose up -d
```

### 6. Verify Installation
```bash
# Check all services are running
docker-compose ps

# View logs
docker-compose logs -f

# Test health endpoint
curl http://localhost:8080/health
```

## Accessing Services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| UniFi Controller | https://localhost:8443 | See .env file |
| FTP Server | ftp://localhost:21 | See .env file |
| MongoDB | localhost:27017 | Internal use |
| Management API | http://localhost:8080 | Bearer token |

## Common Commands

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f [service]

# Restart a service
docker-compose restart [service]

# Check resource usage
docker stats

# Backup data
./scripts/backup.sh
```

## Next Steps

1. **Configure UniFi Controller**: Visit https://localhost:8443
2. **Set up FTP Users**: Configure via UniFi interface
3. **Monitor Services**: Review monitoring guide
4. **Configure Backups**: Follow backup strategy
5. **Set up Alerts**: Configure monitoring thresholds

## Support

- Documentation: See `docs/` directory
- Troubleshooting: See `docs/TROUBLESHOOTING.md`
- Issues: Open a GitHub issue
- Community: Join our discussion forum
