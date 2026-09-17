# UniFi UCP - Enterprise Control Plane

Production-grade infrastructure orchestration software with modern GUI interface.

## Features

- **Real-time Dashboard**: Monitor system status, services, and live operations
- **One-Click Deployment**: Deploy all services with a single click
- **Migration Wizard**: Safely migrate legacy configurations with rollback support
- **Live Logging**: Color-coded operation logs with timestamps
- **Service Management**: Individual service control and restart capabilities
- **Secure Architecture**: Isolated Docker networking, atomic operations, encrypted secrets

## Quick Start

### Run the Compiled Binary

```bash
./unifi-ucp
```

Then open your browser to: **http://localhost:8080**

### Build from Source

```bash
# Ensure dependencies
go mod tidy

# Build for Linux AMD64
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o unifi-ucp ./cmd/server

# Run
./unifi-ucp
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/state` | GET | Get current system state |
| `/api/deploy` | POST | Deploy services (body: `{"target":"all"}`) |
| `/api/migrate` | POST | Start migration wizard |
| `/api/service/{name}/restart` | POST | Restart specific service |
| `/api/logs` | GET | Retrieve operation logs |

## Project Structure

```
/workspace
├── cmd/
│   └── server/
│       └── main.go          # Go backend with embedded web assets
├── web/
│   └── index.html           # React-style GUI dashboard
├── go.mod                   # Go module definition
├── go.sum                   # Dependency checksums
├── unifi-ucp                # Compiled binary (4.9MB)
└── README.md                # This file
```

## Technology Stack

- **Backend**: Go 1.21+ with gorilla/mux router and CORS middleware
- **Frontend**: HTML5 + Tailwind CSS + Lucide Icons
- **Embedding**: Go embed.FS for single-binary distribution
- **Communication**: RESTful JSON API over HTTP
- **Target**: Single static binary, no external runtime dependencies

## Production Features

- ✅ Thread-safe state management with mutex locks
- ✅ Background task execution with async workflows
- ✅ Real-time polling (5-second intervals)
- ✅ Structured JSON logging for SIEM integration
- ✅ Dynamic service monitoring and health checks
- ✅ Responsive dark-mode UI optimized for 24/7 monitoring
- ✅ Embedded static assets (no external file dependencies at runtime)

## License

Proprietary Enterprise Software

---

**Version**: 5.0.0  
**Build**: Production Release  
**Binary Size**: 4.9 MB (stripped, optimized)
