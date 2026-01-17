# HRM Keycloak (SSO)

Keycloak Single Sign-On (SSO) configuration cho hệ thống HRM, cung cấp OAuth 2.0 / OpenID Connect authentication.

## Overview

Keycloak là Identity and Access Management solution, cung cấp:
- **OAuth 2.0 / OpenID Connect** authentication
- **Single Sign-On (SSO)** cho tất cả services
- **Role-Based Access Control (RBAC)**
- **User Federation** (LDAP, Active Directory)
- **Social Login** (Google, Facebook, etc.)

## Quick Start

### Chạy cùng toàn bộ HRM

```bash
cd ../hrm-deployment
docker compose up -d
```

### Chạy riêng Keycloak

```bash
docker compose up -d
```

## Cấu trúc thư mục

```
infrastructure/keycloak/
├── docker-compose.yml       # Standalone Keycloak + PostgreSQL
├── Dockerfile               # Custom Keycloak build
├── realm-export.json        # HRM realm configuration
├── themes/                  # Custom themes
│   └── hrm/
│       └── login/
│           ├── theme.properties
│           ├── resources/
│           │   └── css/
│           │       └── login.css
│           └── messages/
│               ├── messages_en.properties
│               └── messages_vi.properties
└── README.md
```

## Realm Configuration

### Realm: `hrm`

File `realm-export.json` định nghĩa:

#### Realm Roles

| Role | Description |
|------|-------------|
| `employee` | Basic employee - check-in/out, view own data, request leave |
| `manager` | Manager - view team, approve leave for team members |
| `hr_staff` | HR Staff - manage employees, final approve leave |
| `system_admin` | System Administrator - full access |

#### Client Roles (hrm-api)

| Role | Description |
|------|-------------|
| `employee.read` | Read employee data |
| `employee.write` | Create/Update employee |
| `attendance.read` | Read attendance |
| `attendance.write` | Check-in/out |
| `leave.read` | Read leave requests |
| `leave.write` | Create leave requests |
| `leave.approve` | Approve/Reject leave |
| `overtime.read` | Read overtime |
| `overtime.write` | Create overtime |
| `overtime.approve` | Approve overtime |
| `report.read` | Read reports |
| `report.export` | Export reports |
| `admin` | Full admin access |

#### Clients

| Client ID | Type | Description |
|-----------|------|-------------|
| `hrm-api` | Confidential | Backend API services |
| `hrm-frontend` | Public | Next.js frontend application |

#### Test Users

| Username | Password | Roles |
|----------|----------|-------|
| admin | admin123 | system_admin, employee |
| hr_user | hr123 | hr_staff, employee |
| manager_user | manager123 | manager, employee |
| employee_user | employee123 | employee |

## JWT Token Claims

### Access Token chứa:

```json
{
  "sub": "user-uuid",
  "preferred_username": "admin",
  "email": "admin@hrm.local",
  "given_name": "System",
  "family_name": "Admin",
  "employee_id": "EMP001",
  "roles": ["employee", "system_admin"],
  "resource_access": {
    "hrm-api": {
      "roles": ["admin"]
    }
  }
}
```

### Custom Claims

| Claim | Source | Description |
|-------|--------|-------------|
| `employee_id` | User attribute | Mã nhân viên (EMP001, EMP002, ...) |
| `roles` | Realm roles | Realm-level roles |
| `resource_access.hrm-api.roles` | Client roles | API-specific roles |

## Custom Theme

### Login Theme: `hrm`

Custom login page với:
- HRM branding
- Vietnamese language support
- Custom CSS styling

### Sử dụng theme

Theme được mount tự động qua Docker volume:

```yaml
volumes:
  - ./themes/hrm:/opt/keycloak/themes/hrm:ro
```

### Customize CSS

Edit file `themes/hrm/login/resources/css/login.css`:

```css
/* HRM Primary Color */
:root {
    --hrm-primary: #1976d2;
}

.login-pf-page .card-pf {
    border-top: 4px solid var(--hrm-primary);
}
```

### Thêm ngôn ngữ

Thêm file `messages_[locale].properties` trong `themes/hrm/login/messages/`:

```properties
# messages_vi.properties
loginTitle=Đăng nhập HRM
usernameOrEmail=Tên đăng nhập
password=Mật khẩu
doLogIn=Đăng nhập
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `KC_DB` | Database type | postgres |
| `KC_DB_URL` | JDBC URL | jdbc:postgresql://... |
| `KC_DB_USERNAME` | DB username | keycloak_user |
| `KC_DB_PASSWORD` | DB password | keycloak_pass |
| `KEYCLOAK_ADMIN` | Admin username | admin |
| `KEYCLOAK_ADMIN_PASSWORD` | Admin password | admin |
| `KC_HOSTNAME_STRICT` | Strict hostname | false |
| `KC_HTTP_ENABLED` | Enable HTTP | true |

## Ports

| Port | Description |
|------|-------------|
| 8080 | Keycloak HTTP |

## URLs

| Path | Description |
|------|-------------|
| `/` | Keycloak Home |
| `/admin` | Admin Console |
| `/realms/hrm` | HRM Realm |
| `/realms/hrm/.well-known/openid-configuration` | OIDC Discovery |

## Admin Console

```
URL: http://localhost:8080/admin
Username: admin
Password: admin
```

## Integration với Services

### Backend Services (.NET)

```csharp
// appsettings.json
{
  "Keycloak": {
    "Authority": "http://keycloak:8080/realms/hrm",
    "Audience": "hrm-api",
    "ClientId": "hrm-api",
    "ClientSecret": "hrm-api-secret"
  }
}

// Program.cs
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = config["Keycloak:Authority"];
        options.Audience = config["Keycloak:Audience"];
    });
```

### Frontend (Next.js)

```javascript
// Using keycloak-js
import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
    url: 'http://localhost:8080',
    realm: 'hrm',
    clientId: 'hrm-frontend'
});

await keycloak.init({ onLoad: 'login-required' });
```

### Socket Service (Node.js)

```javascript
// Validate token with API Gateway
const response = await axios.get('http://api-gateway:8080/api/auth/me', {
    headers: { Authorization: `Bearer ${token}` }
});
```

## Troubleshooting

### Keycloak không start

```bash
# Check logs
docker compose logs keycloak

# Check database
docker compose logs postgres-keycloak
```

### Import realm failed

```bash
# Restart với realm import
docker compose down
docker compose up -d
```

### Token validation failed

1. Check Keycloak Authority URL trong service config
2. Check Audience khớp với client
3. Verify token chưa expired

---
© 2025 HRM System
