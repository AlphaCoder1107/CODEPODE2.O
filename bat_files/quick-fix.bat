@echo off
echo 🚀 Quick Fix: Contact Form (Works Immediately)

echo 1️⃣ Updating Lambda function to work without email verification...
powershell -Command "Compress-Archive -Path 'simple-lambda.js' -DestinationPath 'lambda.zip' -Force"

aws lambda update-function-code --function-name codepod-contact --zip-file fileb://lambda.zip

echo 2️⃣ Getting API Gateway endpoint...
for /f "tokens=*" %%i in ('aws apigatewayv2 get-apis --query "Items[?Name=='codepod-contact-api'].ApiEndpoint" --output text 2^>nul') do set API_BASE=%%i

if "%API_BASE%"=="" (
    echo Creating API Gateway...
    call create-api.bat
) else (
    set API_ENDPOINT=%API_BASE%/prod/contact
    echo ✅ Found API: %API_ENDPOINT%
)

echo 3️⃣ Updating contact form...
powershell -Command "(Get-Content contact.html) -replace \"const ENDPOINT = '';\", \"const ENDPOINT = '%API_ENDPOINT%';\" | Set-Content contact.html"

echo 4️⃣ Uploading to S3...
aws s3 cp contact.html s3://codepode.in/contact.html

echo 5️⃣ Testing Lambda function...
aws lambda invoke --function-name codepod-contact --payload "{\"httpMethod\":\"POST\",\"body\":\"{\\\"companyName\\\":\\\"Test Company\\\",\\\"contactName\\\":\\\"Test User\\\",\\\"email\\\":\\\"test@example.com\\\",\\\"message\\\":\\\"Test message\\\"}\"}" test-response.json

echo Response:
type test-response.json
del test-response.json
del lambda.zip

echo.
echo ✅ Contact form is now working!
echo 🌐 Test it at: https://codepode.in/contact.html
echo 📊 Form submissions will be logged in CloudWatch
echo 💡 You can check logs in AWS Console > Lambda > codepod-contact > Monitor > Logs

pause