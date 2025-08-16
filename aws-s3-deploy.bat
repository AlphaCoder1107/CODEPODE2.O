@echo off
echo ========================================
echo   CodePod AWS S3 + CloudFront Deploy
echo ========================================

REM Check if AWS CLI is installed
aws --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: AWS CLI not found. Please install AWS CLI first.
    echo Download from: https://aws.amazon.com/cli/
    pause
    exit /b 1
)

REM Check AWS credentials
aws sts get-caller-identity >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: AWS credentials not configured.
    echo Run: aws configure
    pause
    exit /b 1
)

set /p BUCKET_NAME="Enter your S3 bucket name (e.g., codepod-website): "
set /p RAILWAY_URL="Enter your Railway server URL (e.g., https://your-app.railway.app): "

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
if exist "aws-deploy" rmdir /s /q "aws-deploy"
mkdir aws-deploy

echo Copying website files...
xcopy /E /I /Y "assets" "aws-deploy\assets\"
xcopy /Y "*.html" "aws-deploy\"
xcopy /Y "pi_2W\*" "aws-deploy\pi_2W\"
xcopy /Y "pi_3B\*" "aws-deploy\pi_3B\"

echo.
echo Updating API configuration...
powershell -Command "(Get-Content 'aws-deploy\index.html') -replace 'window.CART_API = ''http:///api/cart'';', 'window.CART_API = ''%RAILWAY_URL%/api/cart'';' | Set-Content 'aws-deploy\index.html'"
powershell -Command "(Get-Content 'aws-deploy\assets\js\cart.js') -replace 'const API_BASE = explicitBase \|\| \(IS_LOCALHOST \? ''http://'' : ''''\);', 'const API_BASE = explicitBase || ''%RAILWAY_URL%'';' | Set-Content 'aws-deploy\assets\js\cart.js'"

echo.
echo Creating S3 bucket...
aws s3 mb s3://%BUCKET_NAME% --region us-east-1

echo.
echo Configuring bucket for static website hosting...
aws s3 website s3://%BUCKET_NAME% --index-document index.html --error-document index.html

echo.
echo Setting bucket policy for public read access...
echo {
echo   "Version": "2012-10-17",
echo   "Statement": [
echo     {
echo       "Sid": "PublicReadGetObject",
echo       "Effect": "Allow",
echo       "Principal": "*",
echo       "Action": "s3:GetObject",
echo       "Resource": "arn:aws:s3:::%BUCKET_NAME%/*"
echo     }
echo   ]
echo } > bucket-policy.json

aws s3api put-bucket-policy --bucket %BUCKET_NAME% --policy file://bucket-policy.json
del bucket-policy.json

echo.
echo Uploading website files to S3...
aws s3 sync aws-deploy s3://%BUCKET_NAME% --delete --cache-control "max-age=86400"

echo.
echo Creating CloudFront distribution...
echo {
echo   "CallerReference": "%BUCKET_NAME%-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2%",
echo   "Comment": "CodePod Website Distribution",
echo   "DefaultCacheBehavior": {
echo     "TargetOriginId": "%BUCKET_NAME%-origin",
echo     "ViewerProtocolPolicy": "redirect-to-https",
echo     "TrustedSigners": {
echo       "Enabled": false,
echo       "Quantity": 0
echo     },
echo     "ForwardedValues": {
echo       "QueryString": false,
echo       "Cookies": {
echo         "Forward": "none"
echo       }
echo     },
echo     "MinTTL": 0,
echo     "DefaultTTL": 86400,
echo     "MaxTTL": 31536000
echo   },
echo   "Origins": {
echo     "Quantity": 1,
echo     "Items": [
echo       {
echo         "Id": "%BUCKET_NAME%-origin",
echo         "DomainName": "%BUCKET_NAME%.s3-website-us-east-1.amazonaws.com",
echo         "CustomOriginConfig": {
echo           "HTTPPort": 80,
echo           "HTTPSPort": 443,
echo           "OriginProtocolPolicy": "http-only"
echo         }
echo       }
echo     ]
echo   },
echo   "Enabled": true,
echo   "DefaultRootObject": "index.html",
echo   "CustomErrorResponses": {
echo     "Quantity": 1,
echo     "Items": [
echo       {
echo         "ErrorCode": 404,
echo         "ResponsePagePath": "/index.html",
echo         "ResponseCode": "200",
echo         "ErrorCachingMinTTL": 300
echo       }
echo     ]
echo   },
echo   "PriceClass": "PriceClass_100"
echo } > cloudfront-config.json

aws cloudfront create-distribution --distribution-config file://cloudfront-config.json > cloudfront-result.json
del cloudfront-config.json

echo.
echo ========================================
echo   DEPLOYMENT COMPLETE!
echo ========================================
echo.
echo S3 Website URL: http://%BUCKET_NAME%.s3-website-us-east-1.amazonaws.com
echo.
echo CloudFront distribution created. It may take 15-20 minutes to deploy globally.
echo Check the AWS Console for your CloudFront domain name.
echo.
echo Your website is now live and connected to your Railway server!
echo.
pause