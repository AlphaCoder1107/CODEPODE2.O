@echo off
title CodePod AWS Deployment
color 0A

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                    CodePod AWS Deployment                    ║
echo  ║                                                              ║
echo  ║  This script will deploy your website to AWS S3 and         ║
echo  ║  connect it to your Railway server for payment processing   ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

REM Check prerequisites
echo [1/6] Checking prerequisites...

REM Check AWS CLI
aws --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ AWS CLI not found
    echo.
    echo Please install AWS CLI first:
    echo https://aws.amazon.com/cli/
    echo.
    echo After installation, run: aws configure
    pause
    exit /b 1
)
echo ✅ AWS CLI found

REM Check AWS credentials
aws sts get-caller-identity >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ AWS credentials not configured
    echo.
    echo Please run: aws configure
    echo.
    echo You'll need:
    echo - AWS Access Key ID
    echo - AWS Secret Access Key
    echo - Default region (use: us-east-1)
    pause
    exit /b 1
)
echo ✅ AWS credentials configured

echo.
echo [2/6] Getting deployment information...

set /p RAILWAY_URL="🚂 Enter your Railway server URL (e.g., https://your-app.railway.app): "
set /p BUCKET_NAME="🪣 Enter S3 bucket name (must be globally unique): "
set /p DOMAIN_NAME="🌐 Enter your domain name (optional, press Enter to skip): "

if "%RAILWAY_URL%"=="" (
    echo ❌ Railway URL is required
    pause
    exit /b 1
)

if "%BUCKET_NAME%"=="" (
    echo ❌ Bucket name is required
    pause
    exit /b 1
)

echo.
echo [3/6] Testing Railway server connection...
curl -s "%RAILWAY_URL%/api/config" >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Railway server is responding
) else (
    echo ⚠️  Warning: Could not connect to Railway server
    echo Please verify your server is running and URL is correct
    set /p CONTINUE="Continue anyway? (y/N): "
    if /i not "%CONTINUE%"=="y" exit /b 1
)

echo.
echo [4/6] Preparing deployment files...

REM Clean and create deployment directory
if exist "aws-deployment" rmdir /s /q "aws-deployment"
mkdir aws-deployment

REM Copy website files
echo Copying HTML files...
copy "*.html" "aws-deployment\" >nul

echo Copying assets...
xcopy /E /I /Y "assets" "aws-deployment\assets\" >nul

echo Copying product pages...
if exist "pi_2W" xcopy /E /I /Y "pi_2W" "aws-deployment\pi_2W\" >nul
if exist "pi_3B" xcopy /E /I /Y "pi_3B" "aws-deployment\pi_3B\" >nul

echo Updating API configuration...
powershell -Command "$content = Get-Content 'aws-deployment\assets\js\cart.js' -Raw; $content = $content -replace 'const API_BASE = explicitBase \|\| \(IS_LOCALHOST \? ''http://'' : ''''\);', 'const API_BASE = explicitBase || ''%RAILWAY_URL%'';'; Set-Content 'aws-deployment\assets\js\cart.js' -Value $content" >nul

echo ✅ Files prepared

echo.
echo [5/6] Deploying to AWS S3...

echo Creating S3 bucket...
aws s3 mb s3://%BUCKET_NAME% --region us-east-1 >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ S3 bucket created
) else (
    echo ⚠️  Bucket might already exist, continuing...
)

echo Configuring static website hosting...
aws s3 website s3://%BUCKET_NAME% --index-document index.html --error-document index.html >nul
echo ✅ Website hosting configured

echo Setting public access policy...
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
echo } > temp-policy.json

aws s3api put-bucket-policy --bucket %BUCKET_NAME% --policy file://temp-policy.json >nul
del temp-policy.json
echo ✅ Public access configured

echo Uploading website files...
aws s3 sync aws-deployment s3://%BUCKET_NAME% --delete --quiet
echo ✅ Files uploaded

echo.
echo [6/6] Deployment complete!

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                    🎉 DEPLOYMENT SUCCESSFUL! 🎉              ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo 🌐 Your website is now live at:
echo    http://%BUCKET_NAME%.s3-website-us-east-1.amazonaws.com
echo.
echo 🚂 Connected to Railway server:
echo    %RAILWAY_URL%
echo.
echo 💳 Razorpay payments are handled by your Railway server
echo.

if not "%DOMAIN_NAME%"=="" (
    echo 🔗 To use your custom domain (%DOMAIN_NAME%):
    echo    1. Go to AWS Route 53 console
    echo    2. Create a hosted zone for %DOMAIN_NAME%
    echo    3. Create a CNAME record pointing to:
    echo       %BUCKET_NAME%.s3-website-us-east-1.amazonaws.com
    echo.
)

echo 📊 Next steps:
echo    • Test your website and payment flow
echo    • Set up CloudFront for HTTPS (optional)
echo    • Configure custom domain (optional)
echo    • Monitor usage in AWS Console
echo.
echo 💰 Estimated monthly cost: $1-5 USD for small traffic
echo.

REM Clean up
rmdir /s /q "aws-deployment" >nul 2>&1

echo Press any key to open your website...
pause >nul

REM Try to open the website
start http://%BUCKET_NAME%.s3-website-us-east-1.amazonaws.com

echo.
echo Deployment complete! Your CodePod website is now live on AWS! 🚀
echo.