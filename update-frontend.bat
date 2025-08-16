@echo off
echo 🔧 Updating frontend to use production server

set /p SERVER_URL="Enter your Elastic Beanstalk server URL (e.g., codepod-prod.us-east-1.elasticbeanstalk.com): "

echo Updating cart.js to use production server...

REM Update cart.js to point to production server
powershell -command "(Get-Content assets\js\cart.js) -replace 'http://localhost:3001', 'http://%SERVER_URL%' | Set-Content assets\js\cart.js"

echo Updating index.html...
powershell -command "(Get-Content index.html) -replace 'http://localhost:3001/api/cart', 'http://%SERVER_URL%/api/cart' | Set-Content index.html"

echo.
echo ✅ Frontend updated to use: http://%SERVER_URL%
echo.
echo Re-uploading to S3...
set WEBSITE_BUCKET=codepode.in-website
aws s3 sync . s3://%WEBSITE_BUCKET% --exclude "server/*" --exclude "deployment/*" --exclude "*.bat" --exclude "*.md" --exclude "*.yaml"

echo.
echo ✅ Frontend updated and deployed!
pause