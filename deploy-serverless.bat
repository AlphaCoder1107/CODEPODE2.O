@echo off
echo 🚀 Serverless Deployment (S3 + External Server)

echo 1️⃣ Uploading to S3...
aws s3 sync . s3://codepode.in-website --exclude "server/*" --exclude "deployment/*" --exclude "*.bat" --exclude "*.md" --exclude "*.yaml" --exclude "heroku-deploy/*"

echo.
echo 2️⃣ Creating server package for external hosting...
if not exist external-server mkdir external-server
xcopy /E /I /Y server\* external-server\ >nul 2>&1

echo.
echo ✅ Frontend deployed to S3!
echo 🌐 Website: http://codepode.in-website.s3-website-us-east-1.amazonaws.com
echo.
echo 📝 Next: Deploy server to Railway/Render/Vercel:
echo 1. Go to https://railway.app or https://render.com
echo 2. Connect your GitHub repo or upload external-server folder
echo 3. Set environment variables:
echo    - RAZORPAY_KEY_ID=rzp_test_R5XmEfkjyyHrMQ
echo    - RAZORPAY_KEY_SECRET=dCJ1EXoJzEPHxbfQlKRLHW7y
echo    - WEBHOOK_SECRET=0f3b2a8e9c6d4f1a2b3c4d5e6f708192a1b2c3d4e5f60718293a4c5b6d7e8f90
echo 4. Deploy and get your server URL
echo.
pause