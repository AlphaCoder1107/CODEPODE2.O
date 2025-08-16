@echo off
echo 🚀 Full AWS Deployment with Manual Steps

set DOMAIN=codepode.in
set EMAIL=codepode2424@gmail.com
set RAZORPAY_KEY_ID=rzp_test_R5XmEfkjyyHrMQ
set RAZORPAY_KEY_SECRET=dCJ1EXoJzEPHxbfQlKRLHW7y
set WEBHOOK_SECRET=0f3b2a8e9c6d4f1a2b3c4d5e6f708192a1b2c3d4e5f60718293a4c5b6d7e8f90
set REGION=us-east-1

echo Domain: %DOMAIN%
echo Region: %REGION%
echo.

echo 1️⃣ Preparing deployment packages...
call prepare-deployment.bat

echo.
echo 2️⃣ Creating S3 bucket for website...
set WEBSITE_BUCKET=%DOMAIN%-website
aws s3 mb s3://%WEBSITE_BUCKET% --region %REGION%
aws s3 website s3://%WEBSITE_BUCKET% --index-document index.html

echo.
echo 3️⃣ Setting bucket policy...
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
echo 4️⃣ Uploading website files...
aws s3 sync deployment\static s3://%WEBSITE_BUCKET% --delete

echo.
echo 5️⃣ Creating Elastic Beanstalk application...
aws elasticbeanstalk create-application --application-name codepod-app --description "CodePod Payment Server"

echo.
echo 6️⃣ Creating EB environment...
aws elasticbeanstalk create-environment ^
    --application-name codepod-app ^
    --environment-name codepod-prod ^
    --solution-stack-name "64bit Amazon Linux 2 v5.8.4 running Node.js 18" ^
    --option-settings ^
        Namespace=aws:elasticbeanstalk:application:environment,OptionName=RAZORPAY_KEY_ID,Value=%RAZORPAY_KEY_ID% ^
        Namespace=aws:elasticbeanstalk:application:environment,OptionName=RAZORPAY_KEY_SECRET,Value=%RAZORPAY_KEY_SECRET% ^
        Namespace=aws:elasticbeanstalk:application:environment,OptionName=WEBHOOK_SECRET,Value=%WEBHOOK_SECRET% ^
        Namespace=aws:elasticbeanstalk:application:environment,OptionName=NODE_ENV,Value=production ^
        Namespace=aws:autoscaling:launchconfiguration,OptionName=InstanceType,Value=t3.micro

echo.
echo 7️⃣ Waiting for environment to be ready...
aws elasticbeanstalk wait environment-ready --environment-name codepod-prod

echo.
echo 8️⃣ Deploying server code...
aws elasticbeanstalk create-application-version ^
    --application-name codepod-app ^
    --version-label v1.0 ^
    --source-bundle S3Bucket=%WEBSITE_BUCKET%,S3Key=server-deployment.zip

aws s3 cp deployment\server-deployment.zip s3://%WEBSITE_BUCKET%/server-deployment.zip

aws elasticbeanstalk update-environment ^
    --environment-name codepod-prod ^
    --version-label v1.0

echo.
echo 9️⃣ Getting environment URL...
for /f "tokens=*" %%i in ('aws elasticbeanstalk describe-environments --environment-names codepod-prod --query "Environments[0].CNAME" --output text') do set SERVER_URL=%%i

echo.
echo ✅ Deployment Complete!
echo.
echo 🌐 Website: http://%WEBSITE_BUCKET%.s3-website-%REGION%.amazonaws.com
echo 🔧 Server: http://%SERVER_URL%
echo 📦 Bucket: %WEBSITE_BUCKET%
echo.
echo 📝 Testing URLs:
echo - Health: http://%SERVER_URL%/api/health
echo - Config: http://%SERVER_URL%/api/config
echo - Cart: http://%SERVER_URL%/cart.html
echo.

del website-policy.json
pause