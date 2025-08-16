@echo off
echo 🚀 Quick Upload: CodePod to AWS

echo 1️⃣ Uploading website files...
aws s3 cp index.html s3://codepode.in/
aws s3 cp contact.html s3://codepode.in/
aws s3 cp cart.html s3://codepode.in/
aws s3 cp footer.html s3://codepode.in/
aws s3 cp pi_2W.html s3://codepode.in/
aws s3 cp pi3_W.html s3://codepode.in/
aws s3 cp pi3-modelbplus.html s3://codepode.in/

echo 2️⃣ Uploading assets...
aws s3 sync assets/ s3://codepode.in/assets/ --delete

echo 3️⃣ Uploading images...
aws s3 sync pi_2W/ s3://codepode.in/pi_2W/ --delete
aws s3 sync pi_3B/ s3://codepode.in/pi_3B/ --delete

echo 4️⃣ Clearing CloudFront cache...
for /f "tokens=*" %%i in ('aws cloudfront list-distributions --query "DistributionList.Items[0].Id" --output text') do set DIST_ID=%%i
aws cloudfront create-invalidation --distribution-id %DIST_ID% --paths "/*"

echo.
echo ✅ Upload complete!
echo 🌐 Visit: https://codepode.in
echo ⏱️ Changes visible in 1-2 minutes

pause