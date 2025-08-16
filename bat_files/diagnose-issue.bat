@echo off
echo 🔍 Diagnosing Website Issue

echo 1️⃣ Checking DNS resolution...
nslookup codepode.in

echo.
echo 2️⃣ Checking S3 bucket contents...
aws s3 ls s3://codepode.in/

echo.
echo 3️⃣ Getting CloudFront distribution URL...
for /f "tokens=*" %%i in ('aws cloudfront list-distributions --query "DistributionList.Items[0].DomainName" --output text') do set CLOUDFRONT_URL=%%i
echo CloudFront URL: https://%CLOUDFRONT_URL%

echo.
echo 4️⃣ Checking Route 53 records...
for /f "tokens=*" %%i in ('aws route53 list-hosted-zones --query "HostedZones[?Name=='codepode.in.'].Id" --output text') do set ZONE_ID=%%i
aws route53 list-resource-record-sets --hosted-zone-id %ZONE_ID% --query "ResourceRecordSets[?Type=='A']"

echo.
echo 🧪 Test URLs:
echo Direct S3: http://codepode.in.s3-website-us-east-1.amazonaws.com
echo CloudFront: https://%CLOUDFRONT_URL%
echo Domain: https://codepode.in

pause