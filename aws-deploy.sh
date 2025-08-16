#!/bin/bash

# AWS Deployment Script for CodePod Website
# Replace YOUR_DOMAIN with your actual domain name

DOMAIN="YOUR_DOMAIN.com"
BUCKET_NAME="$DOMAIN"
REGION="us-east-1"

echo "🚀 Deploying CodePod to AWS..."

# 1. Create S3 bucket for website hosting
aws s3 mb s3://$BUCKET_NAME --region $REGION

# 2. Configure bucket for static website hosting
aws s3 website s3://$BUCKET_NAME --index-document index.html --error-document index.html

# 3. Upload website files
aws s3 sync . s3://$BUCKET_NAME --exclude "*.sh" --exclude "server/*" --exclude "*.md" --exclude "*.pdf" --delete

# 4. Set bucket policy for public read access
cat > bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://bucket-policy.json

echo "✅ S3 bucket configured successfully!"
echo "📝 Next steps:"
echo "1. Create CloudFront distribution"
echo "2. Configure Route 53 for your domain"
echo "3. Set up SSL certificate"

# Clean up
rm bucket-policy.json