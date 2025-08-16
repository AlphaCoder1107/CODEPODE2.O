@echo off
echo ========================================
echo   CodePod AWS S3 Quick Deploy
echo ========================================

REM Check if AWS CLI is installed
aws --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: AWS CLI not found. Please install AWS CLI first.
    echo Download from: https://aws.amazon.com/cli/
    pause
    exit /b 1
)

set /p BUCKET_NAME="Enter your S3 bucket name (e.g., my-codepod-site): "
set /p RAILWAY_URL="Enter your Railway server URL (without trailing slash): "

if "%BUCKET_NAME%"=="" (
    echo ERROR: Bucket name is required
    pause
    exit /b 1
)

if "%RAILWAY_URL%"=="" (
    echo ERROR: Railway URL is required
    pause
    exit /b 1
)

echo.
echo Creating deployment directory...
if exist "deploy" rmdir /s /q "deploy"
mkdir deploy

echo Copying files...
copy "*.html" "deploy\"
xcopy /E /I /Y "assets" "deploy\assets\"
xcopy /E /I /Y "pi_2W" "deploy\pi_2W\"
xcopy /E /I /Y "pi_3B" "deploy\pi_3B\"

echo.
echo Updating API configuration in cart.js...
powershell -Command "$content = Get-Content 'deploy\assets\js\cart.js' -Raw; $content = $content -replace 'const API_BASE = explicitBase \|\| \(IS_LOCALHOST \? ''http://'' : ''''\);', 'const API_BASE = explicitBase || ''%RAILWAY_URL%'';'; Set-Content 'deploy\assets\js\cart.js' -Value $content"

echo.
echo Creating S3 bucket...
aws s3 mb s3://%BUCKET_NAME% --region us-east-1

echo.
echo Configuring bucket for static website hosting...
aws s3 website s3://%BUCKET_NAME% --index-document index.html --error-document index.html

echo.
echo Setting public read policy...
echo {
echo   "Version": "2012-10-17",
echo   "Statement": [
echo     {
echo       "Effect": "Allow",
echo       "Principal": "*",
echo       "Action": "s3:GetObject",
echo       "Resource": "arn:aws:s3:::%BUCKET_NAME%/*"
echo     }
echo   ]
echo } > policy.json

aws s3api put-bucket-policy --bucket %BUCKET_NAME% --policy file://policy.json
del policy.json

echo.
echo Uploading files to S3...
aws s3 sync deploy s3://%BUCKET_NAME% --delete

echo.
echo ========================================
echo   DEPLOYMENT COMPLETE!
echo ========================================
echo.
echo Your website is now live at:
echo http://%BUCKET_NAME%.s3-website-us-east-1.amazonaws.com
echo.
echo The website is connected to your Railway server at: %RAILWAY_URL%
echo.
pause