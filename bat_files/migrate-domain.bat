@echo off
echo 🚀 Complete Domain Migration: Hostinger → AWS

echo Step 1: Getting AWS nameservers...
call get-nameservers.bat

echo.
echo Step 2: Setting up DNS records...
call setup-dns.bat

echo.
echo ✅ AWS setup complete!
echo.
echo 📋 MANUAL STEPS REQUIRED:
echo.
echo 1. Go to Hostinger Control Panel
echo 2. Find your domain: codepode.in
echo 3. Go to DNS/Nameservers section
echo 4. Replace current nameservers with the 4 AWS nameservers shown above
echo 5. Save changes
echo.
echo ⏱️ DNS propagation takes 5-60 minutes
echo 🌐 Your site will then be live at https://codepode.in
echo.
echo 🔍 Check propagation status at: https://dnschecker.org

pause