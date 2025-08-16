@echo off
echo 🚀 Deploy Server Only

echo 1️⃣ Cleaning up old environment...
aws elasticbeanstalk terminate-environment --environment-name codepod-prod --terminate-resources 2>nul

echo.
echo 2️⃣ Getting correct Node.js platform...
for /f "tokens=*" %%i in ('aws elasticbeanstalk list-available-solution-stacks --query "SolutionStacks[?contains(@, 'Node.js 18')]" --output text') do set NODE_STACK=%%i

echo Using: %NODE_STACK%

echo.
echo 3️⃣ Creating new environment...
aws elasticbeanstalk create-environment ^
    --application-name codepod-app ^
    --environment-name codepod-server ^
    --solution-stack-name "%NODE_STACK%" ^
    --version-label v1.0 ^
    --option-settings ^
        Namespace=aws:elasticbeanstalk:application:environment,OptionName=RAZORPAY_KEY_ID,Value=rzp_test_R5XmEfkjyyHrMQ ^
        Namespace=aws:elasticbeanstalk:application:environment,OptionName=RAZORPAY_KEY_SECRET,Value=dCJ1EXoJzEPHxbfQlKRLHW7y ^
        Namespace=aws:elasticbeanstalk:application:environment,OptionName=WEBHOOK_SECRET,Value=0f3b2a8e9c6d4f1a2b3c4d5e6f708192a1b2c3d4e5f60718293a4c5b6d7e8f90 ^
        Namespace=aws:elasticbeanstalk:application:environment,OptionName=NODE_ENV,Value=production ^
        Namespace=aws:autoscaling:launchconfiguration,OptionName=InstanceType,Value=t2.micro

echo.
echo 4️⃣ Waiting 5 minutes for deployment...
timeout /t 300 /nobreak

echo.
echo 5️⃣ Getting server URL...
for /f "tokens=*" %%i in ('aws elasticbeanstalk describe-environments --environment-names codepod-server --query "Environments[0].CNAME" --output text') do set SERVER_URL=%%i

echo.
echo ✅ Server URL: http://%SERVER_URL%
echo 🧪 Test: http://%SERVER_URL%/api/health

pause