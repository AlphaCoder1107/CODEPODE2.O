@echo off
echo 🚨 Emergency Fix - Force Website to Show

echo 1️⃣ Checking S3 bucket...
aws s3 ls s3://codepode.in/

echo.
echo 2️⃣ Re-uploading index.html with force...
aws s3 cp index.html s3://codepode.in/index.html --cache-control "no-cache, no-store, must-revalidate"

echo.
echo 3️⃣ Setting S3 bucket policy...
aws s3api put-bucket-policy --bucket codepode.in --policy "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"PublicReadGetObject\",\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::codepode.in/*\"}]}"

echo.
echo 4️⃣ Configuring S3 website hosting...
aws s3 website s3://codepode.in --index-document index.html --error-document index.html

echo.
echo 5️⃣ Testing S3 direct access...
echo Test this URL: http://codepode.in.s3-website-us-east-1.amazonaws.com
echo.

echo 6️⃣ Invalidating all CloudFront cache...
for /f "tokens=*" %%i in ('aws cloudfront list-distributions --query "DistributionList.Items[0].Id" --output text') do set DIST_ID=%%i
aws cloudfront create-invalidation --distribution-id %DIST_ID% --paths "/*"

echo.
echo ✅ Emergency fix complete!
echo 🧪 Test S3 URL: http://codepode.in.s3-website-us-east-1.amazonaws.com
echo ⏱️ Wait 2-3 minutes for CloudFront cache to clear

pause