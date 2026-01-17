# HRM Authz (Authorization Service)

Authorization service cho hệ thống HRM, cung cấp Policy-based Access Control bổ sung cho Keycloak RBAC.

## Overview

Authz service cung cấp:
- **Policy-based Access Control** - Kiểm tra quyền chi tiết
- **Resource Management** - Định nghĩa resources/actions
- **Role-Policy Mapping** - Ánh xạ Keycloak roles với policies
- **Audit Logging** - Ghi log authorization decisions

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                    API Gateway                          │
│                                                        │
│  1. JWT Token từ Keycloak (có roles)                   │
│  2. Gọi Authz để check permission chi tiết             │
│                                                        │
└───────────────────────┬────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────┐
│                  Authz Service                          │
│                                                        │
│  check_permission(role, resource, action)              │
│                                                        │
│  Example:                                              │
│  - check_permission('manager', 'leave', 'approve')    │
│  - check_permission('employee', 'attendance', 'write')│
│                                                        │
└───────────────────────┬────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────┐
│              PostgreSQL (authz_db)                      │
│                                                        │
│  Tables: authz_actions, authz_resources,               │
│          authz_policies, authz_role_policies           │
│                                                        │
└────────────────────────────────────────────────────────┘
```

## Quick Start

### Chạy cùng toàn bộ HRM

```bash
cd ../hrm-deployment
docker compose up -d
```

Database schema tự động init qua `docker-entrypoint-initdb.d`.

## Schema

### Tables

#### `authz.authz_actions` - Các hành động

| id | name | description |
|----|------|-------------|
| read | Read | View/Read data |
| write | Write | Create/Update data |
| delete | Delete | Delete data |
| approve | Approve | Approve requests |
| reject | Reject | Reject requests |
| export | Export | Export data to file |
| manage | Manage | Full management access |

#### `authz.authz_resources` - Các tài nguyên

| id | name | description |
|----|------|-------------|
| employee | Employee | Employee management |
| department | Department | Department management |
| team | Team | Team management |
| company | Company | Company management |
| attendance | Attendance | Check-in/out tracking |
| leave | Leave | Leave request management |
| overtime | Overtime | Overtime request management |
| shift | Shift | Work shift management |
| notification | Notification | Notification management |
| report | Report | Reports and analytics |
| settings | Settings | System settings |

#### `authz.authz_policies` - Các chính sách

| id | name | effect |
|----|------|--------|
| employee_basic | Employee Basic Access | allow |
| manager_access | Manager Access | allow |
| hr_staff_access | HR Staff Access | allow |
| admin_full_access | Admin Full Access | allow |

#### `authz.authz_role_policies` - Ánh xạ Role → Policy

| role_id | policy_id |
|---------|-----------|
| employee | employee_basic |
| manager | employee_basic, manager_access |
| hr_staff | employee_basic, hr_staff_access |
| system_admin | admin_full_access |

## Policies Chi Tiết

### Employee Basic (`employee_basic`)

```
Resources: employee, attendance, leave, overtime, shift, notification
Actions: read, write
```

Nhân viên có thể:
- Xem thông tin cá nhân
- Check-in/out
- Tạo đơn nghỉ phép/tăng ca
- Xem thông báo

### Manager Access (`manager_access`)

```
Resources: employee, team, attendance, leave, overtime, report
Actions: read, approve, reject
```

Manager có thể:
- Xem thông tin team members
- Duyệt/từ chối đơn nghỉ phép (Level 1)
- Duyệt/từ chối đơn tăng ca
- Xem báo cáo team

### HR Staff Access (`hr_staff_access`)

```
Resources: employee, department, team, attendance, leave, overtime,
           shift, notification, report
Actions: read, write, delete, approve, reject, export, manage
```

HR Staff có thể:
- Quản lý nhân viên (CRUD)
- Quản lý phòng ban, team
- Duyệt cuối (Level 2) đơn nghỉ phép
- Export báo cáo
- Cấu hình ca làm việc

### Admin Full Access (`admin_full_access`)

```
Resources: ALL
Actions: ALL
```

System Admin có full access.

## Check Permission Function

### SQL Function

```sql
SELECT authz.check_permission('manager', 'leave', 'approve');
-- Returns: true

SELECT authz.check_permission('employee', 'leave', 'approve');
-- Returns: false
```

### View: `v_role_permissions`

```sql
SELECT * FROM authz.v_role_permissions
WHERE role_id = 'manager';
```

## Integration

### API Gateway (.NET)

```csharp
// Sử dụng raw SQL hoặc Dapper
public async Task<bool> CheckPermission(string role, string resource, string action)
{
    using var connection = new NpgsqlConnection(_connectionString);
    return await connection.QuerySingleAsync<bool>(
        "SELECT authz.check_permission(@role, @resource, @action)",
        new { role, resource, action }
    );
}

// Trong Controller
[HttpPost("leaves/{id}/approve")]
public async Task<IActionResult> ApproveLeave(Guid id)
{
    var userRole = User.GetRole(); // từ JWT

    if (!await _authzService.CheckPermission(userRole, "leave", "approve"))
    {
        return Forbid();
    }

    // Process approval...
}
```

### Middleware Authorization

```csharp
// Custom Authorization Handler
public class AuthzHandler : AuthorizationHandler<AuthzRequirement>
{
    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        AuthzRequirement requirement)
    {
        var role = context.User.GetRole();

        if (await _authzService.CheckPermission(
            role,
            requirement.Resource,
            requirement.Action))
        {
            context.Succeed(requirement);
        }
    }
}

// Sử dụng
[Authorize(Policy = "CanApproveLeave")]
public async Task<IActionResult> ApproveLeave(Guid id)
```

## Database

```
Host: postgres-authz
Port: 5432 (external: 5436)
Database: authz_db
Username: authz_user
Password: authz_pass
Schema: authz
```

## Thêm Permission Mới

### 1. Thêm Action mới

```sql
INSERT INTO authz.authz_actions (id, name, description)
VALUES ('review', 'Review', 'Review and comment');
```

### 2. Thêm Resource mới

```sql
INSERT INTO authz.authz_resources (id, name, description)
VALUES ('document', 'Document', 'Document management');
```

### 3. Thêm Policy mới

```sql
-- Create policy
INSERT INTO authz.authz_policies (id, name, description)
VALUES ('document_reviewer', 'Document Reviewer', 'Can review documents');

-- Add resources
INSERT INTO authz.authz_policy_resources (policy_id, resource_id)
VALUES ('document_reviewer', 'document');

-- Add actions
INSERT INTO authz.authz_policy_actions (policy_id, action_id)
VALUES ('document_reviewer', 'read'),
       ('document_reviewer', 'review');

-- Map to role
INSERT INTO authz.authz_role_policies (role_id, policy_id)
VALUES ('manager', 'document_reviewer');
```

## Troubleshooting

### Check permission không hoạt động

```sql
-- Verify role có policy
SELECT * FROM authz.authz_role_policies WHERE role_id = 'manager';

-- Verify policy có resource
SELECT * FROM authz.authz_policy_resources WHERE policy_id = 'manager_access';

-- Verify policy có action
SELECT * FROM authz.authz_policy_actions WHERE policy_id = 'manager_access';
```

### Reset schema

```bash
docker compose down -v
docker compose up -d
```

---
© 2025 HRM System
