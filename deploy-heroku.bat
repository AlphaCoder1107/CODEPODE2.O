@echo off
echo 🚀 Deploy Server to Heroku

REM Check Heroku CLI
heroku --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Heroku CLI not found. Install from: https://devcenter.heroku.com/articles/heroku-cli
    pause
    exit /b 1
)

set /p APP_NAME="Enter Heroku app name: "

echo.
echo 📋 Deploying server to Heroku...
echo App: %APP_NAME%
echo.

REM Prepare server for Heroku
echo 1️⃣ Preparing server files...
if not exist heroku-deploy mkdir heroku-deploy
xcopy /E /I /Y server\* heroku-deploy\ >nul 2>&1

REM Create Procfile
echo web: node index.js > heroku-deploy\Procfile

cd heroku-deploy

echo.
echo 2️⃣ Initializing git...
git init
git add .
git commit -m "Initial commit"

echo.
echo 3️⃣ Creating Heroku app...
heroku create %APP_NAME%

echo.
echo 4️⃣ Setting environment variables...
heroku config:set NODE_ENV=production
heroku config:set RAZORPAY_KEY_ID=%RAZORPAY_KEY_ID%
heroku config:set RAZORPAY_KEY_SECRET=%RAZORPAY_KEY_SECRET%
heroku config:set WEBHOOK_SECRET=%WEBHOOK_SECRET%

echo.
echo 5️⃣ Deploying to Heroku...
git push heroku main

cd ..

echo.
echo ✅ Server deployed to Heroku!
echo 🌐 Server URL: https://%APP_NAME%.herokuapp.com
echo.
pause