@echo off
echo 📧 Checking SES Email Status

echo Checking verification status for ayushvermm1107@gmail.com...
aws ses get-identity-verification-attributes --identities ayushvermm1107@gmail.com

echo.
echo Checking SES sending quota...
aws ses get-send-quota

echo.
echo Re-sending verification email...
aws ses verify-email-identity --email-address ayushvermm1107@gmail.com

echo.
echo ✅ Verification email re-sent!
echo 📝 Check these locations:
echo   - Gmail Inbox
echo   - Spam/Junk folder
echo   - Promotions tab
echo   - All Mail folder

pause