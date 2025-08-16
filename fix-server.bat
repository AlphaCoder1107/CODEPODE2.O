@echo off
echo 🔧 Fixing Server Deployment

echo 1️⃣ Checking EB environment status...
aws elasticbeanstalk describe-environments --environment-names codepod-prod

echo.
echo 2️⃣ Getting environment URL...
for /f "tokens=*" %%i in ('aws elasticbeanstalk describe-environments --environment-names codepod-prod --query "Environments[0].CNAME" --output text') do set SERVER_URL=%%i

if "%SERVER_URL%"=="None" (
    echo ❌ Environment not ready. Waiting...
    aws elasticbeanstalk wait environment-ready --environment-name codepod-prod
    for /f "tokens=*" %%i in ('aws elasticbeanstalk describe-environments --environment-names codepod-prod --query "Environments[0].CNAME" --output text') do set SERVER_URL=%%i
)

echo.
echo 3️⃣ Uploading server code...
aws s3 cp deployment\server-deployment.zip s3://codepode.in-website/server-deployment.zip

echo.
echo 4️⃣ Creating new version...
aws elasticbeanstalk create-application-version ^
    --application-name codepod-app ^
    --version-label v1.1 ^
    --source-bundle S3Bucket=codepode.in-website,S3Key=server-deployment.zip

echo.
echo 5️⃣ Deploying to environment...
aws elasticbeanstalk update-environment ^
    --environment-name codepod-prod ^
    --version-label v1.1

echo.
echo 6️⃣ Waiting for deployment...
aws elasticbeanstalk wait environment-updated --environment-name codepod-prod

echo.
echo 7️⃣ Getting final URL...
for /f "tokens=*" %%i in ('aws elasticbeanstalk describe-environments --environment-names codepod-prod --query "Environments[0].CNAME" --output text') do set FINAL_URL=%%i

echo.
echo ✅ Server URL: http://%FINAL_URL%
echo.
echo Test it: http://%FINAL_URL%/api/health
pause