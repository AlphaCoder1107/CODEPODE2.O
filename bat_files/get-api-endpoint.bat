@echo off
echo 🔍 Getting API Gateway endpoint...

set STACK_NAME=codepod-website

echo Retrieving API endpoint from CloudFormation stack...
for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --query "Stacks[0].Outputs[?OutputKey=='APIEndpoint'].OutputValue" --output text 2^>nul') do set API_ENDPOINT=%%i

if "%API_ENDPOINT%"=="" (
    echo ❌ API endpoint not found. Checking API Gateway directly...
    for /f "tokens=*" %%i in ('aws apigatewayv2 get-apis --query "Items[?Name=='codepod-contact-api'].ApiEndpoint" --output text 2^>nul') do set API_BASE=%%i
    if not "%API_BASE%"=="" (
        set API_ENDPOINT=%API_BASE%/prod/contact
    )
)

if "%API_ENDPOINT%"=="" (
    echo ❌ No API Gateway found. Creating one...
    call create-api.bat
) else (
    echo ✅ API Endpoint: %API_ENDPOINT%
    echo.
    echo 📝 Updating contact form...
    powershell -Command "(Get-Content contact.html) -replace \"const ENDPOINT = '';\", \"const ENDPOINT = '%API_ENDPOINT%';\" | Set-Content contact.html"
    
    echo.
    echo 📤 Re-uploading contact.html...
    aws s3 cp contact.html s3://codepode.in/contact.html
    
    echo.
    echo ✅ Contact form updated with API endpoint!
    echo 🌐 Test at: https://codepode.in/contact.html
)

pause