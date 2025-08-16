@echo off
echo 🌐 Final Domain Setup - Connecting codepode.in to S3

echo 1️⃣ Getting CloudFront distribution...
for /f "tokens=*" %%i in ('aws cloudfront list-distributions --query "DistributionList.Items[0].DomainName" --output text') do set CF_DOMAIN=%%i

if "%CF_DOMAIN%"=="" (
    echo No CloudFront found. Creating distribution...
    echo This may take 10-15 minutes...
    aws cloudfront create-distribution --distribution-config file://cloudfront-config.json
) else (
    echo Found CloudFront: %CF_DOMAIN%
)

echo 2️⃣ Setting up Route 53 DNS records...
for /f "tokens=*" %%i in ('aws route53 list-hosted-zones --query "HostedZones[?Name=='codepode.in.'].Id" --output text') do set ZONE_ID=%%i

echo Creating A record for codepode.in...
aws route53 change-resource-record-sets --hosted-zone-id %ZONE_ID% --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"codepode.in\",\"Type\":\"A\",\"AliasTarget\":{\"DNSName\":\"%CF_DOMAIN%\",\"EvaluateTargetHealth\":false,\"HostedZoneId\":\"Z2FDTNDATAQYW2\"}}}]}"

echo Creating A record for www.codepode.in...
aws route53 change-resource-record-sets --hosted-zone-id %ZONE_ID% --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"www.codepode.in\",\"Type\":\"A\",\"AliasTarget\":{\"DNSName\":\"%CF_DOMAIN%\",\"EvaluateTargetHealth\":false,\"HostedZoneId\":\"Z2FDTNDATAQYW2\"}}}]}"

echo 3️⃣ Invalidating CloudFront cache...
for /f "tokens=*" %%i in ('aws cloudfront list-distributions --query "DistributionList.Items[0].Id" --output text') do set DIST_ID=%%i
aws cloudfront create-invalidation --distribution-id %DIST_ID% --paths "/*"

echo.
echo ✅ Domain setup complete!
echo 🌐 Your website should be live at: https://codepode.in
echo ⏱️ DNS changes may take 5-10 minutes to propagate

pause