@echo off
echo 🚀 CodePod AWS Deployment with Contact Form
echo.

set /p DOMAIN="Enter your domain name (e.g., codepod.com): "
set /p EMAIL="Enter your email for contact form: "
set STACK_NAME=codepod-website

echo.
echo 📋 Deployment Summary:
echo Domain: %DOMAIN%
echo Email: %EMAIL%
echo Stack: %STACK_NAME%
echo.

pause

echo 1️⃣ Creating complete infrastructure...
aws cloudformation create-stack ^
    --stack-name %STACK_NAME% ^
    --template-body file://complete-infrastructure.yaml ^
    --parameters ParameterKey=DomainName,ParameterValue=%DOMAIN% ParameterKey=ContactEmail,ParameterValue=%EMAIL% ^
    --capabilities CAPABILITY_IAM

echo.
echo 2️⃣ Waiting for stack creation (10-15 minutes)...
aws cloudformation wait stack-create-complete --stack-name %STACK_NAME%

echo.
echo 3️⃣ Getting API endpoint...
for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --query "Stacks[0].Outputs[?OutputKey=='APIEndpoint'].OutputValue" --output text') do set API_ENDPOINT=%%i

echo.
echo 4️⃣ Updating contact form with API endpoint...
powershell -Command "(Get-Content contact.html) -replace 'https://YOUR_API_GATEWAY_URL/contact', '%API_ENDPOINT%' | Set-Content contact.html"

echo.
echo 5️⃣ Uploading website files...
aws s3 sync . s3://%DOMAIN% --exclude "*.bat" --exclude "*.yaml" --exclude "server/*" --exclude "*.md" --exclude "*.pdf" --delete

echo.
echo ✅ Deployment complete!
echo 🌐 Website: https://%DOMAIN%
echo 📧 Contact form endpoint: %API_ENDPOINT%
echo.
echo 📝 Next steps:
echo 1. Verify SES email address: %EMAIL%
echo 2. Update domain nameservers to Route 53
echo 3. Test contact form

pause