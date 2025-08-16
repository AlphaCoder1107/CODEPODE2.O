@echo off
echo 🔧 Quick Fix: Contact Form Setup

echo Step 1: Verify SES email
aws ses verify-email-identity --email-address ayushvermm1107@gmail.com
echo ✅ Verification email sent to ayushvermm1107@gmail.com

echo.
echo Step 2: Get API endpoint
call get-api-endpoint.bat

echo.
echo Step 3: Test Lambda function
echo Testing Lambda function...
aws lambda invoke --function-name codepod-contact --payload "{\"httpMethod\":\"POST\",\"body\":\"{\\\"companyName\\\":\\\"Test\\\",\\\"contactName\\\":\\\"Test User\\\",\\\"email\\\":\\\"test@example.com\\\",\\\"message\\\":\\\"Test message\\\"}\"}" response.json
type response.json
del response.json

echo.
echo ✅ Setup complete!
echo 📧 Check your email for SES verification
echo 🌐 Test contact form at: https://codepode.in/contact.html

pause