#!/bin/bash

# HRM Microservices - Run All Services Script
# This script starts all .NET services and Frontend in separate terminals

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "============================================================"
echo "   HRM Microservices - Starting All Services"
echo "============================================================"
echo ""
echo "This script will open 5 new terminals for:"
echo "   1. Employee Service (http://localhost:5001)"
echo "   2. Time Service (http://localhost:5003)"
echo "   3. Notification Service (http://localhost:5005)"
echo "   4. API Gateway (http://localhost:5000)"
echo "   5. Frontend (http://localhost:3000)"
echo ""
echo "Docker infrastructure should already be running."
echo "Verify: cd hrm-deployment && docker compose ps"
echo ""
read -p "Press Enter to continue..."

# Function to run service in new terminal (macOS/Linux)
run_in_terminal() {
    local title="$1"
    local command="$2"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        osascript -e "tell app \"Terminal\" to do script \"$command\""
    else
        # Linux - using gnome-terminal or xterm
        if command -v gnome-terminal &> /dev/null; then
            gnome-terminal -- bash -c "$command; bash"
        elif command -v xterm &> /dev/null; then
            xterm -title "$title" -hold -e bash -c "$command"
        else
            echo "Please open a new terminal and run: $command"
        fi
    fi
}

# Terminal 1: Employee Service
echo "Starting Employee Service..."
run_in_terminal "Employee Service" "cd $PROJECT_ROOT/hrm-employee-service && dotnet restore && dotnet run"

sleep 2

# Terminal 2: Time Service
echo "Starting Time Service..."
run_in_terminal "Time Service" "cd $PROJECT_ROOT/hrm-Time-Service && dotnet restore && dotnet run"

sleep 2

# Terminal 3: Notification Service
echo "Starting Notification Service..."
run_in_terminal "Notification Service" "cd $PROJECT_ROOT/hrm-Notification-Service && dotnet restore && dotnet run"

sleep 2

# Terminal 4: API Gateway
echo "Starting API Gateway..."
run_in_terminal "API Gateway" "cd $PROJECT_ROOT/hrm-ApiGateway && dotnet restore && dotnet run"

sleep 2

# Terminal 5: Frontend
echo "Starting Frontend..."
run_in_terminal "Frontend" "cd $PROJECT_ROOT/hrm-nextjs && npm install && npm run dev"

echo ""
echo "============================================================"
echo "All services started in separate terminals!"
echo "============================================================"
echo ""
echo "Services should be available at:"
echo "   - Frontend: http://localhost:3000"
echo "   - API Gateway: http://localhost:5000"
echo "   - Keycloak: http://localhost:8080"
echo "   - RabbitMQ Management: http://localhost:15672"
echo "   - MinIO Console: http://localhost:9001"
echo ""
echo "Check the individual terminals for logs and errors."
echo "Press Ctrl+C in any terminal to stop that service."
echo ""
