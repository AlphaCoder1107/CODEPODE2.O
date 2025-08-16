@echo off
echo 🚀 Quick AWS Deploy

REM Use default values for quick deployment
set DOMAIN=codepod-demo.com
set EMAIL=admin@codepod-demo.com
set RAZORPAY_KEY_ID=%RAZORPAY_KEY_ID%
set RAZORPAY_KEY_SECRET=%RAZORPAY_KEY_SECRET%
set WEBHOOK_SECRET=quick-webhook-secret-123

if "%RAZORPAY_KEY_ID%"=="" (
    echo ❌ Set RAZORPAY_KEY_ID environment variable first
    pause
    exit /b 1
)

if "%RAZORPAY_KEY_SECRET%"=="" (
    echo ❌ Set RAZORPAY_KEY_SECRET environment variable first
    pause
    exit /b 1
)

set STACK_NAME=codepod-quick
set REGION=us-east-1

echo Deploying with defaults...
echo Domain: %DOMAIN%
echo Stack: %STACK_NAME%

call prepare-deployment.bat

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

echo ✅ Stack creation started. Check AWS Console for progress.
pause