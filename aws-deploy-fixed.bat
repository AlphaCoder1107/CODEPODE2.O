@echo off
echo 🚀 Fixed AWS Deployment

set DOMAIN=codepode.in
set REGION=us-east-1
set WEBSITE_BUCKET=%DOMAIN%-website

echo 1️⃣ Preparing deployment packages...
call prepare-deployment.bat

echo.
echo 2️⃣ Creating S3 bucket...
aws s3 mb s3://%WEBSITE_BUCKET% --region %REGION%

echo.
echo 3️⃣ Disabling block public access...
aws s3api put-public-access-block --bucket %WEBSITE_BUCKET% --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

echo.
echo 4️⃣ Setting bucket policy...
(
echo {
echo   "Version": "2012-10-17",
echo   "Statement": [
echo     {
echo       "Effect": "Allow",
echo       "Principal": "*",
echo       "Action": "s3:GetObject",
echo       "Resource": "arn:aws:s3:::%WEBSITE_BUCKET%/*"
echo     }
echo   ]
echo }
) > website-policy.json

aws s3api put-bucket-policy --bucket %WEBSITE_BUCKET% --policy file://website-policy.json

echo.
echo 5️⃣ Enabling website hosting...
aws s3 website s3://%WEBSITE_BUCKET% --index-document index.html

echo.
echo 6️⃣ Uploading website files...
aws s3 sync deployment\static s3://%WEBSITE_BUCKET% --delete

echo.
echo 7️⃣ Getting latest Node.js platform...
for /f "tokens=*" %%i in ('aws elasticbeanstalk list-available-solution-stacks --query "SolutionStacks[?contains(@, 'Node.js')] | [0]" --output text') do set NODE_STACK=%%i

echo Using platform: %NODE_STACK%

echo.
echo 8️⃣ Creating Elastic Beanstalk application...
aws elasticbeanstalk create-application --application-name codepod-app --description "CodePod Payment Server" --region %REGION%

echo.
echo 9️⃣ Uploading server code first...
aws s3 cp deployment\server-deployment.zip s3://%WEBSITE_BUCKET%/server-deployment.zip

echo.
echo 🔟 Creating application version...
aws elasticbeanstalk create-application-version ^
    --application-name codepod-app ^
    --version-label v1.0 ^
    --source-bundle S3Bucket=%WEBSITE_BUCKET%,S3Key=server-deployment.zip ^
    --region %REGION%

echo.
echo 1️⃣1️⃣ Creating EB environment...
aws elasticbeanstalk create-environment ^
    --application-name codepod-app ^
    --environment-name codepod-prod ^
    --solution-stack-name "%NODE_STACK%" ^
    --version-label v1.0 ^
    --option-settings ^
        Namespace=aws:elasticbeanstalk:application:environment,OptionName=RAZORPAY_KEY_ID,Value=rzp_test_R5XmEfkjyyHrMQ ^
        Namespace=aws:elasticbeanstalk:application:environment,OptionName=RAZORPAY_KEY_SECRET,Value=dCJ1EXoJzEPHxbfQlKRLHW7y ^
        Namespace=aws:elasticbeanstalk:application:environment,OptionName=WEBHOOK_SECRET,Value=0f3b2a8e9c6d4f1a2b3c4d5e6f708192a1b2c3d4e5f60718293a4c5b6d7e8f90 ^
        Namespace=aws:elasticbeanstalk:application:environment,OptionName=NODE_ENV,Value=production ^
        Namespace=aws:autoscaling:launchconfiguration,OptionName=InstanceType,Value=t3.micro ^
    --region %REGION%

echo.
echo 1️⃣2️⃣ Waiting for environment...
timeout /t 300 /nobreak

echo.
echo 1️⃣3️⃣ Getting environment URL...
for /f "tokens=*" %%i in ('aws elasticbeanstalk describe-environments --environment-names codepod-prod --region %REGION% --query "Environments[0].CNAME" --output text') do set SERVER_URL=%%i

echo.
echo ✅ Deployment Complete!
echo.
echo 🌐 Website: http://%WEBSITE_BUCKET%.s3-website-%REGION%.amazonaws.com
echo 🔧 Server: http://%SERVER_URL%
echo 📦 Bucket: %WEBSITE_BUCKET%
echo.
echo 📝 Test URLs:
echo - Health: http://%SERVER_URL%/api/health
echo - Config: http://%SERVER_URL%/api/config
echo.

del website-policy.json
pause