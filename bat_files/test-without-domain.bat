@echo off
echo 🧪 Test Your Website Without Domain Migration

echo Getting CloudFront URL...
for /f "tokens=*" %%i in ('aws cloudfront list-distributions --query "DistributionList.Items[0].DomainName" --output text') do set CLOUDFRONT_URL=%%i

echo Getting S3 website URL...
echo S3 Website URL: http://codepode.in.s3-website-us-east-1.amazonaws.com

echo.
echo ✅ Your website is accessible at these URLs:
echo.
echo 🌐 CloudFront (Global CDN): https://%CLOUDFRONT_URL%
echo 🪣 S3 Direct: http://codepode.in.s3-website-us-east-1.amazonaws.com
echo.
echo 📝 Test these URLs to verify your website works before migrating domain
echo 💡 Contact form will work on both URLs

pause