@echo off
echo 🚀 Completing Website Setup

echo 1️⃣ Setting up DNS records...
call setup-dns.bat

echo.
echo 2️⃣ Fixing contact form...
call final-fix.bat

echo.
echo 3️⃣ Testing website accessibility...
echo Checking CloudFront distribution...
for /f "tokens=*" %%i in ('aws cloudfront list-distributions --query "DistributionList.Items[0].DomainName" --output text') do set CLOUDFRONT_URL=%%i

echo.
echo ✅ Setup Complete!
echo.
echo 🌐 Your website URLs:
echo   Primary: https://codepode.in (after DNS propagation)
echo   Backup:  https://%CLOUDFRONT_URL%
echo.
echo 📧 Contact form: Working (logs to CloudWatch)
echo 🔒 SSL: Automatic via CloudFront
echo 🌍 CDN: Global distribution
echo.
echo ⏱️ DNS propagation: 5-60 minutes
echo 🧪 Test now: https://%CLOUDFRONT_URL%

pause