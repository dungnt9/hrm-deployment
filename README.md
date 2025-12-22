# HRM Deployment

Deployment repository cho hệ thống HRM (Human Resource Management) - chứa Docker Compose và cấu hình infrastructure.

## Quick Start

### Yêu cầu

- **Docker** version 24+
- **Docker Compose** version 2+

### Cấu trúc thư mục

Đảm bảo các repos nằm cùng cấp với `hrm-deployment`:

```
hrm/
├── hrm-deployment/           # (folder này)
├── hrm-employee-service/
├── hrm-Time-Service/
├── hrm-Notification-Service/
├── hrm-ApiGateway/
└── hrm-nextjs/
```

### Chạy dự án

```bash
cd hrm-deployment
docker compose up -d --build
```

### Reset toàn bộ (xóa data)

```bash
docker compose down -v
docker compose up -d --build
```

---

## Kiến trúc hệ thống

```
                                    ┌─────────────────┐
                                    │    Frontend     │
                                    │   (Next.js 14)  │
                                    │   Port: 3000    │
                                    └────────┬────────┘
                                             │
                                             ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            API Gateway (.NET 8)                              │
│                    REST API + GraphQL (HotChocolate)                         │
│                           Port: 5000                                         │
└──────────┬─────────────────────┬─────────────────────┬─────────────────────┘
           │ gRPC                │ gRPC                │ HTTP
           ▼                     ▼                     ▼
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────────┐
│ Employee Service │   │   Time Service   │   │ Notification Service │
│    (gRPC)        │   │     (gRPC)       │   │     (SignalR)        │
│  Port: 5001/5002 │   │  Port: 5003/5004 │   │    Port: 5005        │
└────────┬─────────┘   └────────┬─────────┘   └──────────┬───────────┘
         │                      │                        │
         ▼                      ▼                        ▼
┌──────────────┐        ┌─────────────────┐      ┌─────────────────┐
│  PostgreSQL  │        │   PostgreSQL    │      │   PostgreSQL    │
│ employee_db  │        │    time_db      │      │ notification_db │
└──────────────┘        └────────┬────────┘      └─────────────────┘
                                 │
                    ┌────────────┼────────────┐
                    ▼            ▼            ▼
              ┌─────────┐  ┌──────────┐  ┌──────────┐
              │  Redis  │  │ RabbitMQ │  │ Hangfire │
              │ (Cache) │  │ (Events) │  │  (Jobs)  │
              └─────────┘  └──────────┘  └──────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         Keycloak (Authentication)                            │
│                    OAuth 2.0 / OpenID Connect / RBAC                         │
│                              Port: 8080                                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Services & Ports

| Service | Port(s) | URL | Mô tả |
|---------|---------|-----|-------|
| Frontend | 3000 | http://localhost:3000 | Web UI (Next.js) |
| API Gateway | 5000 | http://localhost:5000 | REST + GraphQL |
| Swagger | 5000 | http://localhost:5000/swagger | API Docs |
| GraphQL | 5000 | http://localhost:5000/graphql | GraphQL Playground |
| Employee Service | 5001, 5002 | - | gRPC service |
| Time Service | 5003, 5004 | http://localhost:5003/hangfire | gRPC + Hangfire |
| Notification Service | 5005 | ws://localhost:5005/hubs/notification | SignalR Hub |
| Keycloak | 8080 | http://localhost:8080 | Identity Management |
| RabbitMQ | 5672, 15672 | http://localhost:15672 | Message Broker |
| MinIO | 9000, 9001 | http://localhost:9001 | Object Storage |
| PostgreSQL (x4) | 5432-5435 | - | Databases |
| Redis | 6379 | - | Cache |

---

## Tài khoản mặc định

### Keycloak Admin
| Field | Value |
|-------|-------|
| URL | http://localhost:8080 |
| Username | admin |
| Password | admin |

### Application Users
| Role | Username | Password |
|------|----------|----------|
| System Admin | admin | admin123 |
| HR Staff | hr_user | hr123 |
| Manager | manager_user | manager123 |
| Employee | employee_user | employee123 |

### Infrastructure
| Service | Username | Password |
|---------|----------|----------|
| RabbitMQ | hrm_user | hrm_pass |
| MinIO | minio_user | minio_pass |

---

## Chức năng chính

### Employee (Nhân viên)
- Check-in/Check-out với GPS location
- Xem lịch sử chấm công
- Tạo đơn xin nghỉ phép
- Xem số ngày phép còn lại
- Nhận thông báo real-time

### Manager (Quản lý)
- Xem danh sách nhân viên trong team
- Xem chấm công của team
- Duyệt đơn nghỉ phép (Level 1)

### HR Staff (Nhân sự)
- CRUD thông tin nhân viên
- Phân công phòng ban/team
- Duyệt đơn nghỉ phép (Level 2 - Final)
- Xem Organization Chart

### System Admin
- Quản lý roles và permissions
- Cấu hình Keycloak

---

## Công nghệ sử dụng

### Backend
- .NET 8, ASP.NET Core
- gRPC, HotChocolate (GraphQL)
- Entity Framework Core, PostgreSQL
- Redis, RabbitMQ, Hangfire
- Keycloak (OAuth 2.0/OIDC)

### Frontend
- Next.js 14 (App Router)
- TypeScript, Material UI
- Redux Toolkit, Apollo Client
- SignalR Client

### Infrastructure
- Docker, Docker Compose
- Keycloak 23, MinIO

---

## Các lệnh thường dùng

```bash
# Khởi động tất cả
docker compose up -d

# Xem trạng thái
docker compose ps

# Xem logs
docker compose logs -f

# Xem logs service cụ thể
docker compose logs -f api-gateway

# Dừng tất cả
docker compose down

# Dừng và xóa data (reset)
docker compose down -v

# Rebuild một service
docker compose build employee-service
docker compose up -d employee-service
```

---

## Troubleshooting

### Service không start được
```bash
# Kiểm tra logs
docker compose logs <service-name>

# Kiểm tra dependencies đã healthy chưa
docker compose ps
```

### Database connection failed
```bash
# Kiểm tra PostgreSQL
docker compose ps postgres-employee

# Xem logs
docker compose logs postgres-employee
```

### Keycloak chưa ready
Keycloak cần 60-90s để khởi động. Đợi đến khi status là `healthy`:
```bash
docker compose ps keycloak
```

### Reset toàn bộ
```bash
docker compose down -v
docker compose up -d
```

---

## Related Repositories

| Repository | Description |
|------------|-------------|
| [hrm-employee-service](https://github.com/YOUR_USERNAME/hrm-employee-service) | Employee management microservice |
| [hrm-time-service](https://github.com/YOUR_USERNAME/hrm-time-service) | Time & Attendance microservice |
| [hrm-notification-service](https://github.com/YOUR_USERNAME/hrm-notification-service) | Real-time notification service |
| [hrm-api-gateway](https://github.com/YOUR_USERNAME/hrm-api-gateway) | API Gateway (REST + GraphQL) |
| [hrm-frontend](https://github.com/YOUR_USERNAME/hrm-frontend) | Next.js frontend application |

---

## License

MIT License
