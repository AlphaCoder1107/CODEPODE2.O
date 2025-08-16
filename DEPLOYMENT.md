# CodePod AWS Deployment Guide

## Quick Start

1. **Prerequisites**
   - AWS CLI installed and configured
   - Razorpay account with API keys

2. **Set Environment Variables**
   ```cmd
   set RAZORPAY_KEY_ID=your_key_id
   set RAZORPAY_KEY_SECRET=your_key_secret
   ```

3. **Deploy**
   ```cmd
   quick-deploy.bat
   ```

## Custom Deployment

1. **Full Deployment**
   ```cmd
   deploy-aws.bat
   ```

2. **Manual Steps**
   - Enter your domain name
   - Provide contact email
   - Enter Razorpay credentials
   - Wait for deployment (15-20 minutes)

## What Gets Deployed

- **Elastic Beanstalk**: Node.js server with payment processing
- **S3**: Static assets (HTML, CSS, JS, images)
- **CloudFront**: CDN for global distribution
- **Route 53**: DNS management (if domain provided)
- **Certificate Manager**: SSL certificates

## Post-Deployment

1. Update domain nameservers to Route 53
2. Verify SSL certificate
3. Test payment integration
4. Monitor application health

## Troubleshooting

- Check CloudFormation stack events in AWS Console
- View Elastic Beanstalk logs for server issues
- Verify environment variables are set correctly