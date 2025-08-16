@echo off
echo ========================================
echo   Update Frontend Configuration
echo ========================================

set /p RAILWAY_URL="Enter your Railway server URL (e.g., https://your-app.railway.app): "

if "%RAILWAY_URL%"=="" (
    echo ERROR: Railway URL is required
    pause
    exit /b 1
)

echo.
echo Updating cart.js configuration...

REM Create backup
copy "assets\js\cart.js" "assets\js\cart.js.backup"

REM Update the API_BASE configuration
powershell -Command "$content = Get-Content 'assets\js\cart.js' -Raw; $content = $content -replace 'const API_BASE = explicitBase \|\| \(IS_LOCALHOST \? ''http://'' : ''''\);', 'const API_BASE = explicitBase || ''%RAILWAY_URL%'';'; Set-Content 'assets\js\cart.js' -Value $content"

echo.
echo Updating index.html configuration...

REM Create backup
copy "index.html" "index.html.backup"

REM Update the CART_API configuration
powershell -Command "$content = Get-Content 'index.html' -Raw; $content = $content -replace 'window.CART_API = ''http:///api/cart'';', 'window.CART_API = ''%RAILWAY_URL%/api/cart'';'; Set-Content 'index.html' -Value $content"

echo.
echo ========================================
echo   CONFIGURATION UPDATED!
echo ========================================
echo.
echo Your frontend is now configured to use: %RAILWAY_URL%
echo.
echo Backup files created:
echo - assets\js\cart.js.backup
echo - index.html.backup
echo.
echo You can now deploy to AWS or test locally.
echo.
pause