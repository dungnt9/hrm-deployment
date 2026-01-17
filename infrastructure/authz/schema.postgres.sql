-- =====================================================
-- HRM Authorization Schema
-- Khớp với nghiệp vụ HRM: Employee, Attendance, Leave, Overtime
-- =====================================================

CREATE SCHEMA IF NOT EXISTS authz;

-- =====================================================
-- ACTIONS - Các hành động có thể thực hiện
-- =====================================================
CREATE TABLE IF NOT EXISTS authz.authz_actions (
    id TEXT PRIMARY KEY,
    name TEXT,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO authz.authz_actions (id, name, description) VALUES
    ('read', 'Read', 'View/Read data'),
    ('write', 'Write', 'Create/Update data'),
    ('delete', 'Delete', 'Delete data'),
    ('approve', 'Approve', 'Approve requests'),
    ('reject', 'Reject', 'Reject requests'),
    ('export', 'Export', 'Export data to file'),
    ('manage', 'Manage', 'Full management access')
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- RESOURCES - Các tài nguyên/module trong HRM
-- =====================================================
CREATE TABLE IF NOT EXISTS authz.authz_resources (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    parent_id TEXT REFERENCES authz.authz_resources(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO authz.authz_resources (id, name, description) VALUES
    -- Employee Management
    ('employee', 'Employee', 'Employee management module'),
    ('department', 'Department', 'Department management'),
    ('team', 'Team', 'Team management'),
    ('company', 'Company', 'Company management'),

    -- Time Management
    ('attendance', 'Attendance', 'Attendance tracking - check-in/out'),
    ('leave', 'Leave', 'Leave request management'),
    ('overtime', 'Overtime', 'Overtime request management'),
    ('shift', 'Shift', 'Work shift management'),

    -- Notification
    ('notification', 'Notification', 'Notification management'),

    -- Reports & Settings
    ('report', 'Report', 'Reports and analytics'),
    ('settings', 'Settings', 'System settings')
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- POLICIES - Chính sách phân quyền
-- =====================================================
CREATE TABLE IF NOT EXISTS authz.authz_policies (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    effect TEXT NOT NULL DEFAULT 'allow' CHECK (effect IN ('allow', 'deny')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- POLICY_ACTIONS - Mapping policy với actions
-- =====================================================
CREATE TABLE IF NOT EXISTS authz.authz_policy_actions (
    policy_id TEXT REFERENCES authz.authz_policies(id) ON DELETE CASCADE,
    action_id TEXT REFERENCES authz.authz_actions(id) ON DELETE CASCADE,
    PRIMARY KEY (policy_id, action_id)
);

-- =====================================================
-- POLICY_RESOURCES - Mapping policy với resources
-- =====================================================
CREATE TABLE IF NOT EXISTS authz.authz_policy_resources (
    policy_id TEXT REFERENCES authz.authz_policies(id) ON DELETE CASCADE,
    resource_id TEXT REFERENCES authz.authz_resources(id) ON DELETE CASCADE,
    PRIMARY KEY (policy_id, resource_id)
);

-- =====================================================
-- ROLE_POLICIES - Mapping Keycloak roles với policies
-- =====================================================
CREATE TABLE IF NOT EXISTS authz.authz_role_policies (
    role_id TEXT NOT NULL,  -- Keycloak role name
    policy_id TEXT REFERENCES authz.authz_policies(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, policy_id)
);

-- =====================================================
-- DEFAULT POLICIES cho HRM
-- =====================================================

-- Policy: Employee - Basic Access (cho role: employee)
INSERT INTO authz.authz_policies (id, name, description) VALUES
    ('employee_basic', 'Employee Basic Access', 'Basic access for all employees - check-in/out, view own data, request leave/overtime')
ON CONFLICT (id) DO NOTHING;

INSERT INTO authz.authz_policy_resources (policy_id, resource_id) VALUES
    ('employee_basic', 'employee'),
    ('employee_basic', 'attendance'),
    ('employee_basic', 'leave'),
    ('employee_basic', 'overtime'),
    ('employee_basic', 'shift'),
    ('employee_basic', 'notification')
ON CONFLICT DO NOTHING;

INSERT INTO authz.authz_policy_actions (policy_id, action_id) VALUES
    ('employee_basic', 'read'),
    ('employee_basic', 'write')
ON CONFLICT DO NOTHING;

-- Policy: Manager Access (cho role: manager)
INSERT INTO authz.authz_policies (id, name, description) VALUES
    ('manager_access', 'Manager Access', 'Manager can view team, approve/reject leave and overtime requests')
ON CONFLICT (id) DO NOTHING;

INSERT INTO authz.authz_policy_resources (policy_id, resource_id) VALUES
    ('manager_access', 'employee'),
    ('manager_access', 'team'),
    ('manager_access', 'attendance'),
    ('manager_access', 'leave'),
    ('manager_access', 'overtime'),
    ('manager_access', 'report')
ON CONFLICT DO NOTHING;

INSERT INTO authz.authz_policy_actions (policy_id, action_id) VALUES
    ('manager_access', 'read'),
    ('manager_access', 'approve'),
    ('manager_access', 'reject')
ON CONFLICT DO NOTHING;

-- Policy: HR Staff Access (cho role: hr_staff)
INSERT INTO authz.authz_policies (id, name, description) VALUES
    ('hr_staff_access', 'HR Staff Access', 'HR can manage all employee data, final approve leave, export reports')
ON CONFLICT (id) DO NOTHING;

INSERT INTO authz.authz_policy_resources (policy_id, resource_id) VALUES
    ('hr_staff_access', 'employee'),
    ('hr_staff_access', 'department'),
    ('hr_staff_access', 'team'),
    ('hr_staff_access', 'attendance'),
    ('hr_staff_access', 'leave'),
    ('hr_staff_access', 'overtime'),
    ('hr_staff_access', 'shift'),
    ('hr_staff_access', 'notification'),
    ('hr_staff_access', 'report')
ON CONFLICT DO NOTHING;

INSERT INTO authz.authz_policy_actions (policy_id, action_id) VALUES
    ('hr_staff_access', 'read'),
    ('hr_staff_access', 'write'),
    ('hr_staff_access', 'delete'),
    ('hr_staff_access', 'approve'),
    ('hr_staff_access', 'reject'),
    ('hr_staff_access', 'export'),
    ('hr_staff_access', 'manage')
ON CONFLICT DO NOTHING;

-- Policy: Admin Full Access (cho role: system_admin)
INSERT INTO authz.authz_policies (id, name, description) VALUES
    ('admin_full_access', 'Admin Full Access', 'System admin has full access to all resources')
ON CONFLICT (id) DO NOTHING;

INSERT INTO authz.authz_policy_resources (policy_id, resource_id) VALUES
    ('admin_full_access', 'employee'),
    ('admin_full_access', 'department'),
    ('admin_full_access', 'team'),
    ('admin_full_access', 'company'),
    ('admin_full_access', 'attendance'),
    ('admin_full_access', 'leave'),
    ('admin_full_access', 'overtime'),
    ('admin_full_access', 'shift'),
    ('admin_full_access', 'notification'),
    ('admin_full_access', 'report'),
    ('admin_full_access', 'settings')
ON CONFLICT DO NOTHING;

INSERT INTO authz.authz_policy_actions (policy_id, action_id) VALUES
    ('admin_full_access', 'read'),
    ('admin_full_access', 'write'),
    ('admin_full_access', 'delete'),
    ('admin_full_access', 'approve'),
    ('admin_full_access', 'reject'),
    ('admin_full_access', 'export'),
    ('admin_full_access', 'manage')
ON CONFLICT DO NOTHING;

-- =====================================================
-- MAP ROLES TO POLICIES (Keycloak roles)
-- =====================================================
INSERT INTO authz.authz_role_policies (role_id, policy_id) VALUES
    ('employee', 'employee_basic'),
    ('manager', 'employee_basic'),
    ('manager', 'manager_access'),
    ('hr_staff', 'employee_basic'),
    ('hr_staff', 'hr_staff_access'),
    ('system_admin', 'admin_full_access')
ON CONFLICT DO NOTHING;

-- =====================================================
-- INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_authz_policy_actions_policy ON authz.authz_policy_actions(policy_id);
CREATE INDEX IF NOT EXISTS idx_authz_policy_resources_policy ON authz.authz_policy_resources(policy_id);
CREATE INDEX IF NOT EXISTS idx_authz_policy_resources_resource ON authz.authz_policy_resources(resource_id);
CREATE INDEX IF NOT EXISTS idx_authz_role_policies_role ON authz.authz_role_policies(role_id);

-- =====================================================
-- VIEW: Check permission (helper view)
-- =====================================================
CREATE OR REPLACE VIEW authz.v_role_permissions AS
SELECT
    rp.role_id,
    p.id as policy_id,
    p.name as policy_name,
    r.id as resource_id,
    r.name as resource_name,
    a.id as action_id,
    a.name as action_name,
    p.effect
FROM authz.authz_role_policies rp
JOIN authz.authz_policies p ON rp.policy_id = p.id
JOIN authz.authz_policy_resources pr ON p.id = pr.policy_id
JOIN authz.authz_resources r ON pr.resource_id = r.id
JOIN authz.authz_policy_actions pa ON p.id = pa.policy_id
JOIN authz.authz_actions a ON pa.action_id = a.id;

-- =====================================================
-- FUNCTION: Check if role has permission
-- =====================================================
CREATE OR REPLACE FUNCTION authz.check_permission(
    p_role TEXT,
    p_resource TEXT,
    p_action TEXT
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM authz.v_role_permissions
        WHERE role_id = p_role
        AND resource_id = p_resource
        AND action_id = p_action
        AND effect = 'allow'
    );
END;
$$ LANGUAGE plpgsql;
