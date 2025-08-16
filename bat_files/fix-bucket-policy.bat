@echo off
echo 🔧 Fixing S3 Bucket Policy

echo Creating proper bucket policy JSON...
echo {"Version":"2012-10-17","Statement":[{"Sid":"PublicReadGetObject","Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::codepode.in/*"}]} > policy.json

echo Applying bucket policy...
aws s3api put-bucket-policy --bucket codepode.in --policy file://policy.json

echo Making bucket public via console method...
aws s3api put-public-access-block --bucket codepode.in --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

echo ✅ Bucket policy fixed!
echo 🧪 Test your website: http://codepode.in.s3-website-us-east-1.amazonaws.com

del policy.json
pause