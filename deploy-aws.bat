@echo off
echo 🚀 CodePod AWS Deployment

REM Check AWS CLI
aws --version >nul 2>&1
if errorlevel 1 (
    echo ❌ AWS CLI not found. Please install AWS CLI first.
    pause
    exit /b 1
)

REM Get parameters
set /p DOMAIN="Enter domain (e.g., codepod.com): "
set /p EMAIL="Enter contact email: "
set /p RAZORPAY_KEY_ID="Enter Razorpay Key ID: "
set /p RAZORPAY_KEY_SECRET="Enter Razorpay Secret: "
set /p WEBHOOK_SECRET="Enter Webhook Secret: "

set STACK_NAME=codepod-stack
set REGION=us-east-1

echo.
echo 📋 Deployment Info:
echo Domain: %DOMAIN%
echo Stack: %STACK_NAME%
echo Region: %REGION%
echo.
pause

echo 1️⃣ Preparing packages...
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
echo 3️⃣ Waiting for stack creation...
aws cloudformation wait stack-create-complete --stack-name %STACK_NAME% --region %REGION%

echo.
echo 4️⃣ Getting outputs...
for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --region %REGION% --query "Stacks[0].Outputs[?OutputKey=='StaticAssetsBucket'].OutputValue" --output text') do set BUCKET=%%i
for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --region %REGION% --query "Stacks[0].Outputs[?OutputKey=='ElasticBeanstalkURL'].OutputValue" --output text') do set EB_URL=%%i

echo.
echo 5️⃣ Uploading static files...
aws s3 sync deployment\static s3://%BUCKET% --delete --region %REGION%

echo.
echo 6️⃣ Deploying server...
aws s3 cp deployment\server-deployment.zip s3://%BUCKET%/server-deployment.zip --region %REGION%

for /f "tokens=*" %%i in ('aws elasticbeanstalk describe-environments --application-name codepod-app --region %REGION% --query "Environments[0].EnvironmentName" --output text') do set ENV_NAME=%%i

set VERSION_LABEL=v%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2%

aws elasticbeanstalk create-application-version ^
    --application-name codepod-app ^
    --version-label %VERSION_LABEL% ^
    --source-bundle S3Bucket=%BUCKET%,S3Key=server-deployment.zip ^
    --region %REGION%

aws elasticbeanstalk update-environment ^
    --environment-name %ENV_NAME% ^
    --version-label %VERSION_LABEL% ^
    --region %REGION%

echo.
echo 7️⃣ Waiting for deployment...
aws elasticbeanstalk wait environment-updated --environment-name %ENV_NAME% --region %REGION%

echo.
echo ✅ Deployment Complete!
echo.
echo 🌐 Website: https://%DOMAIN%
echo 🔧 EB URL: %EB_URL%
echo 📦 Bucket: %BUCKET%
echo.
pause