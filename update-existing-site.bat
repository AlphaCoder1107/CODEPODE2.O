@echo off
echo Updating existing CodePod website with Razorpay integration...

set /p BUCKET_NAME="Enter your existing S3 bucket name: "
set /p RAILWAY_URL="Enter your Railway server URL: "

echo.
echo Preparing updated files...
if exist "update-deploy" rmdir /s /q "update-deploy"
mkdir update-deploy

copy "*.html" "update-deploy\"
xcopy /E /I /Y "assets" "update-deploy\assets\"
xcopy /E /I /Y "pi_2W" "update-deploy\pi_2W\"
xcopy /E /I /Y "pi_3B" "update-deploy\pi_3B\"

echo Updating API configuration...
powershell -Command "$content = Get-Content 'update-deploy\assets\js\cart.js' -Raw; $content = $content -replace 'const API_BASE = explicitBase \|\| \(IS_LOCALHOST \? ''http://'' : ''''\);', 'const API_BASE = explicitBase || ''%RAILWAY_URL%'';'; Set-Content 'update-deploy\assets\js\cart.js' -Value $content"

echo Uploading to S3...
aws s3 sync update-deploy s3://%BUCKET_NAME% --delete

echo.
echo ✅ Website updated successfully!
echo Your site now has Razorpay integration via Railway server.
echo.
pause