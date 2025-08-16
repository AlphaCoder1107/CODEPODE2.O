@echo off
echo 🚨 FIXING: S3 Bucket Missing - Creating and Uploading

echo 1️⃣ Creating S3 bucket...
aws s3 mb s3://codepode.in --region us-east-1

echo 2️⃣ Configuring bucket for website hosting...
aws s3 website s3://codepode.in --index-document index.html --error-document index.html

echo 3️⃣ Setting bucket policy for public access...
echo {
echo   "Version": "2012-10-17",
echo   "Statement": [
echo     {
echo       "Sid": "PublicReadGetObject",
echo       "Effect": "Allow",
echo       "Principal": "*",
echo       "Action": "s3:GetObject",
echo       "Resource": "arn:aws:s3:::codepode.in/*"
echo     }
echo   ]
echo } > bucket-policy.json

aws s3api put-bucket-policy --bucket codepode.in --policy file://bucket-policy.json

echo 4️⃣ Uploading all website files...
aws s3 sync . s3://codepode.in --exclude "*.bat" --exclude "*.sh" --exclude "*.yaml" --exclude "server/*" --exclude "*.md" --exclude "*.pdf" --exclude "*.json" --delete

echo 5️⃣ Testing S3 website...
echo S3 Website URL: http://codepode.in.s3-website-us-east-1.amazonaws.com

echo 6️⃣ Clearing CloudFront cache...
for /f "tokens=*" %%i in ('aws cloudfront list-distributions --query "DistributionList.Items[0].Id" --output text') do set DIST_ID=%%i
if not "%DIST_ID%"=="" (
    aws cloudfront create-invalidation --distribution-id %DIST_ID% --paths "/*"
)

echo.
echo ✅ Bucket created and website uploaded!
echo 🧪 Test S3 URL: http://codepode.in.s3-website-us-east-1.amazonaws.com
echo 🌐 Your domain: https://codepode.in (wait 2-3 minutes)

del bucket-policy.json

pause