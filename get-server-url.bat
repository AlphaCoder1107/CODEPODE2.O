@echo off
echo 🔍 Getting Server URL

echo Checking environment status...
aws elasticbeanstalk describe-environments --environment-names codepod-prod --query "Environments[0].[EnvironmentName,Status,Health,CNAME]" --output table

echo.
echo Getting server URL...
for /f "tokens=*" %%i in ('aws elasticbeanstalk describe-environments --environment-names codepod-prod --query "Environments[0].CNAME" --output text') do set SERVER_URL=%%i

echo.
echo ✅ Server URL: http://%SERVER_URL%
echo.
echo 🧪 Testing server:
curl -s http://%SERVER_URL%/api/health
echo.
echo.
echo 📝 Your URLs:
echo Website: http://codepode.in-website.s3-website-us-east-1.amazonaws.com
echo Server: http://%SERVER_URL%
pause