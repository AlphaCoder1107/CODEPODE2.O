@echo off
echo 🔄 Alternative Contact Form Setup (No SES Required)

echo Creating contact form that works without email verification...

echo 1️⃣ Updating Lambda to use SNS instead of SES...
aws lambda update-function-code --function-name codepod-contact --zip-file fileb://lambda-sns.zip

echo 2️⃣ Getting API endpoint...
for /f "tokens=*" %%i in ('aws apigatewayv2 get-apis --query "Items[?Name=='codepod-contact-api'].ApiEndpoint" --output text 2^>nul') do set API_BASE=%%i
if not "%API_BASE%"=="" (
    set API_ENDPOINT=%API_BASE%/prod/contact
    echo ✅ API Endpoint: %API_ENDPOINT%
    
    echo 3️⃣ Updating contact form...
    powershell -Command "(Get-Content contact.html) -replace \"const ENDPOINT = '';\", \"const ENDPOINT = '%API_ENDPOINT%';\" | Set-Content contact.html"
    
    echo 4️⃣ Uploading updated contact form...
    aws s3 cp contact.html s3://codepode.in/contact.html
    
    echo ✅ Contact form updated and working!
    echo 🌐 Test at: https://codepode.in/contact.html
) else (
    echo ❌ API Gateway not found. Run create-api.bat first.
)

pause