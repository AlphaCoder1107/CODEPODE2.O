@echo off
echo 🔧 Setting up DNS records for codepode.in

echo Getting CloudFront distribution domain...
for /f "tokens=*" %%i in ('aws cloudfront list-distributions --query "DistributionList.Items[0].DomainName" --output text') do set CLOUDFRONT_DOMAIN=%%i

echo CloudFront Domain: %CLOUDFRONT_DOMAIN%

echo Getting hosted zone ID...
for /f "tokens=*" %%i in ('aws route53 list-hosted-zones --query "HostedZones[?Name=='codepode.in.'].Id" --output text') do set ZONE_ID=%%i

echo Creating DNS records...

:: Create A record for root domain
echo Creating A record for codepode.in...
aws route53 change-resource-record-sets --hosted-zone-id %ZONE_ID% --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"codepode.in\",\"Type\":\"A\",\"AliasTarget\":{\"DNSName\":\"%CLOUDFRONT_DOMAIN%\",\"EvaluateTargetHealth\":false,\"HostedZoneId\":\"Z2FDTNDATAQYW2\"}}}]}"

:: Create A record for www subdomain
echo Creating A record for www.codepode.in...
aws route53 change-resource-record-sets --hosted-zone-id %ZONE_ID% --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"www.codepode.in\",\"Type\":\"A\",\"AliasTarget\":{\"DNSName\":\"%CLOUDFRONT_DOMAIN%\",\"EvaluateTargetHealth\":false,\"HostedZoneId\":\"Z2FDTNDATAQYW2\"}}}]}"

echo ✅ DNS records created!
echo 📝 After updating nameservers in Hostinger, your site will be live at:
echo   - https://codepode.in
echo   - https://www.codepode.in

pause