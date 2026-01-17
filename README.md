# HRM Deployment

Deployment repository cho hệ thống **HRM (Human Resource Management)** - chứa Docker Compose và cấu hình infrastructure cho toàn bộ microservices.

**Học từ VMS Architecture:** Clean Architecture, Keycloak SSO, Policy-based Authorization, Socket Service, Config Mount Pattern.

---

## Mục lục

- [Tổng quan hệ thống](#tổng-quan-hệ-thống)
- [Quick Start](#quick-start)
- [Kiến trúc hệ thống](#kiến-trúc-hệ-thống)
- [Services & Ports](#services--ports)
- [Nghiệp vụ HRM](#nghiệp-vụ-hrm)
- [Infrastructure Components](#infrastructure-components)
- [Event-Driven Architecture](#event-driven-architecture)
- [Authentication & Authorization](#authentication--authorization)
- [Config Mount Pattern](#config-mount-pattern)
- [Volumes & Data Persistence](#volumes--data-persistence)
- [Các lệnh thường dùng](#các-lệnh-thường-dùng)
- [Troubleshooting](#troubleshooting)
- [Production Deployment](#production-deployment)

---

## Tổng quan hệ thống

Hệ thống HRM được thiết kế theo kiến trúc **Microservices** với các công nghệ:

| Thành phần | Công nghệ | Mô tả |
|------------|-----------|-------|
| Backend Services | .NET 8 | Clean Architecture + CQRS + MediatR |
| API Gateway | .NET 8 + HotChocolate | REST API + GraphQL + gRPC Client |
| Frontend | Next.js 14 | React + TypeScript + TailwindCSS |
| Database | PostgreSQL 16 | Mỗi service một database riêng |
| Cache | Redis 7 | Distributed caching |
| Message Queue | RabbitMQ 3 | Event-driven messaging (Outbox pattern) |
| Real-time | Socket.io + SignalR | WebSocket communication |
| Authentication | Keycloak 23 | OAuth 2.0 / OpenID Connect / SSO |
| Authorization | Custom Authz Service | Policy-based Access Control (PBAC) |
| Object Storage | MinIO | S3-compatible file storage |
| Container | Docker + Compose | Orchestration & deployment |

---

## Quick Start

### Yêu cầu hệ thống

- **Docker** version 24+
- **Docker Compose** version 2+
- **RAM** tối thiểu 8GB (khuyến nghị 16GB)
- **Disk** tối thiểu 10GB free

### Cấu trúc thư mục

Đảm bảo các repos nằm cùng cấp với `hrm-deployment`:

```
hrm/
├── hrm-deployment/           # (folder này)
│   ├── infrastructure/
│   │   ├── keycloak/         # SSO + Custom themes
│   │   ├── authz/            # Authorization service
│   │   └── socket/           # Real-time WebSocket (Socket.io)
│   ├── config/
│   │   └── generated/
│   │       └── PRO/          # Production config files
│   ├── docker-compose.yml
│   ├── .env.example
│   └── README.md
├── hrm-employee-service/     # Employee management (gRPC)
├── hrm-Time-Service/         # Time & Attendance (gRPC)
├── hrm-Notification-Service/ # Notification (SignalR)
├── hrm-ApiGateway/           # API Gateway (REST/GraphQL)
└── hrm-nextjs/               # Frontend (Next.js)
```

### Clone tất cả repos

```bash
# Tạo thư mục gốc
mkdir hrm && cd hrm

# Clone các repos
git clone https://github.com/<your-org>/hrm-deployment.git
git clone https://github.com/<your-org>/hrm-employee-service.git
git clone https://github.com/<your-org>/hrm-Time-Service.git
git clone https://github.com/<your-org>/hrm-Notification-Service.git
git clone https://github.com/<your-org>/hrm-ApiGateway.git
git clone https://github.com/<your-org>/hrm-nextjs.git
```

### Chạy dự án

```bash
cd hrm-deployment

# Khởi động tất cả services
docker compose up -d --build

# Theo dõi tiến trình khởi động
docker compose logs -f
```

### Kiểm tra trạng thái

```bash
# Xem trạng thái tất cả containers
docker compose ps

# Đợi Keycloak healthy (khoảng 60-90s)
watch docker compose ps keycloak
```

### Reset toàn bộ (xóa data)

```bash
docker compose down -v
docker compose up -d --build
```

---

## Kiến trúc hệ thống

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              FRONTEND LAYER                                       │
│                                                                                   │
│  ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────────────┐  │
│  │    Next.js 14   │      │   Socket.io     │      │     Keycloak Login      │  │
│  │   Port: 3000    │◄────►│    Client       │      │      (OAuth 2.0)        │  │
│  └────────┬────────┘      └────────┬────────┘      └────────────┬────────────┘  │
│           │                        │                             │               │
└───────────┼────────────────────────┼─────────────────────────────┼───────────────┘
            │ HTTP/GraphQL           │ WebSocket                   │ OAuth
            ▼                        ▼                             ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                               GATEWAY LAYER                                       │
│                                                                                   │
│  ┌─────────────────────────────────────────────┐   ┌─────────────────────────┐  │
│  │              API Gateway (.NET 8)            │   │    Socket Service       │  │
│  │         REST API + GraphQL (HotChocolate)    │   │      (Socket.io)        │  │
│  │                  Port: 5000                  │   │      Port: 5100         │  │
│  └──────────┬──────────────┬───────────────────┘   └───────────┬─────────────┘  │
│             │              │                                    │               │
└─────────────┼──────────────┼────────────────────────────────────┼───────────────┘
              │ gRPC         │ gRPC                               │ RabbitMQ
              ▼              ▼                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              SERVICE LAYER                                        │
│                                                                                   │
│  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────────────────┐ │
│  │ Employee Service │   │   Time Service   │   │   Notification Service       │ │
│  │     (gRPC)       │   │     (gRPC)       │   │       (SignalR)              │ │
│  │  Port: 5001/5002 │   │  Port: 5003/5004 │   │       Port: 5005             │ │
│  │                  │   │                  │   │                              │ │
│  │  • Employees     │   │  • Attendance    │   │  • Push Notifications        │ │
│  │  • Departments   │   │  • Leave         │   │  • User Connections          │ │
│  │  • Teams         │   │  • Overtime      │   │  • Templates                 │ │
│  │  • Positions     │   │  • Shifts        │   │  • Preferences               │ │
│  │  • Companies     │   │  • Holidays      │   │                              │ │
│  └────────┬─────────┘   └────────┬─────────┘   └──────────────┬───────────────┘ │
│           │                      │                             │                 │
└───────────┼──────────────────────┼─────────────────────────────┼─────────────────┘
            │                      │                             │
            ▼                      ▼                             ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           INFRASTRUCTURE LAYER                                    │
│                                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │ PostgreSQL   │  │ PostgreSQL   │  │ PostgreSQL   │  │     PostgreSQL       │ │
│  │ employee_db  │  │   time_db    │  │notification_db│  │    keycloak_db       │ │
│  │  Port: 5432  │  │  Port: 5433  │  │  Port: 5434  │  │     Port: 5435       │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────────────┘ │
│                                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │    Redis     │  │   RabbitMQ   │  │    MinIO     │  │   PostgreSQL         │ │
│  │   (Cache)    │  │   (Events)   │  │  (Storage)   │  │    authz_db          │ │
│  │  Port: 6379  │  │  5672/15672  │  │  9000/9001   │  │    Port: 5436        │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────────────┘ │
│                                                                                   │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                        SECURITY & AUTH LAYER                                      │
│                                                                                   │
│  ┌─────────────────────────────────────────┐   ┌─────────────────────────────┐  │
│  │         Keycloak (SSO)                   │   │      Authz Service          │  │
│  │    OAuth 2.0 / OpenID Connect            │   │  Policy-based Access Control│  │
│  │           Port: 8080                     │   │   REST: 8282 | gRPC: 8283   │  │
│  │                                          │   │        UI: 3001             │  │
│  └─────────────────────────────────────────┘   └─────────────────────────────┘  │
│                                                                                   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Services & Ports

### Application Services

| Service | Container Name | Port(s) | URL | Mô tả |
|---------|---------------|---------|-----|-------|
| Frontend | hrm-frontend | 3000 | http://localhost:3000 | Web UI (Next.js) |
| API Gateway | hrm-api-gateway | 5000 | http://localhost:5000 | REST + GraphQL entry point |
| Swagger UI | - | 5000 | http://localhost:5000/swagger | API Documentation |
| GraphQL Playground | - | 5000 | http://localhost:5000/graphql | GraphQL IDE |
| Employee Service | hrm-employee-service | 5001, 5002 | gRPC only | Employee management |
| Time Service | hrm-time-service | 5003, 5004 | http://localhost:5003/hangfire | Time & Attendance + Hangfire Dashboard |
| Notification Service | hrm-notification-service | 5005 | ws://localhost:5005/hubs/notification | SignalR Hub |
| Socket Service | hrm-socket | 5100 | ws://localhost:5100 | Socket.io real-time |

### Infrastructure Services

| Service | Container Name | Port(s) | URL | Mô tả |
|---------|---------------|---------|-----|-------|
| Keycloak | hrm-keycloak | 8080 | http://localhost:8080 | Identity & SSO |
| Authz API | - | 8282 | http://localhost:8282/v1 | Authorization REST API |
| Authz gRPC | - | 8283 | - | Authorization gRPC |
| Authz UI | - | 3001 | http://localhost:3001 | Authorization Management UI |
| RabbitMQ | hrm-rabbitmq | 5672, 15672 | http://localhost:15672 | Message Broker + Management UI |
| MinIO | hrm-minio | 9000, 9001 | http://localhost:9001 | Object Storage Console |
| Redis | hrm-redis | 6379 | - | Distributed Cache |

### Databases

| Database | Container Name | Port | Database Name | User |
|----------|---------------|------|---------------|------|
| Employee DB | hrm-postgres-employee | 5432 | employee_db | employee_user |
| Time DB | hrm-postgres-time | 5433 | time_db | time_user |
| Notification DB | hrm-postgres-notification | 5434 | notification_db | notification_user |
| Keycloak DB | hrm-postgres-keycloak | 5435 | keycloak_db | keycloak_user |
| Authz DB | hrm-postgres-authz | 5436 | authz_db | authz_user |

---

## Nghiệp vụ HRM

### 1. Quản lý Nhân sự (Employee Service)

```
┌─────────────────────────────────────────────────────────────────┐
│                    EMPLOYEE MANAGEMENT                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────┐    ┌──────────────┐    ┌────────────┐              │
│  │ Company │───►│  Department  │───►│    Team    │              │
│  └─────────┘    └──────────────┘    └─────┬──────┘              │
│                                           │                      │
│                                           ▼                      │
│                 ┌──────────────────────────────────────┐        │
│                 │              Employee                 │        │
│                 ├──────────────────────────────────────┤        │
│                 │ • Employee Code (unique)             │        │
│                 │ • Full Name, Email, Phone            │        │
│                 │ • Position (Job Title)               │        │
│                 │ • Manager (self-reference)           │        │
│                 │ • Hire Date, Status                  │        │
│                 │ • Keycloak User ID (for auth)        │        │
│                 └──────────────────────────────────────┘        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Entities:**
- **Company**: Công ty/Tập đoàn
- **Department**: Phòng ban
- **Team**: Nhóm/Tổ
- **Position**: Chức vụ
- **Employee**: Nhân viên

### 2. Quản lý Chấm công & Nghỉ phép (Time Service)

```
┌─────────────────────────────────────────────────────────────────┐
│                    TIME MANAGEMENT                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                      ATTENDANCE                             │ │
│  │  ┌──────────┐                                               │ │
│  │  │ Employee │──┬──► Check-in (time, location, device)       │ │
│  │  └──────────┘  │                                            │ │
│  │                └──► Check-out (time, work hours calculated) │ │
│  │                                                             │ │
│  │  Status: Present | Late | EarlyLeave | Absent               │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    LEAVE REQUEST                            │ │
│  │                                                             │ │
│  │  Employee ──► Create Request ──► Manager Approval           │ │
│  │                     │                    │                  │ │
│  │                     ▼                    ▼                  │ │
│  │              Pending ──────────► Approved/Rejected          │ │
│  │                                         │                   │ │
│  │                                         ▼                   │ │
│  │                                  HR Final Approval          │ │
│  │                                                             │ │
│  │  Types: Annual | Sick | Unpaid | Maternity | Paternity      │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   OVERTIME REQUEST                          │ │
│  │                                                             │ │
│  │  Employee ──► Create OT Request ──► Manager Approval        │ │
│  │                                                             │ │
│  │  • Start/End Time                                           │ │
│  │  • Reason                                                   │ │
│  │  • Calculated Hours                                         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                       SHIFT                                 │ │
│  │                                                             │ │
│  │  ┌───────────────┐     ┌───────────────┐                   │ │
│  │  │  Shift        │────►│ EmployeeShift │◄──── Employee     │ │
│  │  │ (Morning/     │     │  (assignment) │                   │ │
│  │  │  Afternoon/   │     └───────────────┘                   │ │
│  │  │  Night)       │                                         │ │
│  │  └───────────────┘                                         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Entities:**
- **Attendance**: Bản ghi chấm công (check-in/out)
- **LeaveRequest**: Đơn xin nghỉ phép
- **LeaveBalance**: Số ngày phép còn lại theo loại
- **LeavePolicy**: Chính sách nghỉ phép (số ngày/năm)
- **OvertimeRequest**: Đơn xin tăng ca
- **Shift**: Ca làm việc
- **EmployeeShift**: Phân ca cho nhân viên
- **Holiday**: Ngày lễ
- **ApprovalHistory**: Lịch sử duyệt đơn

### 3. Luồng Phê duyệt (Approval Flow)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         APPROVAL WORKFLOW                                     │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  LEAVE REQUEST FLOW:                                                          │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────────┐      │
│  │ Employee │─────►│ Pending  │─────►│ Manager  │─────►│ Manager      │      │
│  │ Creates  │      │          │      │ Reviews  │      │ Approved     │      │
│  └──────────┘      └──────────┘      └────┬─────┘      └───────┬──────┘      │
│                                           │                     │             │
│                                           ▼                     ▼             │
│                                    ┌──────────┐          ┌──────────────┐    │
│                                    │ Rejected │          │ HR Reviews   │    │
│                                    └──────────┘          └───────┬──────┘    │
│                                                                  │            │
│                                           ┌──────────────────────┼───────┐   │
│                                           ▼                      ▼       │   │
│                                    ┌──────────┐          ┌──────────────┐│   │
│                                    │ Rejected │          │ HR Approved  ││   │
│                                    └──────────┘          │ (Final)      ││   │
│                                                          └──────────────┘│   │
│                                                                          │   │
│  ApprovalHistory: Tracks who approved/rejected and when                  │   │
│  ───────────────────────────────────────────────────────────────────────│   │
│  │ ApprovalStep │ Approver  │ Status   │ Comment    │ Timestamp │       │   │
│  │ Manager      │ John Doe  │ Approved │ OK         │ 2024-01-15│       │   │
│  │ HR           │ Jane HR   │ Approved │ Processed  │ 2024-01-16│       │   │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4. Thông báo Real-time (Notification Service)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                      NOTIFICATION SYSTEM                                      │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  NOTIFICATION TYPES:                                                          │
│  ┌────────────────┬────────────────────────────────────────────────────────┐ │
│  │ Type           │ Description                                            │ │
│  ├────────────────┼────────────────────────────────────────────────────────┤ │
│  │ System         │ System announcements, maintenance notices              │ │
│  │ LeaveRequest   │ Leave request created/approved/rejected                │ │
│  │ Overtime       │ Overtime request status changes                        │ │
│  │ Attendance     │ Check-in/out reminders, late warnings                  │ │
│  │ Team           │ Team updates for managers                              │ │
│  │ Announcement   │ Company-wide announcements                             │ │
│  └────────────────┴────────────────────────────────────────────────────────┘ │
│                                                                               │
│  DELIVERY CHANNELS:                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  In-App     │  │   Email     │  │    Push     │  │     SMS     │         │
│  │ (SignalR)   │  │             │  │             │  │             │         │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                                               │
│  USER PREFERENCES:                                                            │
│  • Enable/disable by notification type                                        │
│  • Enable/disable by channel                                                  │
│  • Quiet hours configuration                                                  │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Infrastructure Components

### 1. Keycloak (SSO Authentication)

**Đường dẫn:** `infrastructure/keycloak/`

```
infrastructure/keycloak/
├── Dockerfile                    # Optimized Keycloak build
├── docker-compose.yml            # Standalone Keycloak compose
├── realm-export.json             # Pre-configured HRM realm
├── README.md
└── themes/
    └── hrm/
        └── login/
            ├── theme.properties
            ├── resources/css/login.css
            └── messages/
                ├── messages_en.properties
                └── messages_vi.properties
```

**Cấu hình Realm HRM:**
- **Realm name:** `hrm`
- **Client ID:** `hrm-api` (backend), `hrm-frontend` (frontend)
- **Roles:** `system_admin`, `hr_staff`, `manager`, `employee`

**Chạy riêng Keycloak:**
```bash
cd infrastructure/keycloak
docker compose up -d
```

### 2. Authz (Authorization Service)

**Đường dẫn:** `infrastructure/authz/`

```
infrastructure/authz/
├── docker-compose.yml
├── schema.postgres.sql          # Authorization schema + default policies
└── README.md
```

**Authorization Model:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AUTHORIZATION MODEL                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐                                                            │
│  │   ROLES     │──────────────────────────────────────┐                     │
│  │ (Keycloak)  │                                      │                     │
│  └─────────────┘                                      ▼                     │
│        │                                       ┌─────────────┐              │
│        │                                       │  POLICIES   │              │
│        │                                       └──────┬──────┘              │
│        │                                              │                     │
│        │         ┌────────────────────────────────────┼──────────────┐     │
│        │         ▼                                    ▼              │     │
│        │  ┌─────────────┐                      ┌─────────────┐       │     │
│        │  │  RESOURCES  │                      │   ACTIONS   │       │     │
│        │  └─────────────┘                      └─────────────┘       │     │
│        │                                                             │     │
│        │  employee, department,                read, write,          │     │
│        │  team, attendance,                    delete, approve,      │     │
│        │  leave, overtime,                     reject, export,       │     │
│        │  shift, notification,                 manage                │     │
│        │  report, settings                                           │     │
│        │                                                             │     │
│        ▼                                                             │     │
│  ┌─────────────────────────────────────────────────────────────────┐│     │
│  │                    DEFAULT POLICIES                              ││     │
│  ├─────────────────────────────────────────────────────────────────┤│     │
│  │ employee       │ employee_basic   │ read, write on own data    ││     │
│  │ manager        │ manager_access   │ + approve, reject on team  ││     │
│  │ hr_staff       │ hr_staff_access  │ + full HR management       ││     │
│  │ system_admin   │ admin_full_access│ full access to everything  ││     │
│  └─────────────────────────────────────────────────────────────────┘│     │
│                                                                      │     │
└─────────────────────────────────────────────────────────────────────┴─────┘
```

**Chạy riêng Authz:**
```bash
cd infrastructure/authz
docker compose up -d
```

### 3. Socket Service (Real-time WebSocket)

**Đường dẫn:** `infrastructure/socket/`

```
infrastructure/socket/
├── index.js                     # Socket.io server + RabbitMQ consumer
├── Dockerfile
├── docker-compose.yml
├── package.json
├── .env.example
└── README.md
```

**HRM Events:**

| Event | Mô tả | Target |
|-------|-------|--------|
| `notification` | New notification | Specific user |
| `notification_read` | Notification marked as read | Specific user |
| `attendance_checked_in` | Employee checked in | User + Manager |
| `attendance_checked_out` | Employee checked out | User + Manager |
| `leave_request_created` | New leave request | Manager |
| `leave_request_approved` | Leave approved | Employee |
| `leave_request_rejected` | Leave rejected | Employee |
| `overtime_request_created` | New OT request | Manager |
| `overtime_request_approved` | OT approved | Employee |
| `team_member_checked_in` | Team member activity | Manager |
| `team_leave_request` | Team leave request | Manager |

**Room Types:**
- `user:{userId}` - User-specific room
- `employee:{employeeId}` - Employee-specific room
- `team:{teamId}` - Team room (for managers)
- `department:{deptId}` - Department room
- `role:{roleName}` - Role-based room

---

## Event-Driven Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           EVENT-DRIVEN FLOW                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  1. ACTION OCCURS                                                                │
│  ┌──────────────────┐                                                           │
│  │   Time Service   │ ──► Leave Request Approved                                │
│  └────────┬─────────┘                                                           │
│           │                                                                      │
│  2. CREATE OUTBOX MESSAGE                                                        │
│           │                                                                      │
│           ▼                                                                      │
│  ┌──────────────────┐                                                           │
│  │  OutboxMessage   │ ──► Stored in database (same transaction)                │
│  │  {               │                                                           │
│  │    Type: "Leave" │                                                           │
│  │    Payload: {...}│                                                           │
│  │    Processed: N  │                                                           │
│  │  }               │                                                           │
│  └────────┬─────────┘                                                           │
│           │                                                                      │
│  3. BACKGROUND JOB PROCESSES OUTBOX                                              │
│           │                                                                      │
│           ▼                                                                      │
│  ┌──────────────────┐                                                           │
│  │    Hangfire      │ ──► Polls OutboxMessage table                             │
│  │   Background     │                                                           │
│  │      Job         │                                                           │
│  └────────┬─────────┘                                                           │
│           │                                                                      │
│  4. PUBLISH TO RABBITMQ                                                          │
│           │                                                                      │
│           ▼                                                                      │
│  ┌──────────────────┐        ┌──────────────────────────────────────────────┐  │
│  │    RabbitMQ      │        │  Message Format:                             │  │
│  │                  │        │  {                                           │  │
│  │  hrm_socket_     │        │    "event": "leave_request_approved",        │  │
│  │  work_queue      │        │    "payload": { requestId, employeeId, ... },│  │
│  │                  │        │    "userIds": ["user-uuid-1"],               │  │
│  └────────┬─────────┘        │    "employeeIds": ["EMP001"],                │  │
│           │                  │    "roles": ["manager"]                      │  │
│           │                  │  }                                           │  │
│           │                  └──────────────────────────────────────────────┘  │
│  5. SOCKET SERVICE CONSUMES                                                      │
│           │                                                                      │
│           ▼                                                                      │
│  ┌──────────────────┐                                                           │
│  │  Socket Service  │ ──► Consume message from queue                            │
│  │   (Node.js)      │                                                           │
│  └────────┬─────────┘                                                           │
│           │                                                                      │
│  6. EMIT TO CONNECTED CLIENTS                                                    │
│           │                                                                      │
│           ▼                                                                      │
│  ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐      │
│  │   Frontend 1     │      │   Frontend 2     │      │   Frontend N     │      │
│  │  (Browser Tab)   │      │  (Mobile App)    │      │   (Any Client)   │      │
│  └──────────────────┘      └──────────────────┘      └──────────────────┘      │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Outbox Pattern Benefits:**
- ✅ Transactional consistency
- ✅ At-least-once delivery
- ✅ Retry on failure
- ✅ No distributed transaction needed

---

## Authentication & Authorization

### Authentication Flow (Keycloak)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           AUTHENTICATION FLOW                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  1. USER INITIATES LOGIN                                                         │
│  ┌──────────────┐                                                               │
│  │   Frontend   │ ──► Click "Login" button                                      │
│  └──────┬───────┘                                                               │
│         │                                                                        │
│  2. REDIRECT TO KEYCLOAK                                                         │
│         │                                                                        │
│         ▼                                                                        │
│  ┌──────────────┐                                                               │
│  │   Keycloak   │ ──► User enters credentials                                   │
│  │  Login Page  │     (HRM themed login page)                                   │
│  └──────┬───────┘                                                               │
│         │                                                                        │
│  3. TOKENS ISSUED                                                                │
│         │                                                                        │
│         ▼                                                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐       │
│  │  Tokens Returned:                                                    │       │
│  │  ├─ access_token  (JWT, 5 min TTL) - for API calls                   │       │
│  │  ├─ refresh_token (30 min TTL) - for token refresh                   │       │
│  │  └─ id_token      (user info)                                        │       │
│  └──────────────────────────────────────────────────────────────────────┘       │
│         │                                                                        │
│  4. API CALLS WITH TOKEN                                                         │
│         │                                                                        │
│         ▼                                                                        │
│  ┌──────────────┐         ┌──────────────┐         ┌──────────────┐            │
│  │   Frontend   │ ──────► │ API Gateway  │ ──────► │   Keycloak   │            │
│  │              │ Bearer  │              │ Verify  │   (JWKS)     │            │
│  │              │ Token   │              │ Token   │              │            │
│  └──────────────┘         └──────────────┘         └──────────────┘            │
│                                                                                  │
│  5. TOKEN REFRESH (automatic)                                                    │
│  ┌──────────────┐         ┌──────────────┐                                      │
│  │   Frontend   │ ──────► │   Keycloak   │ ──► New access_token                 │
│  │ (before exp) │ refresh │              │                                      │
│  └──────────────┘         └──────────────┘                                      │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Authorization Flow (Authz Service)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           AUTHORIZATION FLOW                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  1. REQUEST WITH TOKEN                                                           │
│  ┌──────────────┐         ┌──────────────┐                                      │
│  │   Frontend   │ ──────► │ API Gateway  │                                      │
│  │              │  POST   │              │                                      │
│  │              │ /leave  │              │                                      │
│  └──────────────┘         └──────┬───────┘                                      │
│                                  │                                               │
│  2. EXTRACT ROLES FROM TOKEN                                                     │
│                                  │                                               │
│                                  ▼                                               │
│                    ┌──────────────────────────┐                                 │
│                    │  JWT Claims:             │                                 │
│                    │  {                       │                                 │
│                    │    sub: "user-id",       │                                 │
│                    │    roles: ["employee"],  │                                 │
│                    │    employee_id: "EMP001" │                                 │
│                    │  }                       │                                 │
│                    └────────────┬─────────────┘                                 │
│                                 │                                                │
│  3. CHECK PERMISSION                                                             │
│                                 │                                                │
│                                 ▼                                                │
│  ┌──────────────┐         ┌──────────────┐                                      │
│  │ API Gateway  │ ──gRPC─► │    Authz     │                                      │
│  │              │         │   Service    │                                      │
│  │              │◄────────│              │                                      │
│  └──────────────┘ allowed │              │                                      │
│                    true   └──────────────┘                                      │
│                                                                                  │
│  4. PROCESS OR DENY                                                              │
│                                                                                  │
│       ┌──────────────────┐              ┌──────────────────┐                    │
│       │   If allowed:    │              │   If denied:     │                    │
│       │   Continue to    │              │   Return 403     │                    │
│       │   Backend Service│              │   Forbidden      │                    │
│       └──────────────────┘              └──────────────────┘                    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Default Accounts

| Role | Username | Password | Quyền hạn |
|------|----------|----------|-----------|
| System Admin | admin | admin123 | Full access |
| HR Staff | hr_user | hr123 | Employee + HR management |
| Manager | manager_user | manager123 | Team management + Approvals |
| Employee | employee_user | employee123 | Own data + Requests |

**Keycloak Admin Console:**

| Field | Value |
|-------|-------|
| URL | http://localhost:8080 |
| Username | admin |
| Password | admin |

**Infrastructure Credentials:**

| Service | Username | Password |
|---------|----------|----------|
| RabbitMQ | hrm_user | hrm_pass |
| MinIO | minio_user | minio_pass |

---

## Config Mount Pattern

Production config files được mount từ `config/generated/PRO/` vào containers:

```
config/generated/PRO/
├── employee-service/
│   └── appsettings.Production.json
├── time-service/
│   └── appsettings.Production.json
├── notification-service/
│   └── appsettings.Production.json
├── api-gateway/
│   └── appsettings.Production.json
└── socket-service/
    └── .env
```

**Cấu hình Docker Compose:**

```yaml
services:
  employee-service:
    volumes:
      - ./config/generated/PRO/employee-service/appsettings.Production.json:/app/appsettings.Production.json:ro
```

**Lợi ích:**
- ✅ Tách biệt config production khỏi source code
- ✅ Dễ thay đổi config mà không cần rebuild image
- ✅ Mount read-only (`:ro`) để bảo mật
- ✅ Secrets không nằm trong source control

---

## Volumes & Data Persistence

### Docker Volumes

| Volume | Service | Mục đích |
|--------|---------|----------|
| `postgres_employee_data` | postgres-employee | Employee database |
| `postgres_time_data` | postgres-time | Time database |
| `postgres_notification_data` | postgres-notification | Notification database |
| `postgres_keycloak_data` | postgres-keycloak | Keycloak database |
| `postgres_authz_data` | postgres-authz | Authorization database |
| `redis_data` | redis | Cache data |
| `rabbitmq_data` | rabbitmq | Message queue data |
| `minio_data` | minio | Object storage |

### Backup & Restore

```bash
# Backup database
docker exec hrm-postgres-employee pg_dump -U employee_user employee_db > employee_backup.sql

# Restore database
docker exec -i hrm-postgres-employee psql -U employee_user employee_db < employee_backup.sql

# Backup all volumes
docker run --rm -v hrm-deployment_postgres_employee_data:/data -v $(pwd):/backup alpine tar cvf /backup/postgres_employee.tar /data
```

---

## Các lệnh thường dùng

### Khởi động & Dừng

```bash
# Khởi động tất cả services
docker compose up -d

# Khởi động với rebuild
docker compose up -d --build

# Xem logs (follow mode)
docker compose logs -f

# Xem logs service cụ thể
docker compose logs -f api-gateway time-service

# Dừng tất cả
docker compose down

# Dừng và xóa data (reset hoàn toàn)
docker compose down -v
```

### Build & Rebuild

```bash
# Rebuild một service
docker compose build employee-service

# Rebuild và restart
docker compose up -d --build employee-service

# Rebuild tất cả (no cache)
docker compose build --no-cache
```

### Debug & Monitoring

```bash
# Xem trạng thái containers
docker compose ps

# Xem resource usage
docker stats

# Exec vào container
docker exec -it hrm-api-gateway /bin/bash

# Xem network
docker network inspect hrm-deployment_hrm-network
```

### Chỉ chạy Infrastructure

```bash
# Chỉ infrastructure (databases, redis, rabbitmq, keycloak)
docker compose up -d \
  postgres-employee postgres-time postgres-notification \
  postgres-keycloak postgres-authz \
  redis rabbitmq keycloak minio

# Đợi Keycloak healthy
watch docker compose ps keycloak
```

### Scale Services

```bash
# Scale time-service lên 3 instances (cần cấu hình load balancer)
docker compose up -d --scale time-service=3
```

---

## Troubleshooting

### Service không start được

```bash
# Kiểm tra logs
docker compose logs <service-name>

# Kiểm tra dependencies đã healthy chưa
docker compose ps

# Xem chi tiết container
docker inspect hrm-<service-name>
```

### Database connection failed

```bash
# Kiểm tra PostgreSQL đã ready chưa
docker compose ps postgres-employee

# Test connection
docker exec -it hrm-postgres-employee psql -U employee_user -d employee_db -c "SELECT 1"

# Xem logs database
docker compose logs postgres-employee
```

### Keycloak chưa ready

Keycloak cần **60-90 giây** để khởi động. Đợi đến khi status là `healthy`:

```bash
# Xem trạng thái
docker compose ps keycloak

# Xem logs chi tiết
docker compose logs -f keycloak

# Test health endpoint
curl http://localhost:8080/health/ready
```

### RabbitMQ connection issues

```bash
# Kiểm tra RabbitMQ
docker compose ps rabbitmq

# Xem management UI
# http://localhost:15672 (hrm_user/hrm_pass)

# Xem logs
docker compose logs rabbitmq
```

### gRPC connection failed

```bash
# Kiểm tra employee-service đang chạy
docker compose ps employee-service

# Test gRPC port
docker exec hrm-api-gateway curl -v telnet://employee-service:8081

# Xem logs
docker compose logs employee-service
```

### Reset toàn bộ

```bash
# Stop và xóa tất cả
docker compose down -v

# Xóa images (nếu cần)
docker compose down -v --rmi local

# Khởi động lại
docker compose up -d --build
```

### Out of Memory

```bash
# Tăng Docker memory limit
# Docker Desktop: Settings > Resources > Memory

# Kiểm tra memory usage
docker stats

# Giảm tải bằng cách chỉ chạy services cần thiết
docker compose up -d api-gateway employee-service postgres-employee keycloak
```

---

## Production Deployment

### Environment Variables

Copy và chỉnh sửa file `.env`:

```bash
cp .env.example .env
```

**Các biến quan trọng cần thay đổi:**

```env
# Database passwords (PHẢI ĐỔI!)
POSTGRES_EMPLOYEE_PASSWORD=<strong-password>
POSTGRES_TIME_PASSWORD=<strong-password>
POSTGRES_NOTIFICATION_PASSWORD=<strong-password>
POSTGRES_KEYCLOAK_PASSWORD=<strong-password>

# RabbitMQ (PHẢI ĐỔI!)
RABBITMQ_USER=<secure-user>
RABBITMQ_PASSWORD=<strong-password>

# MinIO (PHẢI ĐỔI!)
MINIO_USER=<secure-user>
MINIO_PASSWORD=<strong-password>

# Keycloak Admin (PHẢI ĐỔI!)
KEYCLOAK_ADMIN=<secure-admin>
KEYCLOAK_ADMIN_PASSWORD=<strong-password>
```

### Security Checklist

- [ ] Đổi tất cả default passwords
- [ ] Enable HTTPS với SSL certificates
- [ ] Configure Keycloak HTTPS
- [ ] Set `KC_HOSTNAME_STRICT=true`
- [ ] Remove Swagger UI trong production
- [ ] Configure proper CORS origins
- [ ] Enable rate limiting
- [ ] Setup monitoring (Prometheus/Grafana)
- [ ] Configure log aggregation (ELK/Loki)
- [ ] Backup strategy cho databases

### Docker Compose Override

Tạo `docker-compose.prod.yml` cho production:

```yaml
services:
  api-gateway:
    environment:
      ASPNETCORE_ENVIRONMENT: Production
      Cors__AllowedOrigins__0: "https://your-domain.com"

  keycloak:
    environment:
      KC_HOSTNAME_STRICT: "true"
      KC_HOSTNAME: "auth.your-domain.com"
```

Chạy với override:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## Related Repositories

| Repository | Description | Port(s) |
|------------|-------------|---------|
| [hrm-employee-service](../hrm-employee-service) | Employee management microservice (gRPC) | 5001, 5002 |
| [hrm-Time-Service](../hrm-Time-Service) | Time & Attendance microservice (gRPC) | 5003, 5004 |
| [hrm-Notification-Service](../hrm-Notification-Service) | Real-time notification (SignalR) | 5005 |
| [hrm-ApiGateway](../hrm-ApiGateway) | API Gateway (REST + GraphQL) | 5000 |
| [hrm-nextjs](../hrm-nextjs) | Frontend application (Next.js) | 3000 |

---

## License

MIT License

---

© 2025 HRM System (Học từ VMS Architecture)
