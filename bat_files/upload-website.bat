@echo off
echo 🚀 Uploading CodePod Website to AWS

echo Uploading all website files to S3...
aws s3 sync . s3://codepode.in --exclude "*.bat" --exclude "*.sh" --exclude "*.yaml" --exclude "server/*" --exclude "*.md" --exclude "*.pdf" --exclude "*.zip" --exclude "*.js.map" --delete

echo.
echo Invalidating CloudFront cache...
for /f "tokens=*" %%i in ('aws cloudfront list-distributions --query "DistributionList.Items[0].Id" --output text') do set DISTRIBUTION_ID=%%i
aws cloudfront create-invalidation --distribution-id %DISTRIBUTION_ID% --paths "/*"

echo.
echo ✅ Website uploaded successfully!
echo 🌐 Your CodePod website is now live at: https://codepode.in
echo ⏱️ Cache invalidation in progress (1-2 minutes)

pause