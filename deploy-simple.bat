@echo off
echo 🚀 Simple AWS Deploy (No CloudFormation)

REM Get parameters
set /p BUCKET_NAME="Enter S3 bucket name (must be unique): "
set /p REGION="Enter AWS region [us-east-1]: "
if "%REGION%"=="" set REGION=us-east-1

echo.
echo 📋 Deployment Info:
echo Bucket: %BUCKET_NAME%
echo Region: %REGION%
echo.
pause

echo 1️⃣ Preparing packages...
call prepare-deployment.bat

echo.
echo 2️⃣ Creating S3 bucket...
aws s3 mb s3://%BUCKET_NAME% --region %REGION%

echo.
echo 3️⃣ Enabling static website hosting...
aws s3 website s3://%BUCKET_NAME% --index-document index.html --error-document index.html

echo.
echo 4️⃣ Setting bucket policy for public access...
(
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
echo }
) > bucket-policy.json

aws s3api put-bucket-policy --bucket %BUCKET_NAME% --policy file://bucket-policy.json

echo.
echo 5️⃣ Uploading static files...
aws s3 sync deployment\static s3://%BUCKET_NAME% --delete --region %REGION%

echo.
echo 6️⃣ Uploading server files...
aws s3 cp deployment\server-deployment.zip s3://%BUCKET_NAME%/server/ --region %REGION%

echo.
echo ✅ Basic deployment complete!
echo.
echo 🌐 Website URL: http://%BUCKET_NAME%.s3-website-%REGION%.amazonaws.com
echo 📦 Bucket: %BUCKET_NAME%
echo.
echo 📝 Next Steps:
echo 1. Deploy server to Heroku/Railway/Vercel for backend
echo 2. Update API endpoints in frontend
echo 3. Set up custom domain with CloudFront
echo.
del bucket-policy.json
pause