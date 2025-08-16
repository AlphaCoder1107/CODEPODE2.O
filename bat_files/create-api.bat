@echo off
echo 🔧 Creating API Gateway for contact form...

echo 1️⃣ Creating HTTP API...
for /f "tokens=*" %%i in ('aws apigatewayv2 create-api --name codepod-contact-api --protocol-type HTTP --cors-configuration AllowOrigins="*",AllowMethods="POST,OPTIONS",AllowHeaders="Content-Type" --query "ApiId" --output text') do set API_ID=%%i

echo API ID: %API_ID%

echo 2️⃣ Creating Lambda integration...
for /f "tokens=*" %%i in ('aws lambda get-function --function-name codepod-contact --query "Configuration.FunctionArn" --output text') do set LAMBDA_ARN=%%i

for /f "tokens=*" %%i in ('aws apigatewayv2 create-integration --api-id %API_ID% --integration-type AWS_PROXY --integration-uri %LAMBDA_ARN% --payload-format-version "2.0" --query "IntegrationId" --output text') do set INTEGRATION_ID=%%i

echo 3️⃣ Creating route...
aws apigatewayv2 create-route --api-id %API_ID% --route-key "POST /contact" --target integrations/%INTEGRATION_ID%

echo 4️⃣ Creating stage...
aws apigatewayv2 create-stage --api-id %API_ID% --stage-name prod --auto-deploy

echo 5️⃣ Adding Lambda permission...
aws lambda add-permission --function-name codepod-contact --statement-id api-gateway-invoke --action lambda:InvokeFunction --principal apigateway.amazonaws.com --source-arn "arn:aws:execute-api:us-east-1:*:%API_ID%/*/*"

echo 6️⃣ Getting API endpoint...
for /f "tokens=*" %%i in ('aws apigatewayv2 get-api --api-id %API_ID% --query "ApiEndpoint" --output text') do set API_ENDPOINT=%%i/prod/contact

echo ✅ API Gateway created!
echo 📍 Endpoint: %API_ENDPOINT%

echo 7️⃣ Updating contact form...
powershell -Command "(Get-Content contact.html) -replace \"const ENDPOINT = '';\", \"const ENDPOINT = '%API_ENDPOINT%';\" | Set-Content contact.html"

echo 8️⃣ Uploading updated contact form...
aws s3 cp contact.html s3://codepode.in/contact.html

echo ✅ Contact form is now ready!

pause