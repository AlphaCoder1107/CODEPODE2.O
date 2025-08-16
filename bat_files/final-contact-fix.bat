@echo off
echo 🔧 Final Contact Form Fix

echo Getting API Gateway endpoint...
for /f "tokens=*" %%i in ('aws apigatewayv2 get-apis --query "Items[?Name=='codepod-contact-api'].ApiEndpoint" --output text') do set API_BASE=%%i

if "%API_BASE%"=="" (
    echo Creating API Gateway...
    for /f "tokens=*" %%i in ('aws apigatewayv2 create-api --name codepod-contact-api --protocol-type HTTP --cors-configuration AllowOrigins="*",AllowMethods="POST,OPTIONS",AllowHeaders="Content-Type" --query "ApiId" --output text') do set API_ID=%%i
    
    for /f "tokens=*" %%i in ('aws lambda get-function --function-name codepod-contact --query "Configuration.FunctionArn" --output text') do set LAMBDA_ARN=%%i
    for /f "tokens=*" %%i in ('aws apigatewayv2 create-integration --api-id %API_ID% --integration-type AWS_PROXY --integration-uri %LAMBDA_ARN% --payload-format-version "2.0" --query "IntegrationId" --output text') do set INTEGRATION_ID=%%i
    
    aws apigatewayv2 create-route --api-id %API_ID% --route-key "POST /contact" --target integrations/%INTEGRATION_ID%
    aws apigatewayv2 create-stage --api-id %API_ID% --stage-name prod --auto-deploy
    aws lambda add-permission --function-name codepod-contact --statement-id api-gateway-invoke --action lambda:InvokeFunction --principal apigateway.amazonaws.com --source-arn "arn:aws:execute-api:*:*:%API_ID%/*/*"
    
    for /f "tokens=*" %%i in ('aws apigatewayv2 get-api --api-id %API_ID% --query "ApiEndpoint" --output text') do set API_ENDPOINT=%%i/prod/contact
) else (
    set API_ENDPOINT=%API_BASE%/prod/contact
)

echo ✅ API Endpoint: %API_ENDPOINT%

echo Updating contact form...
powershell -Command "(Get-Content contact.html) -replace \"const ENDPOINT = '';\", \"const ENDPOINT = '%API_ENDPOINT%';\" | Set-Content contact.html"

echo Uploading updated contact form...
aws s3 cp contact.html s3://codepode.in/

echo Clearing cache...
for /f "tokens=*" %%i in ('aws cloudfront list-distributions --query "DistributionList.Items[0].Id" --output text') do set DIST_ID=%%i
aws cloudfront create-invalidation --distribution-id %DIST_ID% --paths "/contact.html"

echo ✅ Contact form is now working!
echo 🌐 Test at: https://codepode.in/contact.html

pause