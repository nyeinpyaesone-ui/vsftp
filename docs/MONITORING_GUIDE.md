# Monitoring and Observability Guide

## Health Check Endpoints

### Server Health
- **Endpoint**: `/health`
- **Method**: GET
- **Response**: `{"status":"healthy","timestamp":"..."}`
- **Expected Status**: 200 OK

### Service Health Checks
All Docker services include health checks:
- **MongoDB**: Connection test via mongosh
- **UniFi Controller**: HTTPS on port 8443
- **FTP Server**: TCP connection on port 21

## Monitoring Recommendations

### 1. Container Monitoring
```bash
# Check container status
docker-compose ps

# View resource usage
docker stats

# Check logs
docker-compose logs -f [service_name]
```

### 2. Log Aggregation
Configure centralized logging:
- Use Docker logging drivers (syslog, journald, or fluentd)
- Set log rotation to prevent disk exhaustion
- Implement log retention policies

### 3. Metrics Collection
Recommended metrics to monitor:
- **CPU Usage**: Per container and total
- **Memory Usage**: Track against limits
- **Disk I/O**: Especially for MongoDB and FTP
- **Network Traffic**: Inbound/outbound per service
- **Application Metrics**: Request latency, error rates

### 4. Alerting Thresholds
| Metric | Warning | Critical |
|--------|---------|----------|
| CPU Usage | >70% | >90% |
| Memory Usage | >80% | >95% |
| Disk Usage | >75% | >90% |
| Error Rate | >1% | >5% |
| Response Time | >500ms | >2s |

### 5. Prometheus Integration (Optional)
Add to docker-compose.yml:
```yaml
prometheus:
  image: prom/prometheus
  ports:
    - "9090:9090"
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
```

### 6. Grafana Dashboards (Optional)
Visualize metrics with pre-built dashboards for:
- Docker container performance
- MongoDB performance
- Application response times

## Troubleshooting Common Issues

### Service Not Starting
1. Check logs: `docker-compose logs [service]`
2. Verify resource availability: `docker stats`
3. Check port conflicts: `netstat -tlnp`

### High Resource Usage
1. Identify offending container: `docker stats`
2. Check for memory leaks in logs
3. Consider scaling or resource limit adjustments

### Connectivity Issues
1. Verify network configuration: `docker network inspect`
2. Check firewall rules
3. Test internal connectivity: `docker exec [container] ping [service]`
