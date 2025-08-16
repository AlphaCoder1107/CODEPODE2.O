@echo off
echo 🚀 CodePod Full-Stack AWS Deployment
echo.

REM Get deployment parameters
set /p DOMAIN="Enter your domain name (e.g., codepod.com): "
set /p EMAIL="Enter your email for contact form: "
set /p RAZORPAY_KEY_ID="Enter your Razorpay Key ID: "
set /p RAZORPAY_KEY_SECRET="Enter your Razorpay Key Secret: "
set /p WEBHOOK_SECRET="Enter your Webhook Secret: "

set STACK_NAME=codepod-fullstack
set REGION=us-east-1

echo.
echo 📋 Deployment Summary:
echo Domain: %DOMAIN%
echo Email: %EMAIL%
echo Stack: %STACK_NAME%
echo Region: %REGION%
echo.

pause

echo 1️⃣ Preparing deployment packages...
call prepare-deployment.bat

echo.
echo 2️⃣ Creating CloudFormation stack...
aws cloudformation create-stack ^
    --stack-name %STACK_NAME% ^
    --template-body file://full-stack-infrastructure.yaml ^
    --parameters ^
        ParameterKey=DomainName,ParameterValue=%DOMAIN% ^
        ParameterKey=ContactEmail,ParameterValue=%EMAIL% ^
        ParameterKey=RazorpayKeyId,ParameterValue=%RAZORPAY_KEY_ID% ^
        ParameterKey=RazorpayKeySecret,ParameterValue=%RAZORPAY_KEY_SECRET% ^
        ParameterKey=WebhookSecret,ParameterValue=%WEBHOOK_SECRET% ^
    --capabilities CAPABILITY_IAM ^
    --region %REGION%

if errorlevel 1 (
    echo ❌ Stack creation failed!
    pause
    exit /b 1
)

echo.
echo 3️⃣ Waiting for stack creation (15-20 minutes)...
aws cloudformation wait stack-create-complete --stack-name %STACK_NAME% --region %REGION%

if errorlevel 1 (
    echo ❌ Stack creation timed out or failed!
    echo Checking stack events...
    aws cloudformation describe-stack-events --stack-name %STACK_NAME% --region %REGION% --query "StackEvents[?ResourceStatus=='CREATE_FAILED'].[LogicalResourceId,ResourceStatusReason]" --output table
    pause
    exit /b 1
)

echo.
echo 4️⃣ Getting stack outputs...
for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --region %REGION% --query "Stacks[0].Outputs[?OutputKey=='StaticAssetsBucket'].OutputValue" --output text') do set STATIC_BUCKET=%%i
for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --region %REGION% --query "Stacks[0].Outputs[?OutputKey=='ElasticBeanstalkURL'].OutputValue" --output text') do set EB_URL=%%i

echo.
echo 5️⃣ Uploading static assets to S3...
aws s3 sync deployment\static s3://%STATIC_BUCKET% --delete --region %REGION%

echo.
echo 6️⃣ Deploying server to Elastic Beanstalk...
REM Get application and environment names
for /f "tokens=*" %%i in ('aws elasticbeanstalk describe-applications --region %REGION% --query "Applications[?ApplicationName=='codepod-app'].ApplicationName" --output text') do set APP_NAME=%%i
for /f "tokens=*" %%i in ('aws elasticbeanstalk describe-environments --application-name codepod-app --region %REGION% --query "Environments[0].EnvironmentName" --output text') do set ENV_NAME=%%i

REM Create application version
aws elasticbeanstalk create-application-version ^
    --application-name %APP_NAME% ^
    --version-label v%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2% ^
    --source-bundle S3Bucket=%STATIC_BUCKET%,S3Key=server-deployment.zip ^
    --region %REGION%

REM Upload server package to S3
aws s3 cp deployment\server-deployment.zip s3://%STATIC_BUCKET%/server-deployment.zip --region %REGION%

REM Deploy to environment
aws elasticbeanstalk update-environment ^
    --environment-name %ENV_NAME% ^
    --version-label v%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2% ^
    --region %REGION%

echo.
echo 7️⃣ Waiting for deployment to complete...
aws elasticbeanstalk wait environment-updated --environment-name %ENV_NAME% --region %REGION%

echo.
echo ✅ Deployment Complete!
echo.
echo 🌐 Website URL: https://%DOMAIN%
echo 🔧 Elastic Beanstalk URL: %EB_URL%
echo 📦 Static Assets Bucket: %STATIC_BUCKET%
echo.
echo 📝 Next Steps:
echo 1. Update your domain's nameservers to point to Route 53
echo 2. Verify SSL certificate validation
echo 3. Test your website and payment integration
echo 4. Monitor Elastic Beanstalk health
echo.
echo 🔍 Useful Commands:
echo - Check EB logs: aws logs describe-log-groups --region %REGION%
echo - Monitor stack: aws cloudformation describe-stacks --stack-name %STACK_NAME% --region %REGION%
echo.

pause