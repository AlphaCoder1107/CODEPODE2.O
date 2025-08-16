@echo off
echo ========================================
echo   Test Railway Server Connection
echo ========================================

set /p RAILWAY_URL="Enter your Railway server URL: "

if "%RAILWAY_URL%"=="" (
    echo ERROR: Railway URL is required
    pause
    exit /b 1
)

echo.
echo Testing server connection...
curl -s "%RAILWAY_URL%/api/config" > test-response.json

if %errorlevel% equ 0 (
    echo ✓ Server is responding
    echo.
    echo Response:
    type test-response.json
    echo.
) else (
    echo ✗ Server connection failed
    echo.
    echo Please check:
    echo 1. Railway server is deployed and running
    echo 2. URL is correct (include https://)
    echo 3. Server has CORS configured
    echo.
)

del test-response.json 2>nul

echo.
echo Testing create-order endpoint...
curl -s -X POST "%RAILWAY_URL%/api/create-order" -H "Content-Type: application/json" -d "{\"amount\":10000,\"customer\":{\"name\":\"Test\",\"email\":\"test@gmail.com\",\"phone\":\"9876543210\"},\"description\":\"Test order\"}" > order-response.json

if %errorlevel% equ 0 (
    echo ✓ Create order endpoint is working
    echo.
    echo Response:
    type order-response.json
    echo.
) else (
    echo ✗ Create order endpoint failed
    echo.
)

del order-response.json 2>nul

echo.
echo ========================================
echo   Test Complete
echo ========================================
echo.
echo If both tests passed, your Railway server is ready!
echo You can now proceed with AWS deployment.
echo.
pause