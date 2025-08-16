@echo off
echo 📦 Preparing deployment packages...

REM Create deployment directory
if not exist deployment mkdir deployment
if not exist deployment\static mkdir deployment\static
if not exist deployment\server mkdir deployment\server

REM Copy static files (excluding server directory)
echo Copying static files...
xcopy /E /I /Y *.html deployment\static\ >nul 2>&1
xcopy /E /I /Y assets deployment\static\assets\ >nul 2>&1
xcopy /E /I /Y pi_2W deployment\static\pi_2W\ >nul 2>&1
xcopy /E /I /Y pi_3B deployment\static\pi_3B\ >nul 2>&1

REM Copy server files
echo Copying server files...
xcopy /E /I /Y server\* deployment\server\ >nul 2>&1

REM Create package.json for EB deployment
echo Creating EB package.json...
(
echo {
echo   "name": "codepod-server",
echo   "version": "1.0.0",
echo   "main": "index.js",
echo   "scripts": {
echo     "start": "node index.js"
echo   },
echo   "dependencies": {
echo     "cors": "^2.8.5",
echo     "dotenv": "^16.3.1",
echo     "express": "^4.18.2",
echo     "razorpay": "^2.8.1",
echo     "libphonenumber-js": "^1.10.22",
echo     "morgan": "^1.10.0",
echo     "fs-extra": "^11.1.1"
echo   }
echo }
) > deployment\server\package.json

REM Create zip for server deployment
echo Creating server deployment package...
cd deployment\server
if exist ..\server-deployment.zip del ..\server-deployment.zip
powershell -command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::CreateFromDirectory('.', '..\server-deployment.zip')"
cd ..\..

echo ✅ Deployment packages ready!