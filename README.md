# HRM Deployment

Deployment configuration and infrastructure setup for the **HRM (Human Resource Management)** system.

---

## Architecture Overview

```
hrm/
├── hrm-deployment/              # This repo - Infrastructure & Config
│   ├── docker-compose.yml       # Full stack deployment (recommended)
│   ├── docker-compose.infra.yml # Infrastructure only
│   ├── init-db.sql              # Database initialization
│   ├── .env                     # Environment variables
│   ├── .env.example             # Template for .env
│   ├── keycloak/
│   │   └── realm-export.json    # Keycloak realm config
│   ├── infrastructure/
│   │   ├── authz/               # Authorization schema
│   │   ├── keycloak/            # Keycloak themes & config
│   │   └── socket/              # WebSocket service (Node.js)
│   └── config/
│       └── generated/PRO/       # Production configs
│
├── hrm-employee-service/        # Employee management (.NET 8)
├── hrm-Time-Service/            # Attendance & time tracking (.NET 8)
├── hrm-Notification-Service/    # Real-time notifications (.NET 8)
├── hrm-ApiGateway/              # API Gateway (.NET 8)
└── hrm-nextjs/                  # Frontend (Next.js 14)
```

---

## Prerequisites

- **Docker Desktop** 4.x or later
- **Docker Compose** v2.x
- **For Local Development:** .NET 8.0 SDK (already installed on your machine)
- At least **8GB RAM** available for Docker
- Ports available: 3000, 5000-5005, 5100, 5432-5436, 6379, 5672, 8080, 9000-9001, 15672

---

## 🚀 First-Time Setup (After Cloning from GitHub)

### STEP 1: Load Docker Images (Offline - No Internet Needed)

After cloning the project, load all pre-packaged Docker images:

#### Windows (PowerShell):
```powershell
cd hrm-deployment
Get-ChildItem docker-images\*.tar | ForEach-Object { docker load -i $_.FullName }
```

#### Windows (CMD):
```cmd
cd hrm-deployment
for %f in (docker-images\*.tar) do docker load -i "%f"
```

#### Linux/Mac:
```bash
cd hrm-deployment
for file in docker-images/*.tar; do docker load -i "$file"; done
```

### STEP 2: Copy Environment Files

#### For Docker Stack Deployment:

```bash
cd hrm-deployment

# Copy socket service environment
cp env/socket.env.txt config/generated/PRO/socket-service/.env

# Copy docker-compose environment
cp env/docker-compose.env.txt .env
```

#### For Local .NET Development (dotnet run):

**Only needed if you plan to run .NET services locally without Docker:**

```bash
# Copy the .env.txt file and customize for local settings
cp env/docker-compose.env.txt .env.local

# Edit .env.local to point to local/Docker infrastructure:
# - POSTGRES_HOST=localhost (instead of container names)
# - REDIS_HOST=localhost
# - RABBITMQ_HOST=localhost
# - KEYCLOAK_HOST=localhost
# etc.
```

### STEP 3: Run Infrastructure Services

Start all infrastructure services (databases, Redis, RabbitMQ, Keycloak, MinIO, Socket Service) in Docker:

```bash
cd hrm-deployment
docker compose up -d --build
```

This will start:
- 5 PostgreSQL databases (employee, time, notification, keycloak, authz)
- Redis, RabbitMQ, MinIO
- Keycloak SSO
- Socket Service (WebSocket)

### STEP 4: Run .NET Services (Choose One Option)

#### Option A: Run in Docker (Full Stack)
```bash
# Keep docker compose running from STEP 3
# .NET services will start automatically as part of docker compose up -d --build
```

#### Option B: Run Locally with dotnet run (Development Friendly)

**If you prefer running .NET services locally on your machine:**

```bash
# Terminal 1 - Employee Service
cd hrm-employee-service
dotnet restore
dotnet run

# Terminal 2 - Time Service
cd hrm-Time-Service
dotnet restore
dotnet run

# Terminal 3 - Notification Service
cd hrm-Notification-Service
dotnet restore
dotnet run

# Terminal 4 - API Gateway
cd hrm-ApiGateway
dotnet restore
dotnet run

# Terminal 5 - Frontend
cd hrm-nextjs
npm install
npm run dev
```

**Note:** When running locally, make sure:
- All .NET services have access to infrastructure (databases, Redis, RabbitMQ, Keycloak)
- Ports 5001-5005, 5000, and 3000 are available on your machine
- Update `appsettings.Production.json` connection strings to point to `localhost` instead of Docker container names

---

## 📦 Docker Images Offline (IMPORTANT)

### Load images (chỉ cần làm 1 lần duy nhất)

Project này sử dụng Docker images offline (file `.tar` trong folder `docker-images/`) để deploy mà **KHÔNG cần pull từ internet**.

**Sau khi clone project**, load tất cả images vào Docker:

#### Windows (PowerShell):
```powershell
cd hrm-deployment
Get-ChildItem docker-images\*.tar | ForEach-Object { docker load -i $_.FullName }
```

#### Windows (CMD):
```cmd
cd hrm-deployment
for %f in (docker-images\*.tar) do docker load -i "%f"
```

#### Linux/Mac:
```bash
cd hrm-deployment
for file in docker-images/*.tar; do docker load -i "$file"; done
```

**Lưu ý:**
- ✅ **Chỉ cần load 1 lần duy nhất** khi clone project lần đầu
- ✅ Docker sẽ tự động dùng local images này khi chạy `docker compose up`
- ✅ **KHÔNG cần pull từ internet** nữa
- ❌ File `.tar` không commit vào Git (đã ignore) - cần tải riêng hoặc có sẵn

---

## Quick Start

### Architecture Overview

This project uses a **hybrid deployment model**:

- **Infrastructure & Services** → Docker Compose (Databases, Redis, RabbitMQ, Keycloak, MinIO, Socket)
- **.NET Services & Frontend** → Local Development (dotnet run, npm run dev)

```
┌─────────────────────────────────────────┐
│     Docker Compose Infrastructure       │
│  (postgres, redis, rabbitmq, keycloak)  │
└─────────────────────────────────────────┘
           ↑
      ┌────┴────┬────────────┬──────────┐
      ▼         ▼            ▼          ▼
  Employee    Time      Notification  API Gateway
   Service   Service     Service       (dotnet run)
  (dotnet)   (dotnet)    (dotnet)
      ↑         ↑            ↑          ↑
      └─────────┴────────────┴──────────┘
           Socket Service (Node.js)
           Frontend (Next.js)
```

### Quick Start Steps

**Step 1: Load Docker Images (One Time Only)**

```bash
cd hrm-deployment

# Windows (PowerShell)
Get-ChildItem docker-images\*.tar | ForEach-Object { docker load -i $_.FullName }

# Windows (CMD)
for %f in (docker-images\*.tar) do docker load -i "%f"

# Linux/Mac
for file in docker-images/*.tar; do docker load -i "$file"; done
```

**Step 2: Start Infrastructure Services**

```bash
cd hrm-deployment

# Copy environment file
cp env/docker-compose.env.txt .env
cp env/socket.env.txt config/generated/PRO/socket-service/.env

# Start infrastructure (Docker Compose)
docker compose up -d
```

Wait for all services to be healthy:
```bash
# Check status
docker compose ps

# Check logs
docker compose logs -f
```

**Step 3: Run .NET Services & Frontend (New Terminals)**

Open 5 separate terminals and run:

**Terminal 1: Employee Service**
```bash
cd hrm-employee-service
dotnet restore
dotnet run
# Runs on http://localhost:5001 (HTTP) and http://localhost:5002 (gRPC)
```

**Terminal 2: Time Service**
```bash
cd hrm-Time-Service
dotnet restore
dotnet run
# Runs on http://localhost:5003 (HTTP) and http://localhost:5004 (gRPC)
```

**Terminal 3: Notification Service**
```bash
cd hrm-Notification-Service
dotnet restore
dotnet run
# Runs on http://localhost:5005
```

**Terminal 4: API Gateway**
```bash
cd hrm-ApiGateway
dotnet restore
dotnet run
# Runs on http://localhost:5000
```

**Terminal 5: Frontend (Next.js)**
```bash
cd hrm-nextjs
npm install
npm run dev
# Runs on http://localhost:3000
```

**Step 4: Access the Application**

All services are now running and ready:

| Service | URL | Status |
|---------|-----|--------|
| Frontend | http://localhost:3000 | ✅ Ready |
| API Gateway | http://localhost:5000 | ✅ Ready |
| Keycloak Admin | http://localhost:8080 | ✅ Ready |
| Socket Service | http://localhost:5100 | ✅ Ready |
| RabbitMQ Management | http://localhost:15672 | ✅ Ready |
| MinIO Console | http://localhost:9001 | ✅ Ready |

---

---

## Service Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              Docker Compose (Infrastructure)                 │
│                                                               │
│  ┌──────────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐│
│  │  PostgreSQL  │  │  Redis   │  │RabbitMQ  │  │Keycloak  ││
│  │  (5x dbs)    │  │(6379)    │  │(5672)    │  │(8080)    ││
│  └──────────────┘  └──────────┘  └──────────┘  └──────────┘│
│                                                               │
│  ┌──────────────┐  ┌──────────────────────────────────────┐ │
│  │   MinIO      │  │  Socket Service (Node.js)            │ │
│  │(9000/9001)   │  │  docker run - 5100 → localhost:5100  │ │
│  └──────────────┘  └──────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
           ↑
    ┌──────┴──────┬──────────────┬──────────────┬─────────┐
    │             │              │              │         │
    ▼             ▼              ▼              ▼         ▼
[Local Dev Machines]

Employee Service     Time Service      Notification Service  API Gateway    Frontend
(dotnet run)         (dotnet run)      (dotnet run)         (dotnet run)    (npm run dev)
:5001 HTTP           :5003 HTTP        :5005                :5000           :3000
:5002 gRPC           :5004 gRPC
```

### Running Environment

- **Infrastructure Services** → Docker Containers (managed by docker-compose)
- **.NET Services** → Local processes (dotnet run)
- **Frontend** → Local process (npm run dev)
- **Socket Service** → Docker Container (Node.js)

---

## Port Reference

### Docker Infrastructure Services

| Service | Port | Type | Status |
|---------|------|------|--------|
| PostgreSQL Employee DB | 5432 | TCP | Docker |
| PostgreSQL Time DB | 5433 | TCP | Docker |
| PostgreSQL Notification DB | 5434 | TCP | Docker |
| PostgreSQL Keycloak DB | 5435 | TCP | Docker |
| PostgreSQL Authz DB | 5436 | TCP | Docker |
| Redis | 6379 | TCP | Docker |
| RabbitMQ Server | 5672 | TCP | Docker |
| RabbitMQ Management UI | 15672 | HTTP | Docker |
| Keycloak SSO | 8080 | HTTP | Docker |
| MinIO API | 9000 | HTTP | Docker |
| MinIO Console | 9001 | HTTP | Docker |
| Socket Service | 5100 | WebSocket | Docker (Node.js) |

### Local Development Services (dotnet run / npm run dev)

| Service | HTTP Port | gRPC Port | Process |
|---------|-----------|-----------|---------|
| Employee Service | 5001 | 5002 | dotnet run |
| Time Service | 5003 | 5004 | dotnet run |
| Notification Service | 5005 | - | dotnet run |
| API Gateway | 5000 | - | dotnet run |
| Frontend | 3000 | - | npm run dev |

**Note:** Each service runs as a separate process on your local machine, NOT in Docker containers.

---

## Default Credentials

### Keycloak Admin

| Field | Value |
|-------|-------|
| URL | http://localhost:8080 |
| Username | admin |
| Password | admin |

### Application Users

| Role | Username | Password |
|------|----------|----------|
| Admin | admin | admin123 |
| HR | hr_user | hr123 |
| Manager | manager_user | manager123 |
| Employee | employee_user | employee123 |

### Database Credentials

| Database | Username | Password | Database Name |
|----------|----------|----------|---------------|
| Employee DB | employee_user | employee_pass | employee_db |
| Time DB | time_user | time_pass | time_db |
| Notification DB | notification_user | notification_pass | notification_db |
| Keycloak DB | keycloak_user | keycloak_pass | keycloak_db |
| Authz DB | authz_user | authz_pass | authz_db |

### Infrastructure Services

| Service | Username | Password |
|---------|----------|----------|
| RabbitMQ | hrm_user | hrm_pass |
| MinIO | minio_user | minio_pass |

---

## Docker Compose Commands

### Infrastructure Management (docker-compose.yml)

```bash
cd hrm-deployment

# Start infrastructure services
docker compose up -d

# Stop infrastructure services
docker compose down

# View all container status
docker compose ps

# View logs for all services
docker compose logs -f

# View specific service logs
docker compose logs -f keycloak
docker compose logs -f rabbitmq
docker compose logs -f postgres-employee

# Restart a specific service
docker compose restart postgres-employee

# Complete reset (DELETES ALL DATABASE DATA)
docker compose down -v
docker compose up -d
```

### Local Development Commands

```bash
# Terminal 1: Start infrastructure
cd hrm-deployment
docker compose up -d

# Terminal 2: Employee Service
cd hrm-employee-service
dotnet run

# Terminal 3: Time Service
cd hrm-Time-Service
dotnet run

# Terminal 4: Notification Service
cd hrm-Notification-Service
dotnet run

# Terminal 5: API Gateway
cd hrm-ApiGateway
dotnet run

# Terminal 6: Frontend
cd hrm-nextjs
npm run dev
```

### View Container Status

```bash
# Show only Docker containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Show Docker infrastructure
cd hrm-deployment
docker compose ps
```

---

## Configuration Management

### Architecture

The HRM system uses **externalized configuration** mounted from `config/generated/PRO/` directory:

```
config/
└── generated/
    └── PRO/                                    # Production configuration folder
        ├── api-gateway/
        │   └── appsettings.Production.json    # API Gateway config
        ├── employee-service/
        │   └── appsettings.Production.json    # Employee Service config
        ├── time-service/
        │   └── appsettings.Production.json    # Time Service config
        ├── notification-service/
        │   └── appsettings.Production.json    # Notification Service config
        └── socket-service/
            └── .env                            # Socket Service environment
```

### How Configuration Works

1. **Docker Volumes Mount:** Configuration files are mounted as read-only volumes into containers:
   ```yaml
   volumes:
     - ./config/generated/PRO/employee-service/appsettings.Production.json:/app/appsettings.Production.json:ro
   ```

2. **No Environment Variables in docker-compose.yml:** All sensitive data (passwords, connection strings) is stored in the mounted config files, not in docker-compose.yml environment section

3. **Easy Management:** Update configuration files without rebuilding Docker images - just restart containers

### Modifying Configuration

To change service configuration:

1. Edit the respective `appsettings.Production.json` or `.env` file in `config/generated/PRO/`
2. Restart the service:
   ```bash
   docker compose restart <service-name>
   ```
3. No rebuild needed - configuration changes take effect immediately

### Socket Service Configuration

Socket Service uses an `.env` file instead of JSON:

**File:** `config/generated/PRO/socket-service/.env`

```env
SERVER_PORT=5001
AUTH_API=http://api-gateway:8080/api/auth/me
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USER=hrm_user
RABBITMQ_PASSWORD=hrm_pass
RABBITMQ_WORK_QUEUE_NAME=hrm_socket_work_queue
NODE_ENV=production
```

---

## Environment Variables

Global environment variables are in `hrm-deployment/.env` (copied from `env/docker-compose.env.txt`).

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_PASSWORD` | PostgreSQL password | (per database) |
| `RABBITMQ_PASSWORD` | RabbitMQ password | hrm_pass |
| `KEYCLOAK_ADMIN_PASSWORD` | Keycloak admin password | admin |
| `API_GATEWAY_PORT` | API Gateway port | 5000 |
| `FRONTEND_PORT` | Frontend port | 3000 |
| `SOCKET_PORT` | Socket Service port | 5100 |

---

## Common Setup Issues & Solutions

### NuGet Restore Fails

**Issue:** `dotnet restore` fails with "could not connect to package source"

**Solution:** Ensure your internet connection is active, or use offline package cache:

```bash
cd hrm-employee-service
dotnet restore --no-cache
```

### Ports Already in Use

**Issue:** `System.Net.Sockets.SocketException: Address already in use`

**Solution:** Find and kill process using the port:

```bash
# Windows
netstat -ano | findstr :5001
taskkill /PID <PID> /F

# Linux/Mac
lsof -i :5001
kill -9 <PID>
```

### Cannot Connect to Database

**Issue:** `Npgsql.NpgsqlException: Connection refused on 127.0.0.1:5432`

**Solution:** Ensure Docker infrastructure is running:

```bash
cd hrm-deployment
docker compose ps
# All postgres containers should show "healthy"
```

### Cannot Connect to RabbitMQ

**Issue:** `System.Net.Sockets.SocketException: Connection refused on localhost:5672`

**Solution:** Verify RabbitMQ is running:

```bash
docker compose logs -f rabbitmq
# Should show "Ready to accept connections"
```

### Keycloak Not Ready

**Issue:** Services fail with "Keycloak not ready" errors

**Solution:** Wait for Keycloak to fully start (can take 60-90 seconds):

```bash
docker compose logs -f keycloak
# Wait for "Listening on: http://0.0.0.0:8080"
```

---

## Troubleshooting

### .NET Service Won't Start

**Symptoms:** Service exits immediately or shows errors

**Diagnosis:**
```bash
# Check detailed error messages
cd hrm-employee-service
dotnet run --verbose

# Verify connection strings point to correct hosts
cat config/generated/PRO/employee-service/appsettings.Production.json
```

**Solutions:**
- Ensure all Docker infrastructure is running: `docker compose ps`
- Verify connection strings use correct hostnames (localhost for local, container names for Docker)
- Wait for Keycloak to be fully ready before starting services

### Database Connection Failed

**Error:** `Npgsql.NpgsqlException: unable to connect to server`

**Solution:**
```bash
# 1. Ensure PostgreSQL is running
docker compose ps postgres-employee

# 2. Test connection from host machine
# Use pgAdmin or psql tool to verify connectivity
# Connection: localhost:5432 (for employee_db)

# 3. Check PostgreSQL logs
docker compose logs postgres-employee
```

### Cannot Connect to RabbitMQ

**Error:** `System.Net.Sockets.SocketException: Connection refused`

**Solution:**
```bash
# 1. Ensure RabbitMQ is running
docker compose ps rabbitmq

# 2. Check RabbitMQ is accepting connections
docker compose logs rabbitmq | grep "accepting connections"

# 3. Access RabbitMQ Management UI
# URL: http://localhost:15672
# Username: hrm_user
# Password: hrm_pass
```

### Keycloak Not Ready

**Error:** Services fail trying to connect to Keycloak

**Solution:**
```bash
# 1. Check Keycloak startup logs
docker compose logs keycloak

# 2. Wait for Keycloak to be ready (can take 60-90 seconds)
docker compose logs -f keycloak | grep -i "ready\|listening"

# 3. Once ready, access Keycloak Admin
# URL: http://localhost:8080
# Username: admin
# Password: admin
```

### Socket Service Issues

**Error:** Frontend cannot connect to Socket Service

**Solution:**
```bash
# 1. Verify Socket Service is running in Docker
docker compose ps socket-service

# 2. Check Socket Service logs
docker compose logs socket-service

# 3. Verify configuration
cat config/generated/PRO/socket-service/.env

# 4. Test connection
curl http://localhost:5100
```

### Complete Reset (Nuclear Option)

**Use this if everything is broken and you want to start fresh:**

```bash
cd hrm-deployment

# 1. Stop all infrastructure
docker compose down -v

# 2. Kill all .NET service processes
# On Windows: Use Task Manager or taskkill
# On Linux/Mac: pkill -f "dotnet run"

# 3. Clear Node modules for frontend (optional)
cd ../hrm-nextjs
rm -rf node_modules package-lock.json

# 4. Reload Docker images (if needed)
for %f in (docker-images\*.tar) do docker load -i "%f"

# 5. Start fresh
cd ../hrm-deployment
docker compose up -d
```

---

## Local Development with .NET SDK

For faster development cycle, you can run .NET services locally using `dotnet run` while keeping infrastructure (databases, Redis, RabbitMQ, Keycloak) in Docker.

### Prerequisites for Local Development

- .NET 8.0 SDK installed on your machine
- All Docker infrastructure services running (from `docker compose up -d`)

### Running Services Locally

1. **Start Infrastructure in Docker:**
   ```bash
   cd hrm-deployment
   docker compose up -d
   ```

2. **Update Local Configuration:**

   Each .NET service reads from `appsettings.Production.json` in `config/generated/PRO/`

   For local development, you may want to modify connection strings to use `localhost`:

   ```json
   {
     "ConnectionStrings": {
       "DefaultConnection": "Host=localhost;Port=5432;Database=employee_db;Username=employee_user;Password=employee_pass"
     }
   }
   ```

3. **Run Each Service in Separate Terminal:**

   **Employee Service:**
   ```bash
   cd hrm-employee-service
   dotnet restore
   dotnet run
   # Runs on http://localhost:5001 (HTTP) and http://localhost:5002 (gRPC)
   ```

   **Time Service:**
   ```bash
   cd hrm-Time-Service
   dotnet restore
   dotnet run
   # Runs on http://localhost:5003 (HTTP) and http://localhost:5004 (gRPC)
   ```

   **Notification Service:**
   ```bash
   cd hrm-Notification-Service
   dotnet restore
   dotnet run
   # Runs on http://localhost:5005
   ```

   **API Gateway:**
   ```bash
   cd hrm-ApiGateway
   dotnet restore
   dotnet run
   # Runs on http://localhost:5000
   ```

   **Frontend (Node.js):**
   ```bash
   cd hrm-nextjs
   npm install
   npm run dev
   # Runs on http://localhost:3000
   ```

### Benefits of Local Development

✅ **Faster Iteration:** No need to rebuild Docker images
✅ **Better Debugging:** Use Visual Studio or VS Code debugger
✅ **Live Reloading:** Changes automatically reflected
✅ **Reduced Resource Usage:** Only infrastructure in Docker

---

## Socket Service (WebSocket)

The Socket Service provides real-time WebSocket communication. Built with Node.js and Socket.IO.

```
infrastructure/socket/
├── Dockerfile
├── index.js          # Main entry point
├── package.json
└── .env.example
```

### Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| SERVER_PORT | Socket server port | 5001 |
| AUTH_API | Auth verification endpoint | http://api-gateway:8080/api/auth/me |
| RABBITMQ_HOST | RabbitMQ host | rabbitmq |
| RABBITMQ_PORT | RabbitMQ port | 5672 |
| RABBITMQ_USER | RabbitMQ username | hrm_user |
| RABBITMQ_PASSWORD | RabbitMQ password | hrm_pass |
| RABBITMQ_WORK_QUEUE_NAME | Queue name | hrm_socket_work_queue |

---

## Production Deployment (AWS)

For production on AWS:

1. **Infrastructure** -> AWS Managed Services:
   - PostgreSQL -> RDS (5 databases or 5 RDS instances)
   - Redis -> ElastiCache
   - RabbitMQ -> Amazon MQ
   - MinIO -> S3

2. **Application Services** -> ECS Fargate or EKS

3. **Secrets** -> AWS Secrets Manager / Parameter Store

4. **Environment** -> ECS Task Definition environment variables

5. **Load Balancing** -> Application Load Balancer for API Gateway and Frontend

---

## License

MIT
