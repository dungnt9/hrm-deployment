/**
 * HRM Socket Service
 * Real-time WebSocket communication via Socket.io
 * Khớp với nghiệp vụ HRM: Notification, Attendance, Leave, Overtime
 */

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const amqp = require('amqplib/callback_api');
const axios = require('axios');
require('dotenv').config();

const app = express();
const server = http.createServer(app);

// CORS configuration - cho phép frontend kết nối
const io = new Server(server, {
    cors: {
        origin: [
            "http://localhost:3000",
            "http://127.0.0.1:3000",
            "*"
        ],
        methods: ["GET", "POST"],
        credentials: true
    },
    transports: ['websocket', 'polling']
});

// Configuration
const config = {
    port: process.env.SERVER_PORT || 5001,
    authApi: process.env.AUTH_API || 'http://localhost:5000/api/auth/me',
    rabbitmq: {
        host: process.env.RABBITMQ_HOST || 'localhost',
        port: process.env.RABBITMQ_PORT || 5672,
        user: process.env.RABBITMQ_USER || 'hrm_user',
        password: process.env.RABBITMQ_PASSWORD || 'hrm_pass',
        queueName: process.env.RABBITMQ_WORK_QUEUE_NAME || 'hrm_socket_work_queue'
    }
};

// User-Socket mapping: { odId: [socketId1, socketId2] }
const userSocketMap = {};

// HRM Event Types - khớp với nghiệp vụ
const HRM_EVENTS = {
    // Notification events
    NOTIFICATION: 'notification',
    NOTIFICATION_READ: 'notification_read',

    // Attendance events
    ATTENDANCE_CHECKED_IN: 'attendance_checked_in',
    ATTENDANCE_CHECKED_OUT: 'attendance_checked_out',
    ATTENDANCE_UPDATED: 'attendance_updated',

    // Leave events
    LEAVE_REQUEST_CREATED: 'leave_request_created',
    LEAVE_REQUEST_APPROVED: 'leave_request_approved',
    LEAVE_REQUEST_REJECTED: 'leave_request_rejected',
    LEAVE_REQUEST_CANCELLED: 'leave_request_cancelled',

    // Overtime events
    OVERTIME_REQUEST_CREATED: 'overtime_request_created',
    OVERTIME_REQUEST_APPROVED: 'overtime_request_approved',
    OVERTIME_REQUEST_REJECTED: 'overtime_request_rejected',

    // Team events (for managers)
    TEAM_MEMBER_CHECKED_IN: 'team_member_checked_in',
    TEAM_LEAVE_REQUEST: 'team_leave_request',
    TEAM_OVERTIME_REQUEST: 'team_overtime_request'
};

/**
 * Validate JWT token with API Gateway
 * Trả về user info nếu token hợp lệ
 */
async function validateToken(token) {
    try {
        const response = await axios.get(config.authApi, {
            headers: { Authorization: `Bearer ${token}` },
            timeout: 5000
        });

        if (response.data) {
            return {
                id: response.data.id || response.data.sub,
                employeeId: response.data.employee_id,
                username: response.data.preferred_username,
                roles: response.data.roles || []
            };
        }
        return null;
    } catch (error) {
        console.error('Token validation error:', error.message);
        return null;
    }
}

/**
 * Initialize RabbitMQ connection với retry logic
 */
function initRabbitMQ() {
    const amqpUrl = `amqp://${config.rabbitmq.user}:${config.rabbitmq.password}@${config.rabbitmq.host}:${config.rabbitmq.port}`;

    console.log(`Connecting to RabbitMQ at ${config.rabbitmq.host}:${config.rabbitmq.port}...`);

    amqp.connect(amqpUrl, (error, connection) => {
        if (error) {
            console.error('RabbitMQ connection error:', error.message);
            console.log('Retrying in 5 seconds...');
            setTimeout(initRabbitMQ, 5000);
            return;
        }

        console.log('✓ Connected to RabbitMQ');

        connection.createChannel((err, channel) => {
            if (err) {
                console.error('Channel creation error:', err.message);
                return;
            }

            const queue = config.rabbitmq.queueName;

            // Đảm bảo queue tồn tại
            channel.assertQueue(queue, { durable: true });
            channel.prefetch(1);

            console.log(`✓ Listening for messages on queue: ${queue}`);

            channel.consume(queue, (msg) => {
                if (msg !== null) {
                    try {
                        const data = JSON.parse(msg.content.toString());
                        console.log(`Received message: ${data.event}`);
                        handleMessage(data);
                        channel.ack(msg);
                    } catch (e) {
                        console.error('Message processing error:', e.message);
                        channel.ack(msg); // Ack anyway to avoid message stuck
                    }
                }
            }, { noAck: false });
        });

        connection.on('error', (err) => {
            console.error('RabbitMQ connection error:', err.message);
        });

        connection.on('close', () => {
            console.log('RabbitMQ connection closed, reconnecting...');
            setTimeout(initRabbitMQ, 5000);
        });
    });
}

/**
 * Handle incoming RabbitMQ message
 * Format message từ backend services:
 * {
 *   event: 'leave_request_approved',
 *   payload: { ... },
 *   userIds: ['user-id-1', 'user-id-2'],  // optional - null = broadcast
 *   employeeIds: ['EMP001', 'EMP002'],    // optional - by employee code
 *   teamId: 'team-uuid',                   // optional - send to team members
 *   roles: ['manager', 'hr_staff']         // optional - send to users with roles
 * }
 */
function handleMessage(data) {
    const { event, payload, userIds, employeeIds, teamId, roles } = data;

    console.log(`Processing event: ${event}`);

    // Priority: userIds > employeeIds > teamId > roles > broadcast

    if (userIds && userIds.length > 0) {
        // Send to specific users by Keycloak ID
        sendToUsers(userIds, event, payload);
    } else if (employeeIds && employeeIds.length > 0) {
        // Send to specific employees by employee ID
        // Note: Frontend cần map employeeId với socket connection
        sendToEmployees(employeeIds, event, payload);
    } else if (teamId) {
        // Send to team room
        io.to(`team:${teamId}`).emit(event, payload);
        console.log(`Sent to team room: team:${teamId}`);
    } else if (roles && roles.length > 0) {
        // Send to users with specific roles
        roles.forEach(role => {
            io.to(`role:${role}`).emit(event, payload);
        });
        console.log(`Sent to roles: ${roles.join(', ')}`);
    } else {
        // Broadcast to all
        io.emit(event, payload);
        console.log('Broadcasted to all users');
    }
}

/**
 * Send event to specific users by their IDs
 */
function sendToUsers(userIds, event, payload) {
    let sentCount = 0;
    userIds.forEach(userId => {
        const socketIds = userSocketMap[userId];
        if (socketIds && socketIds.length > 0) {
            socketIds.forEach(socketId => {
                io.to(socketId).emit(event, payload);
                sentCount++;
            });
        }
    });
    console.log(`Sent to ${sentCount} socket(s) for ${userIds.length} user(s)`);
}

/**
 * Send event to employees by employee ID
 */
function sendToEmployees(employeeIds, event, payload) {
    // Emit to employee-specific rooms
    employeeIds.forEach(empId => {
        io.to(`employee:${empId}`).emit(event, payload);
    });
    console.log(`Sent to employees: ${employeeIds.join(', ')}`);
}

// Socket.io authentication middleware
io.use(async (socket, next) => {
    const token = socket.handshake.auth.token || socket.handshake.query.token;

    if (!token) {
        console.log('Connection rejected: No token provided');
        return next(new Error('Authentication required'));
    }

    const user = await validateToken(token);

    if (user) {
        socket.user = user;
        return next();
    }

    console.log('Connection rejected: Invalid token');
    return next(new Error('Authentication failed'));
});

// Socket.io connection handler
io.on('connection', (socket) => {
    const user = socket.user;
    const userId = user.id;

    console.log(`✓ User connected: ${user.username} (${userId}), socket: ${socket.id}`);

    // Add socket to user mapping
    if (!userSocketMap[userId]) {
        userSocketMap[userId] = [];
    }
    userSocketMap[userId].push(socket.id);

    // Join user-specific room
    socket.join(`user:${userId}`);

    // Join employee room if has employee ID
    if (user.employeeId) {
        socket.join(`employee:${user.employeeId}`);
        console.log(`  Joined employee room: employee:${user.employeeId}`);
    }

    // Join role-based rooms
    if (user.roles && user.roles.length > 0) {
        user.roles.forEach(role => {
            socket.join(`role:${role}`);
        });
        console.log(`  Joined role rooms: ${user.roles.join(', ')}`);
    }

    // Send connection success event
    socket.emit('connected', {
        message: 'Connected to HRM Socket Service',
        userId: userId,
        timestamp: new Date().toISOString()
    });

    // Handle join team room (for managers)
    socket.on('join_team', (teamId) => {
        socket.join(`team:${teamId}`);
        console.log(`User ${user.username} joined team room: team:${teamId}`);
    });

    // Handle leave team room
    socket.on('leave_team', (teamId) => {
        socket.leave(`team:${teamId}`);
        console.log(`User ${user.username} left team room: team:${teamId}`);
    });

    // Handle join department room
    socket.on('join_department', (deptId) => {
        socket.join(`department:${deptId}`);
        console.log(`User ${user.username} joined department room: department:${deptId}`);
    });

    // Handle custom room join (generic)
    socket.on('join_room', (room) => {
        socket.join(room);
        console.log(`User ${user.username} joined room: ${room}`);
    });

    socket.on('leave_room', (room) => {
        socket.leave(room);
        console.log(`User ${user.username} left room: ${room}`);
    });

    // Handle disconnection
    socket.on('disconnect', (reason) => {
        console.log(`✗ User disconnected: ${user.username}, reason: ${reason}`);

        // Remove socket from user mapping
        if (userSocketMap[userId]) {
            userSocketMap[userId] = userSocketMap[userId].filter(id => id !== socket.id);
            if (userSocketMap[userId].length === 0) {
                delete userSocketMap[userId];
            }
        }
    });

    // Handle errors
    socket.on('error', (error) => {
        console.error(`Socket error for user ${user.username}:`, error.message);
    });
});

// Express endpoints
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        service: 'hrm-socket',
        connections: Object.keys(userSocketMap).length,
        timestamp: new Date().toISOString()
    });
});

// Stats endpoint
app.get('/stats', (req, res) => {
    const totalConnections = Object.values(userSocketMap).reduce((sum, arr) => sum + arr.length, 0);
    res.json({
        uniqueUsers: Object.keys(userSocketMap).length,
        totalConnections: totalConnections,
        rooms: Array.from(io.sockets.adapter.rooms.keys()).filter(r => !r.includes('-')).slice(0, 20)
    });
});

// Start server
server.listen(config.port, '0.0.0.0', () => {
    console.log('');
    console.log('========================================');
    console.log('  HRM Socket Service');
    console.log('========================================');
    console.log(`  Port: ${config.port}`);
    console.log(`  Auth API: ${config.authApi}`);
    console.log(`  RabbitMQ: ${config.rabbitmq.host}:${config.rabbitmq.port}`);
    console.log(`  Queue: ${config.rabbitmq.queueName}`);
    console.log('========================================');
    console.log('');

    // Connect to RabbitMQ after server starts
    initRabbitMQ();
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down...');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down...');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});
