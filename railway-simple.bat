@echo off
echo Railway Deployment

echo 2. Preparing server files...
if not exist railway-server mkdir railway-server
xcopy /E /I /Y server\* railway-server\ >nul 2>&1

echo 3. Go to railway-server folder
cd railway-server

echo 4. Login to Railway
railway login

echo 5. Create new project
railway new

echo 6. Set variables
railway variables set RAZORPAY_KEY_ID=rzp_test_R5XmEfkjyyHrMQ
railway variables set RAZORPAY_KEY_SECRET=dCJ1EXoJzEPHxbfQlKRLHW7y
railway variables set WEBHOOK_SECRET=0f3b2a8e9c6d4f1a2b3c4d5e6f708192a1b2c3d4e5f60718293a4c5b6d7e8f90
railway variables set NODE_ENV=production

echo 7. Deploy
railway up

echo 8. Get domain
railway domain

cd ..
pause