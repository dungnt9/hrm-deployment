# HRM - Human Resource Management System

Hệ thống quản lý nhân sự microservices, hỗ trợ quản lý nhân viên, chấm công, nghỉ phép, tăng ca và thông báo real-time.

---

## Mục lục

- [Kiến trúc tổng thể](#kiến-trúc-tổng-thể)
- [Tech Stack](#tech-stack)
- [Cấu trúc thư mục](#cấu-trúc-thư-mục)
- [Prerequisites](#prerequisites)
- [Hướng dẫn setup local](#hướng-dẫn-setup-local)
- [Hướng dẫn chạy services](#hướng-dẫn-chạy-services)
- [Port Reference](#port-reference)
- [Credentials mặc định](#credentials-mặc-định)
- [Chi tiết từng Service](#chi-tiết-từng-service)
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
- [Troubleshooting](#troubleshooting)

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
├── run-all-services.bat           # Start all services (Windows)
├── run-all-services.sh            # Start all services (Linux/Mac)
└── RUN_SERVICES.md                # (Legacy) setup guide
```

Tất cả .NET services sử dụng **Clean Architecture 4-Layer**: API → Application → Domain → Infrastructure.

---

## Prerequisites

- **Docker Desktop** 4.x+ (với Docker Compose v2)
- **.NET 8.0 SDK**
- **Node.js** (cho frontend)
- RAM tối thiểu **8GB** cho Docker
- Ports khả dụng: `3000, 5000-5005, 5100, 5432-5436, 6379, 5672, 8080, 9000-9001, 15672`

---

## Hướng dẫn setup local

### Step 1: Load Docker Images (chỉ lần đầu)

Project sử dụng Docker images offline (`.tar` files) — không cần internet.

**Windows (PowerShell):**
```powershell
cd hrm-deployment
Get-ChildItem docker-images\*.tar | ForEach-Object { docker load -i $_.FullName }
```

**Windows (CMD):**
```cmd
cd hrm-deployment
for %f in (docker-images\*.tar) do docker load -i "%f"
```

**Linux/Mac:**
```bash
cd hrm-deployment
for file in docker-images/*.tar; do docker load -i "$file"; done
```

### Step 2: Copy environment files

```bash
cd hrm-deployment
cp env/docker-compose.env.txt .env
cp env/socket.env.txt config/generated/PRO/socket-service/.env
```

### Step 3: Khởi động infrastructure

```bash
cd hrm-deployment
docker compose up -d --build
```

Đợi tất cả containers healthy (Keycloak mất ~60-90 giây):

```bash
docker compose ps
```

### Step 4: Chạy application services

Xem mục [Hướng dẫn chạy services](#hướng-dẫn-chạy-services).

---

## Hướng dẫn chạy services

### Cách 1: Script tự động (khuyến nghị)

**Windows:**
```powershell
cd <project-root>
.\run-all-services.bat
```

**Linux/Mac:**
```bash
cd <project-root>
chmod +x run-all-services.sh
./run-all-services.sh
```

Script tự động mở 5 terminal, mỗi terminal chạy 1 service.

### Cách 2: Chạy thủ công (5 terminal riêng biệt)

```bash
# Terminal 1: Employee Service
cd hrm-employee-service && dotnet restore && dotnet run

# Terminal 2: Time Service
cd hrm-Time-Service && dotnet restore && dotnet run

# Terminal 3: Notification Service
cd hrm-Notification-Service && dotnet restore && dotnet run

# Terminal 4: API Gateway
cd hrm-ApiGateway && dotnet restore && dotnet run

# Terminal 5: Frontend
cd hrm-nextjs && npm install && npm run dev
```

### Verify

```bash
curl http://localhost:5000/health   # API Gateway
curl http://localhost:5001/health   # Employee Service
curl http://localhost:5003/health   # Time Service
curl http://localhost:5005/health   # Notification Service
curl http://localhost:5100/health   # Socket Service
```

Mở http://localhost:3000 trên browser.

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

### Application Services (local)

| Service | HTTP Port | gRPC Port | Command |
|---------|-----------|-----------|---------|
| Employee Service | 5001 | 5002 | `dotnet run` |
| Time Service | 5003 | 5004 | `dotnet run` |
| Notification Service | 5005 | - | `dotnet run` |
| API Gateway | 5000 | - | `dotnet run` |
| Frontend | 3000 | - | `npm run dev` |

---

## Credentials mặc định

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

## Troubleshooting

### Keycloak chưa ready

Keycloak mất 60-90 giây để khởi động. Đợi log hiển thị `Listening on: http://0.0.0.0:8080`:

```bash
docker compose logs -f keycloak
```

### Port đã bị chiếm

```powershell
# Windows
netstat -ano | findstr :5001
taskkill /PID <PID> /F

# Linux/Mac
lsof -i :5001
kill -9 <PID>
```

### Không kết nối được database

```bash
docker compose ps                            # Kiểm tra containers healthy
docker compose logs postgres-employee         # Xem logs
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

### Frontend CORS error

1. Verify API Gateway đang chạy: `curl http://localhost:5000/health`
2. Kiểm tra `Cors.AllowedOrigins` trong API Gateway config chứa `http://localhost:3000`

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
cd hrm-deployment
docker compose down -v

# Kill tất cả .NET processes
# Windows: Task Manager hoặc taskkill
# Linux/Mac: pkill -f "dotnet run"

# (Optional) Clear frontend
cd ../hrm-nextjs && rm -rf node_modules package-lock.json

# Start lại
cd ../hrm-deployment
docker compose up -d --build
```

### Tips phát triển

- Dùng `dotnet watch run` thay `dotnet run` để auto-reload khi thay đổi code
- Mỗi service chạy trên 1 terminal riêng để dễ theo dõi logs
- Swagger UI: http://localhost:5000/swagger
- GraphQL Playground: http://localhost:5000/graphql

---

## License

MIT
