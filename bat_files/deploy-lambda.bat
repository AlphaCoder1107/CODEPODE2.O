@echo off
echo 🚀 Deploying Contact Form Lambda Function

set /p DOMAIN="Enter your domain (e.g., codepod.com): "
set /p EMAIL="Enter your email for contact form submissions: "

echo Creating Lambda function...

:: Create deployment package
echo const AWS = require('aws-sdk'); > lambda-function.js
echo const ses = new AWS.SES({ region: 'us-east-1' }); >> lambda-function.js
echo. >> lambda-function.js
echo exports.handler = async (event) =^> { >> lambda-function.js
echo     const headers = { >> lambda-function.js
echo         'Access-Control-Allow-Origin': '*', >> lambda-function.js
echo         'Access-Control-Allow-Headers': 'Content-Type', >> lambda-function.js
echo         'Access-Control-Allow-Methods': 'POST, OPTIONS' >> lambda-function.js
echo     }; >> lambda-function.js
echo. >> lambda-function.js
echo     if (event.httpMethod === 'OPTIONS') { >> lambda-function.js
echo         return { statusCode: 200, headers }; >> lambda-function.js
echo     } >> lambda-function.js
echo. >> lambda-function.js
echo     try { >> lambda-function.js
echo         const data = JSON.parse(event.body); >> lambda-function.js
echo         const emailParams = { >> lambda-function.js
echo             Source: 'noreply@%DOMAIN%', >> lambda-function.js
echo             Destination: { ToAddresses: ['%EMAIL%'] }, >> lambda-function.js
echo             Message: { >> lambda-function.js
echo                 Subject: { Data: `New Contact: ${data.companyName}` }, >> lambda-function.js
echo                 Body: { Text: { Data: `Company: ${data.companyName}\nContact: ${data.contactName}\nEmail: ${data.email}\nPhone: ${data.phone}\nMessage: ${data.message}` } } >> lambda-function.js
echo             } >> lambda-function.js
echo         }; >> lambda-function.js
echo         await ses.sendEmail(emailParams).promise(); >> lambda-function.js
echo         return { statusCode: 200, headers, body: JSON.stringify({ message: 'Success' }) }; >> lambda-function.js
echo     } catch (error) { >> lambda-function.js
echo         return { statusCode: 500, headers, body: JSON.stringify({ message: 'Error' }) }; >> lambda-function.js
echo     } >> lambda-function.js
echo }; >> lambda-function.js

:: Create Lambda function
aws lambda create-function ^
    --function-name codepod-contact ^
    --runtime nodejs18.x ^
    --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/lambda-execution-role ^
    --handler lambda-function.handler ^
    --zip-file fileb://lambda-function.zip

:: Create API Gateway
aws apigatewayv2 create-api ^
    --name codepod-contact-api ^
    --protocol-type HTTP ^
    --cors-configuration AllowOrigins="*",AllowMethods="POST,OPTIONS",AllowHeaders="Content-Type"

echo ✅ Lambda function created!
echo 📝 Next: Run setup-api-gateway.bat

pause