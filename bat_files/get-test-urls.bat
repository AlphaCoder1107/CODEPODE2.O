@echo off
echo 🔍 Getting Test URLs

echo Getting CloudFront distribution...
aws cloudfront list-distributions --query "DistributionList.Items[0].DomainName" --output text > temp_cf.txt
set /p CLOUDFRONT_URL=<temp_cf.txt
del temp_cf.txt

echo.
echo 🧪 TEST THESE URLS:
echo.
echo 1. S3 Direct: http://codepode.in.s3-website-us-east-1.amazonaws.com
echo 2. CloudFront: https://%CLOUDFRONT_URL%
echo 3. Your Domain: https://codepode.in
echo.
echo 📋 Copy and paste these URLs into your browser:
echo http://codepode.in.s3-website-us-east-1.amazonaws.com
echo https://%CLOUDFRONT_URL%
echo.
echo 💡 Which one shows your CodePod website?

pause