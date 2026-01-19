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
- At least **8GB RAM** available for Docker
- Ports available: 3000, 5000-5005, 5100, 5432-5436, 6379, 5672, 8080, 9000-9001, 15672

---

## Quick Start (Full Stack)

### ⚠️ IMPORTANT: First-Time Setup (Required)

**If you just cloned this project**, you MUST run these commands first to fix build issues:

```bash
# Navigate to project root
cd hrm

# 1. Fix API Gateway - Copy proto files to correct location
cd hrm-ApiGateway
mkdir -p Protos
cp src/API/Protos/employee.proto Protos/
cp src/API/Protos/time.proto Protos/

# 2. Go to deployment directory
cd ../hrm-deployment

# 3. Copy environment variables
cp .env.example .env

# 4. Now you can build and run
docker compose up -d --build
```

**Why these steps are needed:**
- API Gateway Dockerfile expects proto files in root `Protos/` folder
- These files are not committed to git to avoid duplication

### Option 1: Single Command Deployment (After Setup)

```bash
cd hrm-deployment

# Start EVERYTHING with one command (if you already did first-time setup above)
docker compose up -d --build

# Wait for all services (~5-10 minutes for first build due to NuGet restore)
docker compose ps

# Check all services are running
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
```

This starts:
- 5 PostgreSQL databases (employee, time, notification, keycloak, authz)
- Redis, RabbitMQ, MinIO
- Keycloak SSO
- Employee Service, Time Service, Notification Service
- API Gateway
- Socket Service (WebSocket)
- Frontend (Next.js)

### Option 2: Infrastructure First, Then Services

```bash
cd hrm-deployment

# 1. Start infrastructure only
docker compose -f docker-compose.infra.yml up -d

# 2. Wait for Keycloak to be healthy (~60-90 seconds)
docker compose -f docker-compose.infra.yml logs -f keycloak

# 3. Start application services (from each service directory)
cd ../hrm-employee-service && docker compose up -d --build
cd ../hrm-Time-Service && docker compose up -d --build
cd ../hrm-Notification-Service && docker compose up -d --build
cd ../hrm-ApiGateway && docker compose up -d --build
cd ../hrm-nextjs && docker compose up -d --build
```

### Step 2: Access the Application

| Service | URL |
|---------|-----|
| Frontend | http://localhost:3000 |
| API Gateway | http://localhost:5000 |
| Swagger | http://localhost:5000/swagger |
| GraphQL Playground | http://localhost:5000/graphql |
| Keycloak Admin | http://localhost:8080 |
| RabbitMQ Management | http://localhost:15672 |
| MinIO Console | http://localhost:9001 |
| Socket Service | http://localhost:5100 |

---

## Service Dependencies

```
Infrastructure (5x postgres, redis, rabbitmq, keycloak, minio)
       │
       ▼
Employee Service (5001 HTTP / 5002 gRPC)
       │
       ├──────────────────┐
       ▼                  ▼
Time Service       Notification Service
(5003 HTTP/5004 gRPC)     (5005 HTTP)
       │                  │
       └────────┬─────────┘
                ▼
          API Gateway (5000)
                │
       ┌────────┴────────┐
       ▼                 ▼
  Frontend (3000)   Socket Service (5100)
```

---

## Port Reference

### Infrastructure

| Service | Host Port | Container Port | Description |
|---------|-----------|----------------|-------------|
| PostgreSQL Employee | 5432 | 5432 | Employee database |
| PostgreSQL Time | 5433 | 5432 | Time database |
| PostgreSQL Notification | 5434 | 5432 | Notification database |
| PostgreSQL Keycloak | 5435 | 5432 | Keycloak database |
| PostgreSQL Authz | 5436 | 5432 | Authorization database |
| Redis | 6379 | 6379 | Cache & session store |
| RabbitMQ | 5672 | 5672 | Message queue |
| RabbitMQ UI | 15672 | 15672 | Management interface |
| Keycloak | 8080 | 8080 | Authentication |
| MinIO API | 9000 | 9000 | Object storage |
| MinIO Console | 9001 | 9001 | MinIO UI |

### Application Services

| Service | HTTP Port | gRPC Port | Container HTTP | Container gRPC |
|---------|-----------|-----------|----------------|----------------|
| Employee Service | 5001 | 5002 | 8080 | 8081 |
| Time Service | 5003 | 5004 | 8080 | 8081 |
| Notification Service | 5005 | - | 8080 | - |
| API Gateway | 5000 | - | 8080 | - |
| Socket Service | 5100 | - | 5001 | - |
| Frontend | 3000 | - | 3000 | - |

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

### Full Stack Management (docker-compose.yml)

```bash
cd hrm-deployment

# Start all services
docker compose up -d --build

# Stop all services
docker compose down

# View all container status
docker compose ps

# View logs for all services
docker compose logs -f

# View specific service logs
docker compose logs -f api-gateway
docker compose logs -f employee-service
docker compose logs -f keycloak

# Rebuild and restart a specific service
docker compose up -d --build employee-service

# Complete reset (DELETES ALL DATA)
docker compose down -v
docker compose up -d --build
```

### Infrastructure Only (docker-compose.infra.yml)

```bash
cd hrm-deployment

# Start infrastructure
docker compose -f docker-compose.infra.yml up -d

# Stop infrastructure
docker compose -f docker-compose.infra.yml down

# View status
docker compose -f docker-compose.infra.yml ps

# View logs
docker compose -f docker-compose.infra.yml logs -f
```

### View All Container Status

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

---

## Environment Variables

All configuration is centralized in `hrm-deployment/.env`. Key variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_PASSWORD` | PostgreSQL password | (per database) |
| `RABBITMQ_PASSWORD` | RabbitMQ password | hrm_pass |
| `KEYCLOAK_ADMIN_PASSWORD` | Keycloak admin password | admin |
| `API_GATEWAY_PORT` | API Gateway port | 5000 |
| `FRONTEND_PORT` | Frontend port | 3000 |
| `SOCKET_PORT` | Socket Service port | 5100 |

---

## Known Issues & Solutions

### Build Errors After Fresh Clone

**Issue:** `Could not make proto path relative : error : Protos/employee.proto: No such file or directory`

**Solution:** Run first-time setup (see Quick Start section above)

```bash
cd hrm-ApiGateway
mkdir -p Protos
cp src/API/Protos/*.proto Protos/
```

### Build Errors in Notification Service

**Issue:** `error CS0246: The type or namespace name 'IRequest<>' could not be found`

**Solution:** Already fixed in [NotificationService.csproj](../hrm-Notification-Service/NotificationService.csproj:10-11). MediatR packages are included.

### Build Errors in Time Service

**Issue:** `error CS0118: 'Attendance' is a namespace but is used like a type`

**Solution:** Already fixed in [CheckInCommandHandler.cs](../hrm-Time-Service/src/Application/Features/Attendance/Commands/CheckInCommandHandler.cs:4). Uses namespace alias.

---

## Troubleshooting

### Service won't start

```bash
# Check logs
docker compose logs employee-service

# Verify infrastructure is healthy
docker compose ps

# Check specific database
docker logs hrm-postgres-employee
```

### Database connection failed

```bash
# Check PostgreSQL for employee
docker logs hrm-postgres-employee

# Test connection
docker exec -it hrm-postgres-employee psql -U employee_user -d employee_db -c "\l"

# Check other databases
docker exec -it hrm-postgres-time psql -U time_user -d time_db -c "\l"
```

### Keycloak not ready

```bash
# View Keycloak logs
docker logs -f hrm-keycloak

# Check health
curl http://localhost:8080/health/ready
```

### Complete reset

```bash
cd hrm-deployment

# Stop and remove all containers + volumes
docker compose down -v

# Remove all HRM containers and images (optional)
docker rm $(docker ps -a -q --filter "name=hrm") 2>/dev/null
docker rmi $(docker images -q "hrm*") 2>/dev/null

# Start fresh
docker compose up -d --build
```

### Port already in use

```bash
# Find process using port (Windows)
netstat -ano | findstr :5000

# Kill process by PID
taskkill /PID <PID> /F

# Or stop conflicting container
docker stop <container_name>
```

### Container keeps restarting

```bash
# Check logs for errors
docker logs hrm-employee-service --tail 100

# Common causes:
# - Database not ready -> Wait for postgres to be healthy
# - Keycloak not ready -> Wait ~60-90 seconds after starting
# - gRPC connection failed -> Employee Service must start first
```

### Cannot connect to gRPC service

```bash
# Verify Employee Service gRPC is listening
docker logs hrm-employee-service | grep "gRPC"

# Check network connectivity
docker network ls | grep hrm

# Services should be on same network
docker network inspect hrm-deployment_hrm-network
```

### RabbitMQ connection issues

```bash
# Check RabbitMQ logs
docker logs hrm-rabbitmq

# Access management UI
# http://localhost:15672 (hrm_user / hrm_pass)

# Check queues
docker exec -it hrm-rabbitmq rabbitmqctl list_queues
```

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
