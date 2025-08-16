@echo off
echo 🔧 Fixing AWS CLI Configuration

echo Reconfiguring AWS CLI with correct region...
aws configure set region us-east-1
aws configure set output json

echo Testing AWS connection...
aws sts get-caller-identity

echo Creating S3 bucket with explicit region...
aws s3 mb s3://codepode.in --region us-east-1

echo Uploading index.html...
aws s3 cp index.html s3://codepode.in/ --region us-east-1

echo Setting website configuration...
aws s3 website s3://codepode.in --index-document index.html --error-document index.html

echo Uploading all files...
aws s3 sync . s3://codepode.in --exclude "*.bat" --exclude "server/*" --exclude "*.md" --exclude "*.pdf" --region us-east-1

echo Setting bucket policy...
echo {
echo   "Version": "2012-10-17",
echo   "Statement": [
echo     {
echo       "Sid": "PublicReadGetObject",
echo       "Effect": "Allow",
echo       "Principal": "*",
echo       "Action": "s3:GetObject",
echo       "Resource": "arn:aws:s3:::codepode.in/*"
echo     }
echo   ]
echo } > bucket-policy.json

aws s3api put-bucket-policy --bucket codepode.in --policy file://bucket-policy.json --region us-east-1

echo ✅ Fixed! Test URL: http://codepode.in.s3-website-us-east-1.amazonaws.com

del bucket-policy.json
pause