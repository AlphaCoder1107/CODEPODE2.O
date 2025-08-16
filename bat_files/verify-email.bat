@echo off
echo 📧 SES Email Verification

set /p EMAIL="Enter your email address: "
set /p DOMAIN="Enter your domain: "

echo.
echo Verifying email address for SES...
aws ses verify-email-identity --email-address %EMAIL%

echo.
echo Verifying domain for SES...
aws ses verify-domain-identity --domain %DOMAIN%

echo.
echo ✅ Verification emails sent!
echo Check your inbox and click the verification links.
echo.
echo 📝 Note: You can send emails from verified addresses only.
echo For production, consider moving out of SES sandbox.

pause