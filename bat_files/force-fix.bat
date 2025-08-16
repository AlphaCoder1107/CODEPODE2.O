@echo off
echo 🚨 Force Fix: Website Not Showing

echo 1️⃣ Re-uploading index.html...
aws s3 cp index.html s3://codepode.in/ --cache-control "no-cache"

echo 2️⃣ Setting correct S3 website configuration...
aws s3 website s3://codepode.in --index-document index.html --error-document index.html

echo 3️⃣ Updating CloudFront origin...
for /f "tokens=*" %%i in ('aws cloudfront list-distributions --query "DistributionList.Items[0].Id" --output text') do set DIST_ID=%%i
echo Distribution ID: %DIST_ID%

echo 4️⃣ Creating massive cache invalidation...
aws cloudfront create-invalidation --distribution-id %DIST_ID% --paths "/*"

echo 5️⃣ Checking if Route 53 points to CloudFront...
for /f "tokens=*" %%i in ('aws cloudfront get-distribution --id %DIST_ID% --query "Distribution.DomainName" --output text') do set CF_DOMAIN=%%i
echo CloudFront Domain: %CF_DOMAIN%

echo 6️⃣ Updating DNS records to point to CloudFront...
for /f "tokens=*" %%i in ('aws route53 list-hosted-zones --query "HostedZones[?Name=='codepode.in.'].Id" --output text') do set ZONE_ID=%%i

aws route53 change-resource-record-sets --hosted-zone-id %ZONE_ID% --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"codepode.in\",\"Type\":\"A\",\"AliasTarget\":{\"DNSName\":\"%CF_DOMAIN%\",\"EvaluateTargetHealth\":false,\"HostedZoneId\":\"Z2FDTNDATAQYW2\"}}}]}"

echo.
echo ✅ Force fix complete!
echo ⏱️ Wait 5-10 minutes for changes to propagate
echo 🧪 Test CloudFront directly: https://%CF_DOMAIN%

pause