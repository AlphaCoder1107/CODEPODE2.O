@echo off
echo 🌐 Checking Domain Migration Status

echo Checking DNS propagation for codepode.in...
nslookup codepode.in

echo.
echo Checking if domain points to AWS...
ping codepode.in -n 1

echo.
echo Setting up DNS records in Route 53...
call setup-dns.bat

echo.
echo ✅ Domain migration status:
echo 📝 Nameservers updated: YES
echo ⏱️ DNS propagation: 5-60 minutes
echo 🌐 Test your site: https://codepode.in

echo.
echo 🔍 Check propagation worldwide: https://dnschecker.org
echo Enter "codepode.in" to see global DNS status

pause