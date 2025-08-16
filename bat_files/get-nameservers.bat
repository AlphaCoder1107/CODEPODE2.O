@echo off
echo 🌐 Getting AWS Route 53 Nameservers for codepode.in

echo Checking if hosted zone exists...
for /f "tokens=*" %%i in ('aws route53 list-hosted-zones --query "HostedZones[?Name=='codepode.in.'].Id" --output text') do set ZONE_ID=%%i

if "%ZONE_ID%"=="" (
    echo Creating Route 53 hosted zone...
    for /f "tokens=*" %%i in ('aws route53 create-hosted-zone --name codepode.in --caller-reference %RANDOM% --query "HostedZone.Id" --output text') do set ZONE_ID=%%i
)

echo Zone ID: %ZONE_ID%

echo Getting nameservers...
aws route53 get-hosted-zone --id %ZONE_ID% --query "DelegationSet.NameServers" --output table

echo.
echo ✅ Copy these 4 nameservers and update them in Hostinger
echo 📝 Next: Go to Hostinger domain management and replace nameservers

pause