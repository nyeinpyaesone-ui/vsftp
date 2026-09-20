# Troubleshooting Guide

## Common Issues and Solutions

### 1. Build Failures

#### Go Build Error: pattern web/*: no matching files found
**Cause**: Embed path incorrect or web directory missing  
**Solution**: 
```bash
mkdir -p cmd/server/web
touch cmd/server/web/index.html cmd/server/web/app.js cmd/server/web/style.css
go build -o bin/server ./cmd/server/main.go
```

#### Docker Compose Syntax Error
**Cause**: Incorrect port range syntax  
**Solution**: Use hyphen not colon for ranges: `${MIN}-${MAX}`

### 2. Container Startup Issues

#### Container Exits Immediately
```bash
# Check logs
docker-compose logs [service_name]

# Common causes:
# - Missing environment variables
# - Port conflicts
# - Insufficient resources
# - Volume permission issues
```

#### Port Already in Use
```bash
# Find process using port
lsof -i :[port]
# or
netstat -tlnp | grep [port]

# Solution: Stop conflicting service or change port in .env
```

### 3. Database Connection Issues

#### MongoDB Connection Failed
```bash
# Check MongoDB container status
docker-compose ps mongodb

# View MongoDB logs
docker-compose logs mongodb

# Test connection from another container
docker exec -it [app_container] mongosh mongodb://mongo:27017
```

### 4. FTP Connection Issues

#### Cannot Connect to FTP Server
```bash
# Verify FTP service is running
docker-compose ps ftp-server

# Check passive port range is open
iptables -L -n | grep [FTP_PASSIVE_MIN]

# Test FTP connection
ftp localhost [FTP_PORT]
```

### 5. UniFi Controller Issues

#### Controller Not Accessible on Port 8443
```bash
# Check if container is healthy
docker-compose ps unifi-controller

# Wait for initialization (can take 2-5 minutes)
docker-compose logs -f unifi-controller

# Verify SSL certificate generation
docker exec unifi-controller ls -la /unifi/data/keystore
```

### 6. Resource Exhaustion

#### Out of Memory Errors
```bash
# Check resource usage
docker stats

# Increase limits in docker-compose.yml
# Or reduce allocated resources in setup.sh
```

#### Disk Space Full
```bash
# Check disk usage
df -h

# Clean up old Docker images
docker image prune -a

# Rotate logs
docker-compose logs --tail=100
```

### 7. Network Connectivity Issues

#### Containers Cannot Communicate
```bash
# Check network configuration
docker network inspect unifi-network

# Test connectivity between containers
docker exec container1 ping container2

# Restart network
docker-compose down
docker network prune
docker-compose up -d
```

### 8. Permission Issues

#### Volume Mount Permissions
```bash
# Fix ownership
docker exec [container] chown -R [user]:[group] /data

# Or set correct permissions on host
chmod 755 ./data/[service]
```

## Diagnostic Commands

```bash
# Overall system health
docker-compose ps
docker stats
df -h

# Service-specific diagnostics
docker-compose logs [service]
docker inspect [container_id]
docker exec [container] [diagnostic_command]

# Network diagnostics
docker network ls
docker network inspect [network_name]
```

## Getting Help

1. Check logs first: `docker-compose logs -f`
2. Verify configuration in `.env` file
3. Ensure minimum system requirements are met
4. Review Docker and application documentation
