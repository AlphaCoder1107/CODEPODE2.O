@echo off
echo 🚀 Deploy to Railway Free and Fast

echo 1️⃣ Installing Railway CLI...
npm install -g @railway/cli

echo.
echo 2️⃣ Preparing server for Railway...
if not exist railway-server mkdir railway-server
xcopy /E /I /Y server\* railway-server\ >nul 2>&1

cd railway-server

echo.
echo 3️⃣ Login to Railway (browser will open)...
railway login

echo.
echo 4️⃣ Creating new project...
railway new

echo.
echo 5️⃣ Setting environment variables...
railway variables set RAZORPAY_KEY_ID=rzp_test_R5XmEfkjyyHrMQ
railway variables set RAZORPAY_KEY_SECRET=dCJ1EXoJzEPHxbfQlKRLHW7y
railway variables set WEBHOOK_SECRET=0f3b2a8e9c6d4f1a2b3c4d5e6f708192a1b2c3d4e5f60718293a4c5b6d7e8f90
railway variables set NODE_ENV=production

echo.
echo 6️⃣ Deploying...
railway up

echo.
echo 7️⃣ Getting your server URL...
railway domain

cd ..

echo.
echo ✅ Server deployed to Railway!
echo 🌐 Website: http://codepode.in-website.s3-website-us-east-1.amazonaws.com
echo 🔧 Server: Check Railway dashboard for URL
echo.
echo Next: Run update-frontend.bat with your Railway URL
pause