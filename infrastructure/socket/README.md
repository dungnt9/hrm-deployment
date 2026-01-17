# HRM Socket Service

Real-time WebSocket service cho hệ thống HRM, sử dụng Socket.io và RabbitMQ.

## Overview

Socket Service cung cấp:
- **Real-time Communication** via Socket.io
- **Event Broadcasting** từ backend services
- **Room-based Messaging** (user, team, department, role)
- **JWT Authentication** với Keycloak
- **RabbitMQ Consumer** - Nhận events từ Time Service

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (Next.js)                        │
│                                                                 │
│  socket.io-client ──────WebSocket─────> Socket Service          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Socket Service (Node.js)                    │
│                                                                 │
│  ┌────────────────┐    ┌────────────────┐    ┌───────────────┐ │
│  │  Socket.io     │    │   RabbitMQ     │    │  JWT Auth     │ │
│  │  Server        │◄───│   Consumer     │    │  Middleware   │ │
│  └───────┬────────┘    └───────▲────────┘    └───────────────┘ │
│          │                     │                               │
│          │    Room Management  │                               │
│          │    - user:userId    │                               │
│          │    - team:teamId    │                               │
│          │    - role:roleName  │                               │
│          │                     │                               │
└──────────┼─────────────────────┼───────────────────────────────┘
           │                     │
           ▼                     │
      Frontend            ┌──────┴──────┐
                          │  RabbitMQ   │
                          │   Queue     │
                          └──────▲──────┘
                                 │
                          ┌──────┴──────┐
                          │Time Service │
                          │(publish)    │
                          └─────────────┘
```

## Quick Start

### Chạy cùng toàn bộ HRM

```bash
cd ../hrm-deployment
docker compose up -d
```

### Chạy riêng Socket Service

```bash
docker compose up -d
```

### Local Development

```bash
npm install
npm run dev
```

## Cấu trúc thư mục

```
infrastructure/socket/
├── docker-compose.yml    # Standalone config
├── Dockerfile            # Docker build
├── package.json          # Dependencies
├── index.js              # Main application
└── README.md
```

## HRM Events

### Event Types

```javascript
const HRM_EVENTS = {
    // Notification
    NOTIFICATION: 'notification',
    NOTIFICATION_READ: 'notification_read',

    // Attendance
    ATTENDANCE_CHECKED_IN: 'attendance_checked_in',
    ATTENDANCE_CHECKED_OUT: 'attendance_checked_out',
    ATTENDANCE_UPDATED: 'attendance_updated',

    // Leave
    LEAVE_REQUEST_CREATED: 'leave_request_created',
    LEAVE_REQUEST_APPROVED: 'leave_request_approved',
    LEAVE_REQUEST_REJECTED: 'leave_request_rejected',
    LEAVE_REQUEST_CANCELLED: 'leave_request_cancelled',

    // Overtime
    OVERTIME_REQUEST_CREATED: 'overtime_request_created',
    OVERTIME_REQUEST_APPROVED: 'overtime_request_approved',
    OVERTIME_REQUEST_REJECTED: 'overtime_request_rejected',

    // Team (for managers)
    TEAM_MEMBER_CHECKED_IN: 'team_member_checked_in',
    TEAM_LEAVE_REQUEST: 'team_leave_request',
    TEAM_OVERTIME_REQUEST: 'team_overtime_request'
};
```

### Event Message Format

```json
{
  "event": "leave_request_approved",
  "payload": {
    "requestId": "uuid",
    "employeeId": "EMP001",
    "employeeName": "Nguyen Van A",
    "approvedBy": "manager_user",
    "approvedAt": "2025-01-13T10:00:00Z",
    "leaveType": "annual",
    "fromDate": "2025-01-15",
    "toDate": "2025-01-16"
  },
  "userIds": ["user-keycloak-id"],
  "employeeIds": ["EMP001"],
  "teamId": null,
  "roles": null
}
```

### Target Specification

| Field | Description | Example |
|-------|-------------|---------|
| `userIds` | Keycloak user IDs | `["uuid-1", "uuid-2"]` |
| `employeeIds` | Employee codes | `["EMP001", "EMP002"]` |
| `teamId` | Team UUID | `"team-uuid"` |
| `roles` | Keycloak roles | `["manager", "hr_staff"]` |

Priority: `userIds` > `employeeIds` > `teamId` > `roles` > broadcast

## Room System

### Auto-joined Rooms

Khi user connect, tự động join:

| Room | Format | Description |
|------|--------|-------------|
| User Room | `user:{userId}` | Personal messages |
| Employee Room | `employee:{employeeId}` | By employee code |
| Role Rooms | `role:{roleName}` | By Keycloak role |

### Manual Room Join

```javascript
// Client-side
socket.emit('join_team', 'team-uuid');
socket.emit('join_department', 'dept-uuid');
socket.emit('join_room', 'custom-room');

// Leave room
socket.emit('leave_team', 'team-uuid');
socket.emit('leave_room', 'custom-room');
```

## Frontend Integration

### Connection

```javascript
import { io } from 'socket.io-client';

const socket = io('http://localhost:5100', {
    auth: {
        token: keycloakToken // JWT from Keycloak
    },
    transports: ['websocket', 'polling']
});

socket.on('connect', () => {
    console.log('Connected to HRM Socket');
});

socket.on('connected', (data) => {
    console.log('Welcome:', data.message);
});
```

### Listening Events

```javascript
// Attendance events
socket.on('attendance_checked_in', (data) => {
    console.log('Checked in:', data);
    // Update UI
});

// Leave events
socket.on('leave_request_approved', (data) => {
    showNotification(`Leave request approved by ${data.approvedBy}`);
});

// Team events (for managers)
socket.on('team_leave_request', (data) => {
    showNotification(`${data.employeeName} requested leave`);
});
```

### Join Team Room (Manager)

```javascript
// When manager views team dashboard
socket.emit('join_team', teamId);

// Listen for team events
socket.on('team_member_checked_in', (data) => {
    updateTeamDashboard(data);
});

// When leaving team view
socket.emit('leave_team', teamId);
```

## Backend Integration (Time Service)

### Publish Event

```csharp
// TimeService - sau khi approve leave
public async Task PublishLeaveApproved(LeaveRequest request)
{
    var message = new
    {
        @event = "leave_request_approved",
        payload = new
        {
            requestId = request.Id,
            employeeId = request.EmployeeId,
            employeeName = request.EmployeeName,
            approvedBy = _currentUser.Username,
            approvedAt = DateTime.UtcNow
        },
        employeeIds = new[] { request.EmployeeId }
    };

    await _rabbitMQ.PublishAsync("hrm_socket_work_queue", message);
}
```

### Event cho Manager

```csharp
// Notify manager khi có leave request mới
var message = new
{
    @event = "team_leave_request",
    payload = new { /* request details */ },
    teamId = employee.TeamId  // Send to team room
};
```

## Authentication

### JWT Validation

Socket Service validate JWT thông qua API Gateway:

```javascript
const response = await axios.get('http://api-gateway:8080/api/auth/me', {
    headers: { Authorization: `Bearer ${token}` }
});

// Returns user info
{
    id: "keycloak-user-id",
    employee_id: "EMP001",
    preferred_username: "admin",
    roles: ["employee", "system_admin"]
}
```

### Connection Rejected

```javascript
socket.on('connect_error', (error) => {
    if (error.message === 'Authentication required') {
        // Redirect to login
    }
    if (error.message === 'Authentication failed') {
        // Token expired, refresh
    }
});
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVER_PORT` | Listen port | 5001 |
| `AUTH_API` | API Gateway auth endpoint | http://api-gateway:8080/api/auth/me |
| `RABBITMQ_HOST` | RabbitMQ host | rabbitmq |
| `RABBITMQ_PORT` | RabbitMQ port | 5672 |
| `RABBITMQ_USER` | RabbitMQ user | hrm_user |
| `RABBITMQ_PASSWORD` | RabbitMQ pass | hrm_pass |
| `RABBITMQ_WORK_QUEUE_NAME` | Queue name | hrm_socket_work_queue |

## Ports

| Port | Description |
|------|-------------|
| 5001 (internal) | Socket.io server |
| 5100 (external) | Exposed to frontend |

## Endpoints

| Path | Description |
|------|-------------|
| `/` | Socket.io endpoint |
| `/health` | Health check |
| `/stats` | Connection statistics |

## Health Check

```bash
curl http://localhost:5100/health
```

Response:
```json
{
  "status": "healthy",
  "service": "hrm-socket",
  "connections": 5,
  "timestamp": "2025-01-13T10:00:00Z"
}
```

## Stats

```bash
curl http://localhost:5100/stats
```

Response:
```json
{
  "uniqueUsers": 5,
  "totalConnections": 8,
  "rooms": ["user:uuid-1", "team:team-1", "role:manager"]
}
```

## Troubleshooting

### Connection refused

1. Check Socket Service đang chạy: `docker compose ps`
2. Check port mapping: external 5100 → internal 5001
3. Check CORS settings

### Authentication failed

1. Verify Keycloak token còn valid
2. Check API Gateway đang chạy
3. Check AUTH_API environment variable

### Events không nhận được

1. Check RabbitMQ connection
2. Verify queue name match
3. Check user đã join đúng room

### RabbitMQ reconnecting

```bash
# Check RabbitMQ status
docker compose logs rabbitmq

# Check Socket Service logs
docker compose logs socket-service
```

---
© 2025 HRM System
