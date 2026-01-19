-- =====================================================
-- HRM Database Initialization
-- Creates all databases for microservices
-- =====================================================

-- Employee Service Database
CREATE DATABASE employee_db;

-- Time Service Database
CREATE DATABASE time_db;

-- Notification Service Database
CREATE DATABASE notification_db;

-- Keycloak Database
CREATE DATABASE keycloak_db;

-- Grant permissions (using postgres user for simplicity in local dev)
-- In production, create separate users for each database
