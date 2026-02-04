# HRM - Human Resource Management System

Hệ thống quản lý nhân sự microservices, hỗ trợ quản lý nhân viên, chấm công, nghỉ phép, tăng ca và thông báo real-time.

---

## Mục lục

- [Kiến trúc tổng thể](#kiến-trúc-tổng-thể)
- [Tech Stack](#tech-stack)
- [Cấu trúc thư mục](#cấu-trúc-thư-mục)
- [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
- [Hướng dẫn cài đặt từ đầu](#hướng-dẫn-cài-đặt-từ-đầu)
- [Khởi động hệ thống](#khởi-động-hệ-thống)
- [Xác nhận hệ thống hoạt động](#xác-nhận-hệ-thống-hoạt-động)
- [Port Reference](#port-reference)
- [Thông tin đăng nhập](#thông-tin-đăng-nhập)
- [Chi tiết từng Service](#chi-tiết-từng-service)
  - [Frontend (Next.js)](#frontend-nextjs)
  - [API Gateway](#api-gateway)
  - [Employee Service](#employee-service)
  - [Time Service](#time-service)
  - [Notification Service](#notification-service)
  - [Socket Service](#socket-service)
  - [Keycloak (SSO)](#keycloak-sso)
  - [Authorization Service](#authorization-service)
- [Cấu hình môi trường](#cấu-hình-môi-trường)
- [Docker Compose Commands](#docker-compose-commands)
- [Production Deployment](#production-deployment)
- [Lưu ý quan trọng](#lưu-ý-quan-trọng)
- [Xử lý sự cố](#xử-lý-sự-cố)
- [Dừng hệ thống](#dừng-hệ-thống)

---

## Kiến trúc tổng thể

### Deployment Model: Hybrid

- **Infrastructure** (PostgreSQL, Redis, RabbitMQ, Keycloak, MinIO, Socket Service) chạy trong **Docker Compose**
- **Backend .NET services** (Employee, Time, Notification, API Gateway) chạy local với **`dotnet run`**
- **Frontend** (Next.js) chạy local với **`npm run dev`**

### System Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              FRONTEND (Next.js)                              │
│                               http://localhost:3000                          │
└───────────────────────────────────┬──────────────────────────────────────────┘
                                    │ REST / GraphQL / WebSocket
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                            API GATEWAY (.NET 8)                              │
│                            http://localhost:5000                             │
│  Controllers (REST)  │  GraphQL (HotChocolate)  │  Swagger  │  SignalR Hub  │
│                      │                          │ /swagger  │               │
│                      └──────── Keycloak JWT Validator ───────┘              │
└──────────────────────────┬───────────────┬────────────────┬──────────────────┘
                           │               │                │
                     gRPC  │         gRPC  │          HTTP  │
                           ▼               ▼                ▼
                ┌─────────────────┐ ┌─────────────────┐ ┌──────────────────┐
                │Employee Service │ │  Time Service   │ │Notification Svc  │
                │  :5001 / :5002  │ │  :5003 / :5004  │ │     :5005        │
                └────────┬────────┘ └────────┬────────┘ └────────┬─────────┘
                         │                   │                   │
                         ▼                   ▼                   ▼
                ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
                │postgres-employee│ │  postgres-time  │ │postgres-notif   │
                │    :5432        │ │    :5433        │ │    :5434        │
                └─────────────────┘ └─────────────────┘ └─────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                     Docker Compose Infrastructure                            │
│  Redis :6379 │ RabbitMQ :5672/:15672 │ Keycloak :8080 │ MinIO :9000/:9001  │
│  postgres-keycloak :5435 │ postgres-authz :5436 │ Socket Service :5100     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Communication Flow

| From | To | Protocol |
|------|----|----------|
| Frontend | API Gateway | REST, GraphQL, WebSocket |
| API Gateway | Employee Service | gRPC |
| API Gateway | Time Service | gRPC |
| API Gateway | Notification Service | HTTP |
| API Gateway | Keycloak | HTTP (JWT validation) |
| Time Service | Employee Service | gRPC (validate manager) |
| Time Service | RabbitMQ | AMQP (Outbox pattern) |
| Notification Service | RabbitMQ | AMQP (consumer) |
| Socket Service | RabbitMQ | AMQP (consumer) |
| Frontend | Socket Service | WebSocket (Socket.IO) |

---

## Tech Stack

### Backend (.NET 8)

| Technology | Purpose |
|------------|---------|
| ASP.NET Core 8.0 | Web framework |
| Entity Framework Core 8.0 | ORM |
| gRPC | Inter-service communication |
| MediatR 12.x | CQRS pattern |
| AutoMapper 13.x | Object mapping |
| FluentValidation 11.x | Input validation |
| HotChocolate 13.x | GraphQL (API Gateway) |
| SignalR 8.0 | WebSocket (Notification Service) |
| Hangfire | Background jobs (Time Service) |
| Serilog | Structured logging |

### Frontend

| Technology | Purpose |
|------------|---------|
| Next.js 14.0.4 | React framework |
| TypeScript 5 | Type safety |
| MUI (Material UI) 5.15 | UI components |
| Redux Toolkit 2.0 | State management |
| Apollo Client 3.8 | GraphQL client |
| keycloak-js 23.0 | SSO integration |
| SignalR Client 8.0 | Real-time notifications |
| Recharts 2.10 | Charts |

### Infrastructure

| Technology | Version | Purpose |
|------------|---------|---------|
| PostgreSQL | 16-alpine | Database (5 instances) |
| Redis | 7-alpine | Caching (attendance status) |
| RabbitMQ | 3-management-alpine | Event messaging |
| Keycloak | 23.0 | SSO / OAuth2 / OIDC |
| MinIO | latest | Object storage |
| Socket.IO (Node.js) | - | Real-time WebSocket |

---

## Cấu trúc thư mục

```
hrm/
├── hrm-deployment/                # Infrastructure & deployment config
│   ├── docker-compose.yml         # Docker infrastructure
│   ├── .env                       # Environment variables (from env/*.txt)
│   ├── run-all-services.bat       # Start all services (Windows)
│   ├── run-all-services.sh        # Start all services (Linux/Mac)
│   ├── env/                       # Environment file templates
│   │   ├── docker-compose.env.txt
│   │   └── socket.env.txt
│   ├── infrastructure/
│   │   ├── authz/                 # Authorization schema (SQL)
│   │   ├── keycloak/              # Keycloak realm, themes
│   │   └── socket/                # Socket Service (Node.js)
│   ├── config/generated/PRO/      # Production config files
│   │   ├── api-gateway/appsettings.Production.json
│   │   ├── employee-service/appsettings.Production.json
│   │   ├── time-service/appsettings.Production.json
│   │   ├── notification-service/appsettings.Production.json
│   │   └── socket-service/.env
│   └── docker-images/             # Pre-packaged Docker images (.tar)
│
├── hrm-ApiGateway/                # API Gateway (.NET 8)
│   └── src/
│       ├── API/                   # Controllers, GraphQL, Hubs, Protos
│       └── Application/           # gRPC client services
│
├── hrm-employee-service/          # Employee Service (.NET 8)
│   └── src/
│       ├── API/                   # gRPC services
│       ├── Application/           # CQRS commands/queries
│       ├── Domain/                # Entities, Enums
│       └── Infrastructure/        # EF Core, Repositories
│
├── hrm-Time-Service/              # Time Service (.NET 8)
│   └── src/
│       ├── API/                   # gRPC services, BackgroundServices
│       ├── Application/           # CQRS (Attendance, Leave, Overtime)
│       ├── Domain/                # Entities, Enums
│       └── Infrastructure/        # EF Core, RabbitMQ, Redis
│
├── hrm-Notification-Service/      # Notification Service (.NET 8)
│   └── src/
│       ├── API/                   # Controllers, SignalR Hub, RabbitMQ consumer
│       ├── Application/           # CQRS commands/queries
│       ├── Domain/                # Entities, Enums
│       └── Infrastructure/        # EF Core
│
├── hrm-nextjs/                    # Frontend (Next.js 14)
│
└── RUN_SERVICES.md                # (Legacy) setup guide
```

Tất cả .NET services sử dụng **Clean Architecture 4-Layer**: API → Application → Domain → Infrastructure.

---

## Yêu cầu hệ thống

| Phần mềm | Version | Kiểm tra |
|----------|---------|----------|
| Docker Desktop | 4.x+ | `docker --version` |
| .NET SDK | 8.0+ | `dotnet --version` |
| Node.js | 18+ | `node --version` |
| RAM | 8GB+ | - |

**Ports cần khả dụng:** `3000, 5000-5005, 5100, 5432-5436, 6379, 5672, 8080, 9000-9001, 15672`

---

## Hướng dẫn cài đặt từ đầu

### Bước 1: Clone repository

```bash
git clone <repository-url>
cd hrm
```

### Bước 2: Load Docker Images (offline)

Project sử dụng Docker images offline - không cần internet.

**Windows (PowerShell):**
```powershell
cd hrm-deployment
Get-ChildItem docker-images\*.tar | ForEach-Object {
    Write-Host "Loading $($_.Name)..."
    docker load -i $_.FullName
}
```

**Windows (Git Bash / WSL) / Linux / Mac:**
```bash
cd hrm-deployment
for file in docker-images/*.tar; do
    echo "Loading $file..."
    docker load -i "$file"
done
```

**Xác nhận images đã load:**
```bash
docker images
```

Kết quả mong đợi:
```
REPOSITORY                      TAG
postgres                        16-alpine
redis                           7-alpine
rabbitmq                        3-management-alpine
quay.io/keycloak/keycloak       23.0
minio/minio                     latest
node                            20-alpine
```

### Bước 3: Copy Environment Files

```bash
cd hrm-deployment

# Copy Docker Compose environment
cp env/docker-compose.env.txt .env

# Copy Socket Service environment (QUAN TRỌNG!)
cp env/socket.env.txt config/generated/PRO/socket-service/.env
```

### Bước 4: Cấu hình Frontend

```bash
cd ../hrm-nextjs
cp .env.example .env.local
```

Kiểm tra nội dung `.env.local`:
```env
NEXT_PUBLIC_API_URL=http://localhost:5000
NEXT_PUBLIC_KEYCLOAK_URL=http://localhost:8080
NEXT_PUBLIC_KEYCLOAK_REALM=hrm
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=hrm-frontend
NEXT_PUBLIC_NOTIFICATION_HUB_URL=http://localhost:5005/hubs/notification
```

### Bước 5: Cài đặt dependencies cho Frontend

```bash
cd hrm-nextjs
npm install
```

---

## Khởi động hệ thống

### Bước 1: Khởi động Docker Infrastructure

```bash
cd hrm-deployment
docker compose up -d --build
```

**Đợi tất cả containers healthy (khoảng 60-90 giây):**
```bash
docker compose ps
```

Kết quả mong đợi - tất cả phải "Up" và hầu hết "healthy":
```
NAME                        STATUS
hrm-postgres-employee       Up (healthy)
hrm-postgres-time           Up (healthy)
hrm-postgres-notification   Up (healthy)
hrm-postgres-keycloak       Up (healthy)
hrm-postgres-authz          Up (healthy)
hrm-redis                   Up (healthy)
hrm-rabbitmq                Up (healthy)
hrm-keycloak                Up (healthy hoặc unhealthy*)
hrm-minio                   Up (healthy)
hrm-socket                  Up (healthy hoặc unhealthy*)
```

> **Lưu ý:** Keycloak và Socket có thể hiển thị "unhealthy" do healthcheck configuration, nhưng vẫn hoạt động bình thường. Xem [Lưu ý quan trọng](#lưu-ý-quan-trọng).

### Bước 2: Khởi động Application Services

Mở **5 terminal riêng biệt** và chạy lần lượt:

**Terminal 1 - Employee Service:**
```bash
cd hrm-employee-service
dotnet restore
dotnet run
```

**Terminal 2 - Time Service:**
```bash
cd hrm-Time-Service
dotnet restore
dotnet run
```

**Terminal 3 - Notification Service:**
```bash
cd hrm-Notification-Service
dotnet restore
dotnet run
```

**Terminal 4 - API Gateway:**
```bash
cd hrm-ApiGateway
dotnet restore
dotnet run
```

**Terminal 5 - Frontend:**
```bash
cd hrm-nextjs
npm run dev
```

> **Tip:** Sử dụng `dotnet watch run` thay `dotnet run` để auto-reload khi thay đổi code.

---

## Xác nhận hệ thống hoạt động

### Kiểm tra Health Endpoints

```bash
# Employee Service
curl http://localhost:5001/health
# Expected: Healthy

# Time Service
curl http://localhost:5003/health
# Expected: Healthy

# Notification Service
curl http://localhost:5005/health
# Expected: Healthy

# API Gateway
curl http://localhost:5000/health
# Expected: Healthy

# Socket Service
curl http://localhost:5100/health
# Expected: {"status":"healthy","service":"hrm-socket",...}

# Keycloak OIDC
curl http://localhost:8080/realms/hrm/.well-known/openid-configuration
# Expected: JSON với issuer, authorization_endpoint, etc.
```

### Truy cập Web Interfaces

| Service | URL | Ghi chú |
|---------|-----|---------|
| **Frontend** | http://localhost:3000 | Ứng dụng chính |
| **Swagger API** | http://localhost:5000/swagger | API Documentation |
| **GraphQL Playground** | http://localhost:5000/graphql | GraphQL queries |
| **Keycloak Admin** | http://localhost:8080/admin | SSO Management |
| **RabbitMQ Management** | http://localhost:15672 | Message Queue |
| **MinIO Console** | http://localhost:9001 | Object Storage |
| **Hangfire Dashboard** | http://localhost:5003/hangfire | Background Jobs |

---

## Port Reference

### Docker Infrastructure

| Service | Port | Protocol |
|---------|------|----------|
| PostgreSQL Employee DB | 5432 | TCP |
| PostgreSQL Time DB | 5433 | TCP |
| PostgreSQL Notification DB | 5434 | TCP |
| PostgreSQL Keycloak DB | 5435 | TCP |
| PostgreSQL Authz DB | 5436 | TCP |
| Redis | 6379 | TCP |
| RabbitMQ Server | 5672 | AMQP |
| RabbitMQ Management UI | 15672 | HTTP |
| Keycloak SSO | 8080 | HTTP |
| MinIO API | 9000 | HTTP |
| MinIO Console | 9001 | HTTP |
| Socket Service | 5100 | WebSocket |

### Application Services (Local)

| Service | HTTP Port | gRPC Port | Command |
|---------|-----------|-----------|---------|
| Employee Service | 5001 | 5002 | `dotnet run` |
| Time Service | 5003 | 5004 | `dotnet run` |
| Notification Service | 5005 | - | `dotnet run` |
| API Gateway | 5000 | - | `dotnet run` |
| Frontend | 3000 | - | `npm run dev` |

---

## Thông tin đăng nhập

### Application Users (Keycloak)

| Role | Username | Password | Realm Roles |
|------|----------|----------|-------------|
| Admin | admin | admin123 | system_admin, employee |
| HR | hr_user | hr123 | hr_staff, employee |
| Manager | manager_user | manager123 | manager, employee |
| Employee | employee_user | employee123 | employee |

### Infrastructure Services

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| Keycloak Admin | http://localhost:8080/admin | admin | admin |
| RabbitMQ Management | http://localhost:15672 | hrm_user | hrm_pass |
| MinIO Console | http://localhost:9001 | minio_user | minio_pass |

### Databases

| Database | Port | Username | Password | DB Name |
|----------|------|----------|----------|---------|
| Employee DB | 5432 | employee_user | employee_pass | employee_db |
| Time DB | 5433 | time_user | time_pass | time_db |
| Notification DB | 5434 | notification_user | notification_pass | notification_db |
| Keycloak DB | 5435 | keycloak_user | keycloak_pass | keycloak_db |
| Authz DB | 5436 | authz_user | authz_pass | authz_db |

---

## Chi tiết từng Service

### Frontend (Next.js)

SPA dashboard cho toàn bộ hệ thống HRM. Sử dụng Next.js 14 App Router.

**Tính năng chính:**
- Dashboard với stats, check-in/out nhanh
- Quản lý nhân viên (CRUD, search, filter, CSV export)
- Sơ đồ tổ chức (GraphQL, react-organizational-chart)
- Chấm công (check-in/out với GPS, lịch sử, team attendance)
- Nghỉ phép / Tăng ca (tạo đơn, xem balance, approval workflow)
- Approvals Hub (duyệt hàng loạt, audit trail)
- Thông báo real-time (SignalR WebSocket, badge count)
- Analytics & Reports (charts với Recharts, CSV export)
- Profile & Settings (đổi mật khẩu, notification preferences)

**Routes:**

| Route | Quyền | Mô tả |
|-------|-------|-------|
| `/` | Public | Login |
| `/dashboard` | Employee | Dashboard, check-in/out |
| `/attendance` | Employee | Lịch sử chấm công |
| `/leave` | Employee | Đơn nghỉ phép, balance |
| `/overtime` | Employee | Đơn tăng ca |
| `/shifts` | Employee | Ca làm việc |
| `/organization` | Employee | Sơ đồ tổ chức |
| `/notifications` | Employee | Thông báo |
| `/profile` | Employee | Hồ sơ cá nhân |
| `/employees` | Manager/HR | Quản lý nhân viên |
| `/teams` | Manager/HR | Quản lý team |
| `/team-attendance` | Manager/HR | Chấm công team |
| `/approvals` | Manager/HR | Duyệt đơn |
| `/reports` | Manager/HR | Báo cáo, analytics |

**Environment Variables (`.env.local`):**

```
NEXT_PUBLIC_API_URL=http://localhost:5000
NEXT_PUBLIC_KEYCLOAK_URL=http://localhost:8080
NEXT_PUBLIC_KEYCLOAK_REALM=hrm
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=hrm-frontend
NEXT_PUBLIC_NOTIFICATION_HUB_URL=http://localhost:5000/hubs/notification
```

**Cấu trúc app:**

```
app/
├── page.tsx                    # Login
├── layout.tsx                  # Root layout + providers
├── (auth)/                     # Auth-protected routes
│   ├── dashboard/
│   ├── employees/
│   ├── attendance/
│   ├── leave/
│   ├── overtime/
│   ├── approvals/
│   ├── teams/
│   ├── team-attendance/
│   ├── shifts/
│   ├── organization/
│   ├── profile/
│   ├── notifications/
│   └── reports/
├── components/
│   ├── layout/Layout.tsx       # Main layout wrapper
│   └── providers/
│       ├── AuthProvider.tsx     # Keycloak auth init
│       └── NotificationProvider.tsx  # SignalR setup
└── lib/
    ├── api.ts                  # REST API client
    ├── apollo.ts               # GraphQL client
    ├── auth.ts                 # JWT management
    ├── signalr.ts              # SignalR hub connection
    ├── export.ts               # CSV export
    └── keycloak.ts             # Keycloak integration
store/
├── index.ts                    # Redux store
└── slices/
    ├── authSlice.ts
    ├── attendanceSlice.ts
    └── notificationSlice.ts
```

**State Management (Redux Toolkit):**
- `authSlice` — `isAuthenticated`, `user`, `token` (auto-refresh mỗi 4 phút)
- `attendanceSlice` — `isCheckedIn`, `checkInTime`, `checkOutTime`, `currentHours`
- `notificationSlice` — `notifications[]`, `unreadCount`

**SignalR:** Auto-reconnect với exponential backoff (1s → 3s → 5s). JWT auth qua Keycloak token.

---

### API Gateway

Entry point cho tất cả client requests. Aggregation layer giữa frontend và backend services.

**Chức năng chính:**
- Routing requests tới microservices
- JWT Authentication (Keycloak)
- Role-based Authorization
- Aggregation dữ liệu từ nhiều services (REST → gRPC translation)
- Swagger UI (`/swagger`), GraphQL Playground (`/graphql`)

**REST API Endpoints:**

| Group | Prefix | Chức năng |
|-------|--------|-----------|
| Auth | `/api/auth` | Login, logout, refresh token, change password |
| Employees | `/api/employees` | CRUD nhân viên, departments, teams |
| Attendance | `/api/attendance` | Check-in/out, history, team attendance |
| Leave | `/api/leave` | Tạo/duyệt/từ chối đơn nghỉ phép |
| Overtime | `/api/overtime` | Tạo/duyệt/từ chối đơn tăng ca |
| Notifications | `/api/notifications` | Danh sách, đánh dấu đã đọc |

**GraphQL Queries:** `getOrgChart`, `getDepartments`, `getTeams`, `getTeamMembers`

**Authorization Policies:**

| Policy | Role | Mô tả |
|--------|------|-------|
| Employee | `employee` | Quyền cơ bản |
| Manager | `manager` | Quản lý team |
| HRStaff | `hr_staff` | Nghiệp vụ HR |
| Admin | `system_admin` | Full access |
| ManagerOrHR | `manager` OR `hr_staff` | Duyệt đơn |

---

### Employee Service

gRPC microservice quản lý nhân viên, phòng ban, team, công ty.

**Nghiệp vụ:**
- CRUD nhân viên (tạo: `hr_staff`, xóa: `system_admin`)
- Quản lý phòng ban, team (hỗ trợ phòng ban con)
- Sơ đồ tổ chức (org chart)
- Gán vai trò Keycloak cho nhân viên
- Xác thực manager permission (cho Time Service gọi khi duyệt đơn)

**Trạng thái nhân viên:** Active, OnLeave, Inactive, Probation, Terminated, Resigned

**Loại hình:** FullTime, PartTime, Contract, Temporary, Intern

**Database:** `employee_db` trên `localhost:5432`

**Seed Data:** 7 phòng ban, 14 teams, 30 nhân viên mẫu.

---

### Time Service

gRPC microservice quản lý chấm công, nghỉ phép, tăng ca, ca làm việc.

**Nghiệp vụ chấm công:**
- Check-in/out với GPS, IP, device info
- Tính toán tự động: đi muộn, về sớm, OT, tổng giờ làm
- Cache trạng thái trên Redis (5 phút)

**Nghiệp vụ nghỉ phép — Quy trình duyệt 2 cấp:**
```
Employee (tạo đơn) → Manager (Level 1) → HR Staff (Level 2) → Approved/Rejected
```

| Loại nghỉ | Số ngày mặc định |
|-----------|------------------|
| Annual | 12/năm |
| Sick | 10/năm |
| Unpaid | Không giới hạn |
| Maternity | 180 ngày |
| Paternity | 5 ngày |
| Wedding | 3 ngày |
| Bereavement | 3 ngày |

**Event-Driven (Outbox Pattern):** Sau mỗi thao tác (check-in, duyệt đơn...), event được lưu vào bảng `outbox_messages`, background job (Hangfire) xử lý và publish lên RabbitMQ exchange `hrm.events`.

**Database:** `time_db` trên `localhost:5433` | **Redis:** `localhost:6379`

**Hangfire Dashboard:** http://localhost:5003/hangfire

---

### Notification Service

HTTP microservice quản lý thông báo real-time qua SignalR.

**Nghiệp vụ:**
- Nhận events từ RabbitMQ → lưu DB → push qua SignalR
- REST API: danh sách thông báo, mark as read, preferences
- Notification templates (title/message templates với placeholders)
- User connection tracking (SignalR connection lifecycle)

**SignalR Hub:** `ws://localhost:5005/hubs/notification`

| Server → Client Event | Mô tả |
|------------------------|-------|
| `ReceiveNotification` | Thông báo mới |
| `NotificationRead` | Xác nhận đã đọc |
| `UnreadCountUpdated` | Cập nhật badge count |

**Notification Types:** LeaveRequestCreated/Approved/Rejected, AttendanceReminder, OvertimeRequest*, EmployeeOnboarding/Offboarding, BirthdayReminder, SystemAnnouncement...

**Database:** `notification_db` trên `localhost:5434`

---

### Socket Service

Node.js WebSocket service sử dụng Socket.IO, chạy trong Docker container.

**Chức năng:**
- Real-time event broadcasting từ RabbitMQ tới frontend
- Room-based messaging: `user:{userId}`, `employee:{employeeId}`, `role:{roleName}`, `team:{teamId}`
- JWT authentication thông qua API Gateway (`/api/auth/me`)

**Events:**

| Category | Events |
|----------|--------|
| Attendance | `attendance_checked_in`, `attendance_checked_out` |
| Leave | `leave_request_created/approved/rejected/cancelled` |
| Overtime | `overtime_request_created/approved/rejected` |
| Team | `team_member_checked_in`, `team_leave_request`, `team_overtime_request` |

**Frontend connection:**
```javascript
import { io } from 'socket.io-client';
const socket = io('http://localhost:5100', {
    auth: { token: keycloakJWT },
    transports: ['websocket', 'polling']
});
```

**Endpoints:** `/` (Socket.IO), `/health`, `/stats`

**Config:** `config/generated/PRO/socket-service/.env`

| Variable | Default |
|----------|---------|
| SERVER_PORT | 5001 (internal) |
| AUTH_API | http://api-gateway:8080/api/auth/me |
| RABBITMQ_HOST | rabbitmq |
| RABBITMQ_PORT | 5672 |
| RABBITMQ_USER | hrm_user |
| RABBITMQ_PASSWORD | hrm_pass |
| RABBITMQ_WORK_QUEUE_NAME | hrm_socket_work_queue |

---

### Keycloak (SSO)

OAuth 2.0 / OpenID Connect authentication cho toàn bộ hệ thống.

**Realm:** `hrm` (auto-import từ `realm-export.json`)

**Realm Roles:**

| Role | Mô tả |
|------|-------|
| `employee` | Quyền cơ bản: check-in/out, xem data cá nhân, tạo đơn |
| `manager` | Xem team, duyệt đơn Level 1 |
| `hr_staff` | CRUD nhân viên, duyệt cuối Level 2, export báo cáo |
| `system_admin` | Full access |

**Clients:**

| Client ID | Type | Mô tả |
|-----------|------|-------|
| `hrm-api` | Confidential | Backend services |
| `hrm-frontend` | Public | Next.js frontend |

**Client Roles (`hrm-api`):** `employee.read`, `employee.write`, `attendance.read/write`, `leave.read/write/approve`, `overtime.read/write/approve`, `report.read/export`, `admin`

**Custom Theme:** Login page custom (HRM branding, hỗ trợ tiếng Việt), mount qua Docker volume `themes/hrm`.

**JWT Custom Claims:** `employee_id`, `roles`, `resource_access.hrm-api.roles`

**OIDC Discovery:** http://localhost:8080/realms/hrm/.well-known/openid-configuration

---

### Authorization Service

Policy-based Access Control bổ sung cho Keycloak RBAC, sử dụng PostgreSQL function.

**Database:** `authz_db` trên `localhost:5436`, schema `authz`

**Check permission:**
```sql
SELECT authz.check_permission('manager', 'leave', 'approve');  -- true
SELECT authz.check_permission('employee', 'leave', 'approve'); -- false
```

**Resources:** employee, department, team, company, attendance, leave, overtime, shift, notification, report, settings

**Actions:** read, write, delete, approve, reject, export, manage

**Policies:**

| Policy | Áp dụng cho Role |
|--------|------------------|
| `employee_basic` | employee (read/write trên data cá nhân) |
| `manager_access` | manager (read, approve, reject trên team) |
| `hr_staff_access` | hr_staff (full CRUD, export, manage) |
| `admin_full_access` | system_admin (ALL resources, ALL actions) |

Schema tự động init qua `docker-entrypoint-initdb.d`.

---

## Cấu hình môi trường

### Environment Files

```
hrm-deployment/
├── .env                              # Docker Compose env (copy từ env/docker-compose.env.txt)
├── env/
│   ├── docker-compose.env.txt        # Template (committed to git)
│   └── socket.env.txt                # Template (committed to git)
└── config/generated/PRO/
    ├── api-gateway/appsettings.Production.json
    ├── employee-service/appsettings.Production.json
    ├── time-service/appsettings.Production.json
    ├── notification-service/appsettings.Production.json
    └── socket-service/.env
```

File `.env` nằm trong `.gitignore`. File `.txt` template được commit.

### Service Config (appsettings.json mặc định cho local dev)

**Employee Service:**
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=employee_db;Username=employee_user;Password=employee_pass"
  },
  "Keycloak": {
    "Authority": "http://localhost:8080/realms/hrm",
    "Audience": "hrm-api",
    "ClientId": "hrm-api",
    "ClientSecret": "hrm-api-secret",
    "RequireHttps": false
  }
}
```

**Time Service:**
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5433;Database=time_db;Username=time_user;Password=time_pass",
    "Redis": "localhost:6379"
  },
  "RabbitMQ": {
    "Host": "localhost", "Port": 5672,
    "Username": "hrm_user", "Password": "hrm_pass",
    "Exchange": "hrm.events"
  },
  "GrpcServices": { "EmployeeService": "http://localhost:5002" }
}
```

**Notification Service:**
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5434;Database=notification_db;Username=notification_user;Password=notification_pass"
  },
  "RabbitMQ": {
    "Host": "localhost", "Port": 5672,
    "Username": "hrm_user", "Password": "hrm_pass",
    "Exchange": "hrm.events", "Queue": "notification.queue"
  }
}
```

**API Gateway:**
```json
{
  "GrpcServices": {
    "EmployeeService": "http://localhost:5002",
    "TimeService": "http://localhost:5004"
  },
  "NotificationService": { "Url": "http://localhost:5005" },
  "Cors": { "AllowedOrigins": ["http://localhost:3000", "http://127.0.0.1:3000"] }
}
```

---

## Docker Compose Commands

```bash
cd hrm-deployment

# Start tất cả infrastructure
docker compose up -d

# Xem trạng thái
docker compose ps

# Xem logs
docker compose logs -f
docker compose logs -f keycloak       # Log 1 service

# Restart 1 service
docker compose restart rabbitmq

# Stop tất cả
docker compose down

# Reset toàn bộ (XÓA database data)
docker compose down -v && docker compose up -d
```

---

## Production Deployment

### AWS Mapping

| Local | AWS |
|-------|-----|
| PostgreSQL | RDS |
| Redis | ElastiCache |
| RabbitMQ | Amazon MQ |
| MinIO | S3 |
| Application Services | ECS Fargate / EKS |
| Secrets | AWS Secrets Manager / Parameter Store |
| Load Balancing | Application Load Balancer |

### Docker Build (từng service)

```bash
# Employee Service
cd hrm-employee-service
docker build -t hrm-employee-service .
docker run -p 5001:8080 -p 5002:8081 \
  -e ConnectionStrings__DefaultConnection="Host=host.docker.internal;Port=5432;..." \
  hrm-employee-service

# API Gateway
cd hrm-ApiGateway
docker build -t hrm-api-gateway .
docker run -p 5000:8080 \
  -e GrpcServices__EmployeeService="http://host.docker.internal:5002" \
  hrm-api-gateway
```

### Externalized Configuration

Production config được mount read-only vào containers:
```yaml
volumes:
  - ./config/generated/PRO/employee-service/appsettings.Production.json:/app/appsettings.Production.json:ro
```

Thay đổi config chỉ cần restart container, không cần rebuild image.

---

## Lưu ý quan trọng

### 1. Keycloak hiển thị "unhealthy" nhưng vẫn hoạt động

Keycloak cần 60-90 giây để khởi động hoàn toàn. Docker healthcheck có thể timeout trước khi Keycloak ready. Kiểm tra thực tế:

```bash
curl http://localhost:8080/realms/hrm/.well-known/openid-configuration
```

Nếu trả về JSON -> Keycloak hoạt động bình thường.

### 2. Socket Service config cho Hybrid Deployment

File `config/generated/PRO/socket-service/.env` cần nội dung đúng từ `env/socket.env.txt`:

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

> **Nếu Socket Service không thể xác thực user:** Thay `AUTH_API` thành `http://host.docker.internal:5000/api/auth/me` để Socket container có thể gọi API Gateway trên host machine.

### 3. Thứ tự khởi động services

**PHẢI** khởi động theo thứ tự:
1. Docker Infrastructure (docker compose up)
2. Employee Service (các service khác phụ thuộc)
3. Time Service
4. Notification Service
5. API Gateway
6. Frontend

### 4. appsettings.json phải ở thư mục gốc

Mỗi .NET service cần file `appsettings.json` ở **cùng cấp với file `.csproj`**, KHÔNG phải trong `src/API/`.

### 5. Lần đầu chạy Employee/Time/Notification Service

EF Core sẽ tự động tạo database schema (migration). Nếu gặp lỗi database, kiểm tra:
- PostgreSQL container đã healthy chưa
- Connection string trong appsettings.json đúng chưa

### 6. CORS errors trên Frontend

Nếu gặp CORS error, kiểm tra:
1. API Gateway đang chạy: `curl http://localhost:5000/health`
2. File `hrm-ApiGateway/appsettings.json` có cấu hình:
```json
"Cors": {
  "AllowedOrigins": ["http://localhost:3000", "http://127.0.0.1:3000"]
}
```

---

## Xử lý sự cố

### Port đã bị chiếm

**Windows:**
```powershell
# Tìm process đang dùng port
netstat -ano | findstr :5001

# Kill process
taskkill /PID <PID> /F
```

**Linux/Mac:**
```bash
lsof -i :5001
kill -9 <PID>
```

### Không kết nối được database

```bash
# Kiểm tra container status
docker compose ps

# Xem logs
docker compose logs postgres-employee

# Restart container cụ thể
docker compose restart postgres-employee
```

### Không kết nối được RabbitMQ

```bash
docker compose logs rabbitmq
# Đợi "Ready to accept connections"
# UI: http://localhost:15672 (hrm_user / hrm_pass)
```

### NuGet restore thất bại

```bash
cd <service-directory>
dotnet restore --no-cache
```

### Socket Service không nhận events

1. Kiểm tra RabbitMQ connection: `docker compose logs socket-service`
2. Verify queue name `hrm_socket_work_queue` match giữa Time Service và Socket Service
3. Kiểm tra user đã join đúng room

### gRPC connection lỗi

```bash
# Test Employee Service
grpcurl -plaintext localhost:5002 grpc.health.v1.Health/Check

# Test Time Service
grpcurl -plaintext localhost:5004 grpc.health.v1.Health/Check
```

### Reset toàn bộ hệ thống

```bash
# Dừng và xóa tất cả containers + volumes
cd hrm-deployment
docker compose down -v

# Kill tất cả .NET processes (Windows)
taskkill /IM dotnet.exe /F

# Kill tất cả .NET processes (Linux/Mac)
pkill -f "dotnet run"

# Xóa node_modules nếu cần
cd ../hrm-nextjs
rm -rf node_modules .next

# Khởi động lại từ đầu
cd ../hrm-deployment
docker compose up -d --build
```

### Xem logs của service

```bash
# Docker service logs
docker compose logs -f keycloak
docker compose logs -f socket-service

# .NET service logs - xem trực tiếp trong terminal đang chạy
```

### Frontend lỗi 404 static files

Nếu gặp lỗi:
```
GET http://localhost:3000/_next/static/css/app/layout.css net::ERR_ABORTED 404
GET http://localhost:3000/_next/static/chunks/main-app.js net::ERR_ABORTED 404
```

**Nguyên nhân:** Process Node.js cũ bị treo, `.next` cache không đồng bộ.

**Cách fix:**

**Windows (PowerShell):**
```powershell
# Tìm và kill process chiếm port 3000
netstat -ano | findstr :3000
taskkill /PID <PID> /F

# Hoặc kill tất cả node processes
taskkill /IM node.exe /F
```

**Windows (Git Bash):**
```bash
# Tìm PID
netstat -ano | findstr :3000

# Kill (thay <PID> bằng số PID tìm được)
taskkill //PID <PID> //F
```

**Linux/Mac:**
```bash
# Kill process trên port 3000
lsof -ti:3000 | xargs kill -9

# Hoặc
pkill -f "next dev"
```

**Sau đó restart frontend:**
```bash
cd hrm-nextjs
rm -rf .next
npm run dev
```

---

## Dừng hệ thống

### Dừng tạm thời (giữ data)

```bash
# Dừng Docker infrastructure
cd hrm-deployment
docker compose stop

# Dừng .NET services: Ctrl+C trong mỗi terminal
```

### Dừng và xóa hoàn toàn

```bash
# Xóa containers VÀ volumes (MẤT DATA)
cd hrm-deployment
docker compose down -v

# Chỉ xóa containers (GIỮ DATA)
docker compose down
```

---

## License

MIT
