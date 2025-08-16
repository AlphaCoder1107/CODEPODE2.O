@echo off
echo 🧪 Quick Test: Alternative URLs

echo Getting CloudFront URL...
for /f "tokens=*" %%i in ('aws cloudfront list-distributions --query "DistributionList.Items[0].DomainName" --output text') do set CLOUDFRONT_URL=%%i

echo.
echo 🌐 Test these URLs in your browser:
echo.
echo 1. CloudFront (should work): https://%CLOUDFRONT_URL%
echo 2. S3 Direct (should work): http://codepode.in.s3-website-us-east-1.amazonaws.com  
echo 3. Your domain (might be cached): https://codepode.in
echo.
echo 💡 If CloudFront URL shows your site, the issue is DNS caching
echo 💡 If S3 URL shows your site, CloudFront needs time to update
echo 💡 If neither works, files weren't uploaded correctly

echo.
echo 🔄 Clear your browser cache and try again
echo 🌍 Or test from different device/network

pause