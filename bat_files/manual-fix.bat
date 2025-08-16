@echo off
echo 🔧 Manual Fix: Creating S3 Bucket Step by Step

echo Step 1: Creating S3 bucket...
aws s3 mb s3://codepode.in

echo Step 2: Uploading index.html...
aws s3 cp index.html s3://codepode.in/

echo Step 3: Making bucket public...
aws s3api put-bucket-acl --bucket codepode.in --acl public-read

echo Step 4: Setting website configuration...
aws s3 website s3://codepode.in --index-document index.html

echo Step 5: Uploading all files...
aws s3 sync . s3://codepode.in --exclude "*.bat" --exclude "server/*" --exclude "*.md" --exclude "*.pdf"

echo.
echo ✅ Done! Test this URL:
echo http://codepode.in.s3-website-us-east-1.amazonaws.com

pause