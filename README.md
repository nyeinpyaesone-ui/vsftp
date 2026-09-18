# 🌐 UniFi Network OS Docker Suite

[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![UniFi](https://img.shields.io/badge/UniFi-Network-0068C1?style=for-the-badge&logo=ubiquiti&logoColor=white)](https://ui.com)
[![MongoDB](https://img.shields.io/badge/MongoDB-47A248?style=for-the-badge&logo=mongodb&logoColor=white)](https://www.mongodb.com/)
[![FTP](https://img.shields.io/badge/FTP-vsftpd-FF6600?style=for-the-badge&logo=ftp&logoColor=white)](https://security.appspot.com/vsftpd.html)

> **Production-ready Docker deployments for UniFi Network Controller with integrated secure FTP backup servers**

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Quick Comparison](#-quick-comparison)
- [Live Architecture Diagrams](#-live-architecture-diagrams)
- [Deployments](#-deployments)
  - [1. UniFi Network OS](#1-unifi-network-os----universal-deployment)
  - [2. Enterprise File System](#2-enterprise-file-system----production-grade)
  - [3. UCK-G2 Optimized](#3-uck-g2-optimized----low-resource-devices)
  - [4. Auto Node](#4-auto-node----coming-soon)
- [Security Features](#-security-features)
- [Prerequisites](#-prerequisites)
- [Getting Started](#-getting-started)
- [Port Reference](#-port-reference)
- [Backup Strategy](#-backup-strategy)
- [Management Commands](#-management-commands)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

This repository provides **four distinct deployment options** for running UniFi Network Controller in Docker environments, each tailored for specific use cases and hardware configurations. All deployments include an integrated **vsftpd FTP server** for secure backup operations and file storage.

### Key Benefits

| Feature | Benefit |
|---------|---------|
| 🔐 **Secure by Default** | SSL/TLS encryption, strong passwords, network isolation |
| 🚀 **Auto-Configuration** | Hardware detection, dynamic resource allocation |
| 💾 **Integrated Backups** | Built-in FTP server for automated UniFi backups |
| 📊 **Production Ready** | Health checks, logging, resource limits |
| 🔄 **Multi-Architecture** | ARM64 (Cloud Key/Pi) & AMD64 (Server/PC) support |

---

## ⚡ Quick Comparison

### Resource Requirements Table

| Deployment Type | RAM Min | CPU Min | Storage | Best For |
|-----------------|---------|---------|---------|----------|
| **Network OS** | 2 GB | 2 Cores | 15 GB | General Use |
| **Enterprise FS** | 2 GB | 2 Cores | 15 GB | Production |
| **UCK-G2 Optimized** | 1 GB | 2 Cores | 5 GB | Cloud Key |
| **Auto Node** | TBA | TBA | TBA | Automation |

### Feature Comparison Matrix

| Feature | Network OS | Enterprise FS | UCK-G2 Opt |
|---------|:----------:|:-------------:|:----------:|
| Hardware Auto-Detection | ✅ | ✅ | ✅ |
| Network Isolation | ❌ | ✅ | ✅ |
| Health Checks | ❌ | ✅ | ❌ |
| Resource Limits | Dynamic | Advanced | Fixed |
| Flash Protection | ✅ | ❌ | ✅ (tmpfs) |
| Rate Limiting | Basic | Advanced | Basic |
| Logging Rotation | Standard | Professional | Minimal |
| SSL/TLS Encryption | ✅ | ✅ | ✅ |
| Multi-Architecture | ARM/AMD | AMD64 | ARM64 |

### Complexity vs Features

```
Complexity Level:     ★☆☆☆☆        ★★☆☆☆        ★★★☆☆        ★★★★☆
                     Simple       Moderate      Advanced    Expert
                         │            │            │            │
Deployments:    [Network OS]  [UCK-G2 Opt] [Enterprise] [Auto Node*]
                         │            │            │            │
Features:          Basic      Optimized      Full       Dynamic
                     │            │            │            │
Target:         Any Device   Cloud Key    Production   Automated
                                              Server       Env

*Coming Soon
```

---

## 🏗️ Live Architecture Diagrams

### Interactive System Flow (Mermaid)

```mermaid
flowchart TD
    subgraph Host["🖥️ Host System"]
        direction TB
        Internet((🌐 Internet))
        Firewall[🛡️ Firewall]
    end
    
    subgraph Frontend["📡 Frontend Network (Public)"]
        direction LR
        UniFi[⚙️ UniFi Controller<br/>Port: 8443/8080/3478]
        FTP[📁 vsftpd Server<br/>Port: 21/50000-50100]
    end
    
    subgraph Storage["💾 Shared Storage Volume"]
        BackupDir[📦 /data/shared-storage<br/>UniFi Backups *.unf]
    end
    
    subgraph Internal["🔒 Internal Network (Isolated)"]
        Mongo[🗄️ MongoDB Database<br/>Port: 27017<br/>No External Access]
    end
    
    Internet --> Firewall
    Firewall -->|HTTPS/UDP| UniFi
    Firewall -->|FTPS| FTP
    
    UniFi <-->|Read/Write| BackupDir
    FTP <-->|Upload/Download| BackupDir
    
    UniFi -->|Internal Network| Mongo
    
    classDef host fill:#e1f5fe,stroke:#01579b,stroke-width:2px;
    classDef frontend fill:#fff3e0,stroke:#e65100,stroke-width:2px;
    classDef storage fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px;
    classDef internal fill:#fce4ec,stroke:#880e4f,stroke-width:2px;
    
    class Host host
    class Frontend frontend
    class Storage storage
    class Internal internal
```

### Enterprise Deployment Architecture (ASCII)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FRONTEND NETWORK (Public)                        │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                                                                   │   │
│  │    ┌─────────────────┐              ┌─────────────────┐          │   │
│  │    │   UniFi         │◄────────────►│    vsftpd       │          │   │
│  │    │   Controller    │   Shared     │    FTP Server   │          │   │
│  │    │   Port: 8443    │   Storage    │    Port: 21     │          │   │
│  │    └────────┬────────┘              └────────▲────────┘          │   │
│  │             │                                │                    │   │
│  │             │        ┌───────────────────────┘                    │   │
│  │             │        │                                            │   │
│  ├─────────────┼────────┼────────────────────────────────────────────┤   │
│  │             ▼        ▼                                            │   │
│  │    ┌──────────────────────────────────────────────────────────┐   │   │
│  │    │              SHARED STORAGE VOLUME                        │   │   │
│  │    │            /data/shared-storage                           │   │   │
│  │    │   ┌─────────────────┐  ┌─────────────────┐               │   │   │
│  │    │   │ UniFi Backups   │◄─┤ FTP Access      │               │   │   │
│  │    │   │ *.unf files     │  │ Upload/Download │               │   │   │
│  │    │   └─────────────────┘  └─────────────────┘               │   │   │
│  │    └──────────────────────────────────────────────────────────┘   │   │
│  │                                                                   │   │
│  └───────────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────┤
│                       INTERNAL NETWORK (Isolated)                        │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │    ┌─────────────────┐                                           │   │
│  │    │   MongoDB       │◄────── No External Access ─────► BLOCKED │   │
│  │    │   Database      │                                           │   │
│  │    │   Port: 27017   │                                           │   │
│  │    └─────────────────┘                                           │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘

Legend:
  ► Data Flow         ── Network Boundary    ◄► Bidirectional Access
```

### Security Layers Visualization

```
┌─────────────────────────────────────────────────────────────────┐
│                    🛡️ SECURITY LAYERS                          │
├─────────────────────────────────────────────────────────────────┤
│  Layer 7: Application                                           │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  • SSL/TLS Encryption (FTPS)                              │  │
│  │  • Strong Password Generation (24-32 chars)               │  │
│  │  • Anonymous FTP Access Disabled                          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                          ▼                                      │
│  Layer 4: Network                                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  • Isolated Internal Network (MongoDB)                    │  │
│  │  • Separate Frontend Network (UniFi + FTP)                │  │
│  │  • Port Conflict Detection                                │  │
│  └───────────────────────────────────────────────────────────┘  │
│                          ▼                                      │
│  Layer 2: Container                                             │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  • CPU/Memory Resource Limits                             │  │
│  │  • PID Limits                                             │  │
│  │  • Storage Quotas                                         │  │
│  │  • Health Checks with Auto-Recovery                       │  │
│  └───────────────────────────────────────────────────────────┘  │
│                          ▼                                      │
│  Layer 1: Host                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  • Root Privilege Enforcement                             │  │
│  │  • Secure File Permissions (UID 1000)                     │  │
│  │  • Flash Storage Protection (tmpfs for logs)              │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Backup Workflow Animation

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐      ┌──────────────┐
│   UniFi     │      │   Shared     │      │    FTP      │      │   External   │
│  Controller │      │   Storage    │      │   Server    │      │   Client     │
└──────┬──────┘      └──────┬───────┘      └──────┬──────┘      └──────┬───────┘
       │                    │                      │                    │
       │  1. Create Backup  │                      │                    │
       │───────────────────>│                      │                    │
       │   (*.unf file)     │                      │                    │
       │                    │                      │                    │
       │                    │  2. Store File       │                    │
       │                    │<─────────────────────│                    │
       │                    │   (Write to disk)    │                    │
       │                    │                      │                    │
       │                    │  3. Notify Ready     │                    │
       │<───────────────────│                      │                    │
       │                    │                      │                    │
       │                    │                      │  4. FTP Connect    │
       │                    │                      │<───────────────────│
       │                    │                      │   (FTPS Session)   │
       │                    │                      │                    │
       │                    │  5. Download Backup  │                    │
       │                    │─────────────────────>│                    │
       │                    │   (*.unf via SSL)    │                    │
       │                    │                      │                    │
       │                    │                      │  6. Transfer       │
       │                    │                      │───────────────────>│
       │                    │                      │   Complete ✓       │
       │                    │                      │                    │

Time:  ───────────────────────────────────────────────────────────────────>
```

---

## 🚀 Deployments

### 1. UniFi Network OS – 🌍 Universal Deployment

**Best for**: General purpose deployment on any hardware (Raspberry Pi, Cloud Key, Server, PC)

<details>
<summary><b>📋 Click to expand features</b></summary>

#### Features
- ✅ Hardware auto-detection (ARM64 & AMD64)
- ✅ Dynamic resource allocation based on RAM/CPU
- ✅ Secure credential generation (24-32 char passwords)
- ✅ Flash storage protection for SD/eMMC devices
- ✅ Single-file deployment script

#### Quick Start
```bash
cd unifi-network-os
sudo ./setup.sh
```

#### Access After Setup
- **UniFi Controller**: `https://<SERVER_IP>:8443`
- **FTP Server**: `ftps://<SERVER_IP>:21`
- **FTP User**: `unifi_backup`
- **FTP Password**: Displayed after setup

</details>

---

### 2. Enterprise File System – 🏢 Production Grade

**Best for**: Production environments with advanced security and performance requirements

<details>
<summary><b>📋 Click to expand features</b></summary>

#### Features
- ✅ **Network Isolation**: Separate internal network for database
- ✅ **Port Conflict Detection**: Validates ports before deployment
- ✅ **Health Monitoring**: Automated service health checks with auto-recovery
- ✅ **SSL/TLS Encryption**: FTPS (FTP over SSL) for secure transfers
- ✅ **Resource Optimization**: MongoDB WiredTiger cache tuning + JVM optimization
- ✅ **Connection Rate Limiting**: 100KB/s, 20 max clients, 5 per IP
- ✅ **Professional Logging**: JSON log drivers with rotation

#### Architecture Highlights
```
Frontend Network: 172.29.0.0/24
  ├── UniFi Controller (Ports: 8443, 8080, 3478, 10001)
  └── vsftpd Server (Ports: 21, 30000-30010)

Internal Network: 172.28.0.0/24 (Isolated)
  └── MongoDB Database (Port: 27017) - No external access
```

#### Quick Start
```bash
cd unifi-enterprise-fs
sudo ./scripts/setup.sh
```

#### What Happens During Setup
1. ✅ Root privilege verification
2. ✅ Docker daemon validation
3. ✅ Hardware analysis (RAM, CPU, disk)
4. ✅ Network scan & port conflict detection
5. ✅ Secure credential generation
6. ✅ Environment configuration (.env)
7. ✅ Directory setup with proper permissions
8. ✅ Service deployment & health verification

#### Access After Setup
- **UniFi Controller**: `https://<SERVER_IP>:8443`
- **FTP Server**: `ftps://<SERVER_IP>:21`
- **FTP Username**: `unifi_backup`
- **Database**: Internal only (credentials saved in `.env`)

📖 **Full Documentation**: [unifi-enterprise-fs/README.md](unifi-enterprise-fs/README.md)

</details>

---

### 3. UCK-G2 Optimized – 📱 Low Resource Devices

**Best for**: UniFi Cloud Key Gen2, Raspberry Pi, and similar constrained devices (1GB RAM, ARM64)

<details>
<summary><b>📋 Click to expand features</b></summary>

#### Resource Allocation

| Service | Memory | CPU | Storage Limit |
|---------|--------|-----|---------------|
| MongoDB | 300MB | 0.5 | 2GB |
| UniFi Controller | 300MB | 1.0 | 3GB |
| vsftpd | 64MB | 0.25 | 500MB |

#### Features
- ✅ ARM64 optimized images (`platform: linux/arm64`)
- ✅ Conservative memory limits (256M JVM heap)
- ✅ Storage quota enforcement via `storage_opt`
- ✅ Serial GC for low-memory Java (`-XX:+UseSerialGC`)
- ✅ Minimal footprint design with tmpfs for logs
- ✅ PIDs limit enforcement (512-1024 max)
- ✅ ulimits configuration (nofile: 1024)

#### Quick Start
```bash
cd unifi-uck-g2-opt
sudo ./scripts/setup.sh
```

#### Storage Management
```bash
# Check storage usage per volume
./scripts/storage-info.sh
```

#### Access
- **UniFi**: `https://<IP>:8443`
- **FTP**: `ftps://<IP>:21` (user: `unifi_backup`)
- **Ports**: 8443, 8080, 8448, 3478/udp, 10001/udp, 1900/udp

📖 **Full Documentation**: [unifi-uck-g2-opt/README.md](unifi-uck-g2-opt/README.md)

</details>

---

### 4. Auto Node – 🤖 Coming Soon

**Best for**: Automated dynamic configuration and intelligent resource management

> ⏳ **Status**: Under development  
> Expected features: Auto-discovery, dynamic scaling, configuration templates

---

## 🔐 Security Features

All deployments implement enterprise-grade security measures:

```
┌─────────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS                          │
├─────────────────────────────────────────────────────────────┤
│  🔒 Authentication                                          │
│     • Strong password generation (24-32 characters)         │
│     • No anonymous FTP access                               │
│     • Database authentication required                      │
├─────────────────────────────────────────────────────────────┤
│  🔐 Encryption                                              │
│     • FTPS (FTP over SSL/TLS)                               │
│     • SSL certificate generation                            │
│     • Encrypted data in transit                             │
├─────────────────────────────────────────────────────────────┤
│  🛡️ Network Isolation                                       │
│     • Internal database network (Enterprise)                │
│     • No direct database exposure                           │
│     • Firewall-friendly port configuration                  │
├─────────────────────────────────────────────────────────────┤
│  📦 Resource Protection                                     │
│     • CPU/memory limits per container                       │
│     • Disk quota enforcement                                │
│     • Log rotation to prevent disk exhaustion               │
├─────────────────────────────────────────────────────────────┤
│  👤 Permission Management                                   │
│     • Non-root container users (UID 1000)                   │
│     • Restricted file permissions (600/700)                 │
│     • Secure environment file protection                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **CPU** | 2 Cores | 4+ Cores |
| **RAM** | 2 GB | 4+ GB |
| **Storage** | 15 GB | 30+ GB SSD |
| **OS** | Linux (any distro) | Ubuntu 22.04 LTS |

### Software Dependencies

```bash
# Docker Engine 20.10+
docker --version

# Docker Compose Plugin v2.0+
docker compose version
```

### Installation (if needed)

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Docker Compose Plugin
sudo apt-get install docker-compose-plugin
```

---

## 🎯 Getting Started

### Step-by-Step Guide

#### 1️⃣ Choose Your Deployment

```
Have a Cloud Key Gen2 or Raspberry Pi?
  └─► Use "UCK-G2 Optimized"

Running on a server for production?
  └─► Use "Enterprise File System"

Just want something simple that works?
  └─► Use "UniFi Network OS"
```

#### 2️⃣ Run the Setup Script

```bash
# Example: Enterprise deployment
cd unifi-enterprise-fs
sudo ./scripts/setup.sh
```

#### 3️⃣ Save Your Credentials

**⚠️ IMPORTANT**: The setup script will display credentials. **Save them immediately!**

```
