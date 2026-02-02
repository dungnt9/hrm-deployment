@echo off
REM HRM Microservices - Run All Services Script
REM This script opens 5 terminals and starts each .NET service + Frontend

cd /d "%~dp0\.."

echo.
echo ============================================================
echo   HRM Microservices - Starting All Services
echo ============================================================
echo.
echo This script will open 5 new terminals for:
echo   1. Employee Service (http://localhost:5001)
echo   2. Time Service (http://localhost:5003)
echo   3. Notification Service (http://localhost:5005)
echo   4. API Gateway (http://localhost:5000)
echo   5. Frontend (http://localhost:3000)
echo.
echo Docker infrastructure should already be running.
echo Verify: docker compose ps -a (from hrm-deployment folder)
echo.
pause

REM Terminal 1: Employee Service
start cmd /k "cd /d "%~dp0\..\hrm-employee-service" && title Employee Service && dotnet restore && dotnet run"

REM Terminal 2: Time Service
timeout /t 2 /nobreak
start cmd /k "cd /d "%~dp0\..\hrm-Time-Service" && title Time Service && dotnet restore && dotnet run"

REM Terminal 3: Notification Service
timeout /t 2 /nobreak
start cmd /k "cd /d "%~dp0\..\hrm-Notification-Service" && title Notification Service && dotnet restore && dotnet run"

REM Terminal 4: API Gateway
timeout /t 2 /nobreak
start cmd /k "cd /d "%~dp0\..\hrm-ApiGateway" && title API Gateway && dotnet restore && dotnet run"

REM Terminal 5: Frontend
timeout /t 2 /nobreak
start cmd /k "cd /d "%~dp0\..\hrm-nextjs" && title Frontend (Next.js) && npm install && npm run dev"

echo.
echo ============================================================
echo All services started in separate terminals!
echo ============================================================
echo.
echo Services should be available at:
echo   - Frontend: http://localhost:3000
echo   - API Gateway: http://localhost:5000
echo   - Keycloak: http://localhost:8080
echo   - RabbitMQ Management: http://localhost:15672
echo   - MinIO Console: http://localhost:9001
echo.
echo Check the individual terminals for logs and errors.
echo Press Ctrl+C in any terminal to stop that service.
echo.
pause
