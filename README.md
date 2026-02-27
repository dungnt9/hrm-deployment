# HRM - Human Resource Management System

Microservices-based human resource management system, supporting employee management, attendance, leave, overtime and real-time notifications.

---

## Table of Contents

- [Overall Architecture](#overall-architecture)
- [Tech Stack](#tech-stack)
- [Directory Structure](#directory-structure)
- [System Requirements](#system-requirements)
- [Installation Guide from Scratch](#installation-guide-from-scratch)
- [Starting the System](#starting-the-system)
- [Verify System is Working](#verify-system-is-working)
- [Port Reference](#port-reference)
- [Login Credentials](#login-credentials)
- [Service Details](#service-details)
  - [Frontend (Next.js)](#frontend-nextjs)
  - [API Gateway](#api-gateway)
  - [Employee Service](#employee-service)
  - [Time Service](#time-service)
  - [Notification Service](#notification-service)
  - [Socket Service](#socket-service)
  - [Keycloak (SSO)](#keycloak-sso)
  - [Authorization Service](#authorization-service)
- [Environment Configuration](#environment-configuration)
- [Docker Compose Commands](#docker-compose-commands)
- [Production Deployment](#production-deployment)
- [Important Notes](#important-notes)
- [Troubleshooting](#troubleshooting)
- [Stopping the System](#stopping-the-system)

---

## Overall Architecture

### Deployment Model: Hybrid

- **Infrastructure** (PostgreSQL, Redis, RabbitMQ, Keycloak, MinIO, Socket Service) runs in **Docker Compose**
- **Backend .NET services** (Employee, Time, Notification, API Gateway) run locally with **`dotnet run`**
- **Frontend** (Next.js) runs locally with **`npm run dev`**

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

| From                 | To                   | Protocol                 |
| -------------------- | -------------------- | ------------------------ |
| Frontend             | API Gateway          | REST, GraphQL, WebSocket |
| API Gateway          | Employee Service     | gRPC                     |
| API Gateway          | Time Service         | gRPC                     |
| API Gateway          | Notification Service | HTTP                     |
| API Gateway          | Keycloak             | HTTP (JWT validation)    |
| Time Service         | Employee Service     | gRPC (validate manager)  |
| Time Service         | RabbitMQ             | AMQP (Outbox pattern)    |
| Notification Service | RabbitMQ             | AMQP (consumer)          |
| Socket Service       | RabbitMQ             | AMQP (consumer)          |
| Frontend             | Socket Service       | WebSocket (Socket.IO)    |

---

## Tech Stack

### Backend (.NET 8)

| Technology                | Purpose                          |
| ------------------------- | -------------------------------- |
| ASP.NET Core 8.0          | Web framework                    |
| Entity Framework Core 8.0 | ORM                              |
| gRPC                      | Inter-service communication      |
| MediatR 12.x              | CQRS pattern                     |
| AutoMapper 13.x           | Object mapping                   |
| FluentValidation 11.x     | Input validation                 |
| HotChocolate 13.x         | GraphQL (API Gateway)            |
| SignalR 8.0               | WebSocket (Notification Service) |
| Hangfire                  | Background jobs (Time Service)   |
| Serilog                   | Structured logging               |

### Frontend

| Technology             | Purpose                 |
| ---------------------- | ----------------------- |
| Next.js 14.0.4         | React framework         |
| TypeScript 5           | Type safety             |
| MUI (Material UI) 5.15 | UI components           |
| Redux Toolkit 2.0      | State management        |
| Apollo Client 3.8      | GraphQL client          |
| keycloak-js 23.0       | SSO integration         |
| SignalR Client 8.0     | Real-time notifications |
| Recharts 2.10          | Charts                  |

### Infrastructure

| Technology          | Version             | Purpose                     |
| ------------------- | ------------------- | --------------------------- |
| PostgreSQL          | 16-alpine           | Database (5 instances)      |
| Redis               | 7-alpine            | Caching (attendance status) |
| RabbitMQ            | 3-management-alpine | Event messaging             |
| Keycloak            | 23.0                | SSO / OAuth2 / OIDC         |
| MinIO               | latest              | Object storage              |
| Socket.IO (Node.js) | -                   | Real-time WebSocket         |

---

## Directory Structure

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

All .NET services use **Clean Architecture 4-Layer**: API → Application → Domain → Infrastructure.

---

## System Requirements

| Software       | Version | Check Command      |
| -------------- | ------- | ------------------ |
| Docker Desktop | 4.x+    | `docker --version` |
| .NET SDK       | 8.0+    | `dotnet --version` |
| Node.js        | 18+     | `node --version`   |
| RAM            | 8GB+    | -                  |

**Required available ports:** `3000, 5000-5005, 5100, 5432-5436, 6379, 5672, 8080, 9000-9001, 15672`

---

## Installation Guide from Scratch

### Step 1: Clone repository

```bash
git clone <repository-url>
cd hrm
```

### Step 2: Load Docker Images (offline)

The project uses offline Docker images - no internet required.

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

**Verify images are loaded:**

```bash
docker images
```

Expected output:

```
REPOSITORY                      TAG
postgres                        16-alpine
redis                           7-alpine
rabbitmq                        3-management-alpine
quay.io/keycloak/keycloak       23.0
minio/minio                     latest
node                            20-alpine
```

### Step 3: Copy Environment Files

```bash
cd hrm-deployment

# Copy Docker Compose environment
cp env/docker-compose.env.txt .env

# Copy Socket Service environment (IMPORTANT!)
cp env/socket.env.txt config/generated/PRO/socket-service/.env
```

### Step 4: Configure Frontend

```bash
cd ../hrm-nextjs
cp .env.example .env.local
```

Verify `.env.local` content:

```env
NEXT_PUBLIC_API_URL=http://localhost:5000
NEXT_PUBLIC_KEYCLOAK_URL=http://localhost:8080
NEXT_PUBLIC_KEYCLOAK_REALM=hrm
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=hrm-frontend
NEXT_PUBLIC_NOTIFICATION_HUB_URL=http://localhost:5005/hubs/notification
```

### Step 5: Install Frontend Dependencies

```bash
cd hrm-nextjs
npm install
```

---

## Starting the System

### Step 1: Start Docker Infrastructure

```bash
cd hrm-deployment
docker compose up -d --build
```

**Wait for all containers to be healthy (approximately 60-90 seconds):**

```bash
docker compose ps
```

Expected output - all should be "Up" and most "healthy":

```
NAME                        STATUS
hrm-postgres-employee       Up (healthy)
hrm-postgres-time           Up (healthy)
hrm-postgres-notification   Up (healthy)
hrm-postgres-keycloak       Up (healthy)
hrm-postgres-authz          Up (healthy)
hrm-redis                   Up (healthy)
hrm-rabbitmq                Up (healthy)
hrm-keycloak                Up (healthy or unhealthy*)
hrm-minio                   Up (healthy)
hrm-socket                  Up (healthy or unhealthy*)
```

> **Note:** Keycloak and Socket may show "unhealthy" due to healthcheck configuration, but they still work normally. See [Important Notes](#important-notes).

### Step 2: Start Application Services

Open **5 separate terminals** and run sequentially:

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

> **Tip:** Use `dotnet watch run` instead of `dotnet run` for auto-reload when code changes.

---

## Verify System is Working

### Check Health Endpoints

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
# Expected: JSON with issuer, authorization_endpoint, etc.
```

### Access Web Interfaces

| Service                 | URL                            | Notes             |
| ----------------------- | ------------------------------ | ----------------- |
| **Frontend**            | http://localhost:3000          | Main application  |
| **Swagger API**         | http://localhost:5000/swagger  | API Documentation |
| **GraphQL Playground**  | http://localhost:5000/graphql  | GraphQL queries   |
| **Keycloak Admin**      | http://localhost:8080/admin    | SSO Management    |
| **RabbitMQ Management** | http://localhost:15672         | Message Queue     |
| **MinIO Console**       | http://localhost:9001          | Object Storage    |
| **Hangfire Dashboard**  | http://localhost:5003/hangfire | Background Jobs   |

---

## Port Reference

### Docker Infrastructure

| Service                    | Port  | Protocol  |
| -------------------------- | ----- | --------- |
| PostgreSQL Employee DB     | 5432  | TCP       |
| PostgreSQL Time DB         | 5433  | TCP       |
| PostgreSQL Notification DB | 5434  | TCP       |
| PostgreSQL Keycloak DB     | 5435  | TCP       |
| PostgreSQL Authz DB        | 5436  | TCP       |
| Redis                      | 6379  | TCP       |
| RabbitMQ Server            | 5672  | AMQP      |
| RabbitMQ Management UI     | 15672 | HTTP      |
| Keycloak SSO               | 8080  | HTTP      |
| MinIO API                  | 9000  | HTTP      |
| MinIO Console              | 9001  | HTTP      |
| Socket Service             | 5100  | WebSocket |

### Application Services (Local)

| Service              | HTTP Port | gRPC Port | Command       |
| -------------------- | --------- | --------- | ------------- |
| Employee Service     | 5001      | 5002      | `dotnet run`  |
| Time Service         | 5003      | 5004      | `dotnet run`  |
| Notification Service | 5005      | -         | `dotnet run`  |
| API Gateway          | 5000      | -         | `dotnet run`  |
| Frontend             | 3000      | -         | `npm run dev` |

---

## Login Credentials

### Application Users (Keycloak)

| Role     | Username      | Password    | Realm Roles            |
| -------- | ------------- | ----------- | ---------------------- |
| Admin    | admin         | admin123    | system_admin, employee |
| HR       | hr_user       | hr123       | hr_staff, employee     |
| Manager  | manager_user  | manager123  | manager, employee      |
| Employee | employee_user | employee123 | employee               |

### Infrastructure Services

| Service             | URL                         | Username   | Password   |
| ------------------- | --------------------------- | ---------- | ---------- |
| Keycloak Admin      | http://localhost:8080/admin | admin      | admin      |
| RabbitMQ Management | http://localhost:15672      | hrm_user   | hrm_pass   |
| MinIO Console       | http://localhost:9001       | minio_user | minio_pass |

### Databases

| Database        | Port | Username          | Password          | DB Name         |
| --------------- | ---- | ----------------- | ----------------- | --------------- |
| Employee DB     | 5432 | employee_user     | employee_pass     | employee_db     |
| Time DB         | 5433 | time_user         | time_pass         | time_db         |
| Notification DB | 5434 | notification_user | notification_pass | notification_db |
| Keycloak DB     | 5435 | keycloak_user     | keycloak_pass     | keycloak_db     |
| Authz DB        | 5436 | authz_user        | authz_pass        | authz_db        |

---

## Service Details

### Frontend (Next.js)

SPA dashboard for the entire HRM system. Uses Next.js 14 App Router.

**Main Features:**

- Dashboard role-aware: Attendance card, Leave Balance (progress bars), This Month stats; Manager/HR see Pending Approvals badge; HR/Admin see Company Overview; Quick Actions by role
- Employee Management (CRUD, search, filter, CSV export)
- Organization Chart (GraphQL, react-organizational-chart)
- Attendance (check-in/out with GPS, history, team attendance)
- Leave / Overtime (request submission, balance view, approval workflow)
- Approvals Hub (batch approval, audit trail)
- Real-time Notifications (SignalR WebSocket, badge count)
- Analytics & Reports (charts with Recharts, CSV export)
- Profile & Settings (3 tabs: personal info, documents, emergency contacts)
- **Payslip Preview** (auto-calculate: 22 standard days, attendance, OT x1.5, BHXH/BHYT/BHTN/tax deductions, Print/PDF)
- **Announcement Board** (filter by category, pin important, HR create/edit/delete, dashboard widget)

**Routes:**

| Route              | Role       | Description                                                    |
| ------------------ | ---------- | -------------------------------------------------------------- |
| `/`                | Public     | Login                                                          |
| `/dashboard`       | Employee   | Dashboard, check-in/out                                        |
| `/attendance`      | Employee   | Attendance history                                             |
| `/leave`           | Employee   | Leave requests, balance                                        |
| `/overtime`        | Employee   | Overtime requests                                              |
| `/shifts`          | Employee   | Work shifts                                                    |
| `/organization`    | Employee   | Organization chart                                             |
| `/notifications`   | Employee   | Notifications                                                  |
| `/profile`         | Employee   | Personal profile (3 tabs: info, documents, emergency contacts) |
| `/payroll`         | Employee   | **NEW** - Payslip (HR view all, employee view own)             |
| `/announcements`   | Employee   | **NEW** - Company announcements                                |
| `/employees`       | Manager/HR | Employee management                                            |
| `/departments`     | Manager/HR | Department management (CRUD)                                   |
| `/teams`           | Manager/HR | Team management                                                |
| `/team-attendance` | Manager/HR | Team attendance                                                |
| `/approvals`       | Manager/HR | Request approvals                                              |
| `/reports`         | Manager/HR | Reports, analytics                                             |

**Environment Variables (`.env.local`):**

```
NEXT_PUBLIC_API_URL=http://localhost:5000
NEXT_PUBLIC_KEYCLOAK_URL=http://localhost:8080
NEXT_PUBLIC_KEYCLOAK_REALM=hrm
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=hrm-frontend
NEXT_PUBLIC_NOTIFICATION_HUB_URL=http://localhost:5000/hubs/notification
```

**App structure:**

```
app/
├── page.tsx                    # Login
├── layout.tsx                  # Root layout + providers
├── (auth)/                     # Auth-protected routes
│   ├── dashboard/
│   ├── employees/
│   ├── departments/            # NEW - Department management
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
│   ├── layout/
│   │   ├── Layout.tsx          # Original layout
│   │   └── CollapsibleLayout.tsx # NEW - Enhanced with collapse
│   └── providers/
│       ├── AuthProvider.tsx     # Keycloak auth init
│       └── NotificationProvider.tsx  # SignalR setup
└── lib/
    ├── api.ts                  # REST API client (+ Department CRUD)
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

**NEW Components:**

- **CollapsibleLayout.tsx** - Sidebar with toggle collapse (260px ↔ 72px)
  - Smooth transitions & animations
  - Icon-only mode when collapsed
  - Tooltips on hover
  - Persist state in localStorage
  - Responsive mobile/desktop

- **departments/page.tsx** - Department Management
  - Full CRUD operations
  - Summary cards (metrics)
  - Data table with edit/delete
  - Modal forms with validation

**State Management (Redux Toolkit):**

- `authSlice` — `isAuthenticated`, `user`, `token` (auto-refresh every 4 minutes)
- `attendanceSlice` — `isCheckedIn`, `checkInTime`, `checkOutTime`, `currentHours`
- `notificationSlice` — `notifications[]`, `unreadCount`

**SignalR:** Auto-reconnect with exponential backoff (1s → 3s → 5s). JWT auth via Keycloak token.

---

### API Gateway

Entry point for all client requests. Aggregation layer between frontend and backend services.

**Main Functions:**

- Routing requests to microservices
- JWT Authentication (Keycloak)
- Role-based Authorization
- Data aggregation from multiple services (REST → gRPC translation)
- Swagger UI (`/swagger`), GraphQL Playground (`/graphql`)

**REST API Endpoints:**

| Group         | Prefix                       | Function                                      |
| ------------- | ---------------------------- | --------------------------------------------- |
| Auth          | `/api/auth`                  | Login, logout, refresh token, change password |
| Employees     | `/api/employees`             | Employee CRUD, get me, get manager            |
| Departments   | `/api/employees/departments` | Department CRUD (HRStaff+)                    |
| Teams         | `/api/employees/teams`       | Team CRUD (HRStaff+)                          |
| Attendance    | `/api/attendance`            | Check-in/out, history, team attendance        |
| Leave         | `/api/leave`                 | Create/approve/reject leave requests          |
| Overtime      | `/api/overtime`              | Create/approve/reject overtime requests       |
| Notifications | `/api/notifications`         | List, mark as read                            |

**GraphQL Queries:** `getOrgChart`, `getDepartments`, `getTeams`, `getTeamMembers`

**Authorization Policies:**

| Policy      | Role                                  | Description                  |
| ----------- | ------------------------------------- | ---------------------------- |
| Employee    | `employee`                            | Basic permissions            |
| Manager     | `manager`                             | Team management              |
| HRStaff     | `hr_staff`, `system_admin`            | HR operations (✅ Fixed)     |
| Admin       | `system_admin`                        | Full access                  |
| ManagerOrHR | `manager`, `hr_staff`, `system_admin` | Request approvals (✅ Fixed) |

> **✅ Updated:** Admin users can now access Manager/HR endpoints

---

### Employee Service

gRPC microservice managing employees, departments, teams, and company.

**Business Logic:**

- Employee CRUD (create: `hr_staff`, delete: `system_admin`)
- Department and team management (supports sub-departments)
- Organization chart (org chart)
- Assign Keycloak roles to employees
- Validate manager permissions (called by Time Service when approving requests)

**gRPC Methods (new):**

| Method                                                       | Description                       |
| ------------------------------------------------------------ | --------------------------------- |
| `GetDepartment` / `GetDepartments`                           | Get department by ID or all       |
| `CreateDepartment` / `UpdateDepartment` / `DeleteDepartment` | Department CRUD                   |
| `GetTeam` / `GetTeams`                                       | Get team by ID or by departmentId |
| `CreateTeam` / `UpdateTeam` / `DeleteTeam`                   | Team CRUD                         |
| `GetEmployeeByKeycloakId`                                    | Find employee by Keycloak userId  |

**Employee Status:** Active, OnLeave, Inactive, Probation, Terminated, Resigned

**Employment Type:** FullTime, PartTime, Contract, Temporary, Intern

**Database:** `employee_db` on `localhost:5432`

**Seed Data:** 7 departments, 14 teams, 30 sample employees.

---

### Time Service

gRPC microservice managing attendance, leave, overtime, and work shifts.

**Attendance Business Logic:**

- Check-in/out with GPS, IP, device info
- Automatic calculation: late arrival, early departure, OT, total hours
- Cache status on Redis (5 minutes)

**Leave Request Business Logic - 2-Level Approval Workflow:**

```
Employee (create request) → Manager (Level 1) → HR Staff (Level 2) → Approved/Rejected
```

> **✅ Improvement:** Leave Request API automatically fills `approverId` from employee's manager and defaults `approverType` = "manager" if not provided. Validation messages are improved when employee has no manager.

| Leave Type  | Default Days |
| ----------- | ------------ |
| Annual      | 12/year      |
| Sick        | 10/year      |
| Unpaid      | Unlimited    |
| Maternity   | 180 days     |
| Paternity   | 5 days       |
| Wedding     | 3 days       |
| Bereavement | 3 days       |

**Event-Driven (Outbox Pattern):** After each operation (check-in, request approval...), events are saved to `outbox_messages` table, background job (Hangfire) processes and publishes to RabbitMQ exchange `hrm.events`.

**Seed Data 2026 (applied to DB):**

| Table              | Data                                                     |
| ------------------ | -------------------------------------------------------- |
| `Shifts`           | Morning Shift (08-17), Standard Shift 2 (09-18)          |
| `LeaveBalances`    | 10 employees, year 2026                                  |
| `Attendances`      | 51 records Feb 2026 for 3 test users (emp 445, 446, 448) |
| `LeaveRequests`    | 4 pending (approverId = manager 446), 1 approved         |
| `OvertimeRequests` | 3 pending, 3 approved                                    |

**Database:** `time_db` on `localhost:5433` | **Redis:** `localhost:6379`

**Hangfire Dashboard:** http://localhost:5003/hangfire

---

### Notification Service

HTTP microservice managing real-time notifications via SignalR.

**Business Logic:**

- Receive events from RabbitMQ → save to DB → push via SignalR
- REST API: notification list, mark as read, preferences
- Notification templates (title/message templates with placeholders)
- User connection tracking (SignalR connection lifecycle)

**SignalR Hub:** `ws://localhost:5005/hubs/notification`

| Server → Client Event | Description            |
| --------------------- | ---------------------- |
| `ReceiveNotification` | New notification       |
| `NotificationRead`    | Mark as read confirmed |
| `UnreadCountUpdated`  | Update badge count     |

**Notification Types:** LeaveRequestCreated/Approved/Rejected, AttendanceReminder, OvertimeRequest\*, EmployeeOnboarding/Offboarding, BirthdayReminder, SystemAnnouncement...

**Database:** `notification_db` on `localhost:5434`

---

### Socket Service

Node.js WebSocket service using Socket.IO, running in Docker container.

**Functions:**

- Real-time event broadcasting from RabbitMQ to frontend
- Room-based messaging: `user:{userId}`, `employee:{employeeId}`, `role:{roleName}`, `team:{teamId}`
- JWT authentication via API Gateway (`/api/auth/me`)

**Events:**

| Category   | Events                                                                  |
| ---------- | ----------------------------------------------------------------------- |
| Attendance | `attendance_checked_in`, `attendance_checked_out`                       |
| Leave      | `leave_request_created/approved/rejected/cancelled`                     |
| Overtime   | `overtime_request_created/approved/rejected`                            |
| Team       | `team_member_checked_in`, `team_leave_request`, `team_overtime_request` |

**Frontend connection:**

```javascript
import { io } from "socket.io-client";
const socket = io("http://localhost:5100", {
  auth: { token: keycloakJWT },
  transports: ["websocket", "polling"],
});
```

**Endpoints:** `/` (Socket.IO), `/health`, `/stats`

**Config:** `config/generated/PRO/socket-service/.env`

| Variable                 | Default                             |
| ------------------------ | ----------------------------------- |
| SERVER_PORT              | 5001 (internal)                     |
| AUTH_API                 | http://api-gateway:8080/api/auth/me |
| RABBITMQ_HOST            | rabbitmq                            |
| RABBITMQ_PORT            | 5672                                |
| RABBITMQ_USER            | hrm_user                            |
| RABBITMQ_PASSWORD        | hrm_pass                            |
| RABBITMQ_WORK_QUEUE_NAME | hrm_socket_work_queue               |

---

### Keycloak (SSO)

OAuth 2.0 / OpenID Connect authentication for the entire system.

**Realm:** `hrm` (auto-import from `realm-export.json`)

**Realm Roles:**

| Role           | Description                                                          |
| -------------- | -------------------------------------------------------------------- |
| `employee`     | Basic permissions: check-in/out, view personal data, create requests |
| `manager`      | View team, approve Level 1 requests                                  |
| `hr_staff`     | Employee CRUD, final Level 2 approval, export reports                |
| `system_admin` | Full access                                                          |

**Clients:**

| Client ID      | Type         | Description      |
| -------------- | ------------ | ---------------- |
| `hrm-api`      | Confidential | Backend services |
| `hrm-frontend` | Public       | Next.js frontend |

**Client Roles (`hrm-api`):** `employee.read`, `employee.write`, `attendance.read/write`, `leave.read/write/approve`, `overtime.read/write/approve`, `report.read/export`, `admin`

**Custom Theme:** Custom login page (HRM branding, Vietnamese support), mounted via Docker volume `themes/hrm`.

**JWT Custom Claims:** `employee_id`, `roles`, `resource_access.hrm-api.roles`

**OIDC Discovery:** http://localhost:8080/realms/hrm/.well-known/openid-configuration

---

### Authorization Service

Policy-based Access Control supplementing Keycloak RBAC, using PostgreSQL functions.

**Database:** `authz_db` on `localhost:5436`, schema `authz`

**Check permission:**

```sql
SELECT authz.check_permission('manager', 'leave', 'approve');  -- true
SELECT authz.check_permission('employee', 'leave', 'approve'); -- false
```

**Resources:** employee, department, team, company, attendance, leave, overtime, shift, notification, report, settings

**Actions:** read, write, delete, approve, reject, export, manage

**Policies:**

| Policy              | Applied to Role                           |
| ------------------- | ----------------------------------------- |
| `employee_basic`    | employee (read/write on personal data)    |
| `manager_access`    | manager (read, approve, reject on team)   |
| `hr_staff_access`   | hr_staff (full CRUD, export, manage)      |
| `admin_full_access` | system_admin (ALL resources, ALL actions) |

Schema auto-initialized via `docker-entrypoint-initdb.d`.

---

## Environment Configuration

### Environment Files

```
hrm-deployment/
├── .env                              # Docker Compose env (copy from env/docker-compose.env.txt)
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

File `.env` is in `.gitignore`. File `.txt` template is committed.

### Service Config (default appsettings.json for local dev)

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
    "Host": "localhost",
    "Port": 5672,
    "Username": "hrm_user",
    "Password": "hrm_pass",
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
    "Host": "localhost",
    "Port": 5672,
    "Username": "hrm_user",
    "Password": "hrm_pass",
    "Exchange": "hrm.events",
    "Queue": "notification.queue"
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
  "Cors": {
    "AllowedOrigins": ["http://localhost:3000", "http://127.0.0.1:3000"]
  }
}
```

---

## Docker Compose Commands

```bash
cd hrm-deployment

# Start all infrastructure
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
docker compose logs -f keycloak       # Log for 1 service

# Restart 1 service
docker compose restart rabbitmq

# Stop all
docker compose down

# Reset everything (DELETE database data)
docker compose down -v && docker compose up -d
```

---

## Production Deployment

### AWS Mapping

| Local                | AWS                                   |
| -------------------- | ------------------------------------- |
| PostgreSQL           | RDS                                   |
| Redis                | ElastiCache                           |
| RabbitMQ             | Amazon MQ                             |
| MinIO                | S3                                    |
| Application Services | ECS Fargate / EKS                     |
| Secrets              | AWS Secrets Manager / Parameter Store |
| Load Balancing       | Application Load Balancer             |

### Docker Build (per service)

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

Production config is mounted read-only into containers:

```yaml
volumes:
  - ./config/generated/PRO/employee-service/appsettings.Production.json:/app/appsettings.Production.json:ro
```

Config changes only require container restart, no need to rebuild image.

---

## Important Notes

### 1. Database Migration for New Features

**IMPORTANT:** New features (Payslip, Profile 3-tabs, Announcements) require 3 new tables: `EmployeeDocuments`, `EmployeeContacts`, `Announcements`. The project uses `EnsureCreatedAsync()`, so when you **drop & recreate database** (`docker compose down -v && docker compose up -d`), tables will be auto-created. If you want to keep existing data, you need to add migrations manually.

### 2. Keycloak shows "unhealthy" but still works

Keycloak needs 60-90 seconds to fully start. Docker healthcheck may timeout before Keycloak is ready. Check in practice:

```bash
curl http://localhost:8080/realms/hrm/.well-known/openid-configuration
```

If it returns JSON -> Keycloak is working normally.

### 3. Socket Service config for Hybrid Deployment

File `config/generated/PRO/socket-service/.env` needs correct content from `env/socket.env.txt`:

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

> **If Socket Service cannot authenticate users:** Change `AUTH_API` to `http://host.docker.internal:5000/api/auth/me` so the Socket container can call API Gateway on the host machine.

### 4. Service startup order

**MUST** start in this order:

1. Docker Infrastructure (docker compose up)
2. Employee Service (other services depend on it)
3. Time Service
4. Notification Service
5. API Gateway
6. Frontend

### 5. appsettings.json must be in root directory

Each .NET service needs `appsettings.json` file at **the same level as `.csproj` file**, NOT in `src/API/`.

### 6. First time running Employee/Time/Notification Service

EF Core will automatically create database schema (migration). If you encounter database errors, check:

- Is PostgreSQL container healthy?
- Is connection string in appsettings.json correct?

### 7. CORS errors on Frontend

If you encounter CORS errors, check:

1. API Gateway is running: `curl http://localhost:5000/health`
2. File `hrm-ApiGateway/appsettings.json` has configuration:

```json
"Cors": {
  "AllowedOrigins": ["http://localhost:3000", "http://127.0.0.1:3000"]
}
```

---

## Troubleshooting

### Port already in use

**Windows:**

```powershell
# Find process using port
netstat -ano | findstr :5001

# Kill process
taskkill /PID <PID> /F
```

**Linux/Mac:**

```bash
lsof -i :5001
kill -9 <PID>
```

### Cannot connect to database

```bash
# Check container status
docker compose ps

# View logs
docker compose logs postgres-employee

# Restart specific container
docker compose restart postgres-employee
```

### Cannot connect to RabbitMQ

```bash
docker compose logs rabbitmq
# Wait for "Ready to accept connections"
# UI: http://localhost:15672 (hrm_user / hrm_pass)
```

### NuGet restore failed

```bash
cd <service-directory>
dotnet restore --no-cache
```

### Socket Service not receiving events

1. Check RabbitMQ connection: `docker compose logs socket-service`
2. Verify queue name `hrm_socket_work_queue` match between Time Service and Socket Service
3. Check if user has joined the correct room

### gRPC connection error

```bash
# Test Employee Service
grpcurl -plaintext localhost:5002 grpc.health.v1.Health/Check

# Test Time Service
grpcurl -plaintext localhost:5004 grpc.health.v1.Health/Check
```

### Reset entire system

```bash
# Stop and remove all containers + volumes
cd hrm-deployment
docker compose down -v

# Kill all .NET processes (Windows)
taskkill /IM dotnet.exe /F

# Kill all .NET processes (Linux/Mac)
pkill -f "dotnet run"

# Delete node_modules if needed
cd ../hrm-nextjs
rm -rf node_modules .next

# Restart from scratch
cd ../hrm-deployment
docker compose up -d --build
```

### View service logs

```bash
# Docker service logs
docker compose logs -f keycloak
docker compose logs -f socket-service

# .NET service logs - view directly in the running terminal
```

### Frontend 404 static files error

If you encounter errors:

```
GET http://localhost:3000/_next/static/css/app/layout.css net::ERR_ABORTED 404
GET http://localhost:3000/_next/static/chunks/main-app.js net::ERR_ABORTED 404
```

**Cause:** Old Node.js process is stuck, `.next` cache is out of sync.

**Fix:**

**Windows (PowerShell):**

```powershell
# Find and kill process occupying port 3000
netstat -ano | findstr :3000
taskkill /PID <PID> /F

# Or kill all node processes
taskkill /IM node.exe /F
```

**Windows (Git Bash):**

```bash
# Find PID
netstat -ano | findstr :3000

# Kill (replace <PID> with the found PID)
taskkill //PID <PID> //F
```

**Linux/Mac:**

```bash
# Kill process on port 3000
lsof -ti:3000 | xargs kill -9

# Or
pkill -f "next dev"
```

**Then restart frontend:**

```bash
cd hrm-nextjs
rm -rf .next
npm run dev
```

---

## Stopping the System

### Temporary stop (keep data)

```bash
# Stop Docker infrastructure
cd hrm-deployment
docker compose stop

# Stop .NET services: Ctrl+C in each terminal
```

### Stop and delete completely

```bash
# Delete containers AND volumes (LOSE DATA)
cd hrm-deployment
docker compose down -v

# Delete only containers (KEEP DATA)
docker compose down
```

---

## License

MIT
