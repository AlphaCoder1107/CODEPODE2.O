# CodePod AWS Deployment Guide

## Quick Setup (5 minutes)

### Prerequisites
- AWS CLI installed and configured
- Your domain name ready

### Step 1: Deploy Everything
```bash
deploy.bat
```
Enter your domain and email when prompted.

### Step 2: Verify Email
```bash
verify-email.bat
```
Check your email and click verification link.

### Step 3: Update Domain DNS
Point your domain to Route 53 nameservers (provided in AWS console).

## What Gets Created

- **S3 Bucket**: Static website hosting
- **CloudFront**: Global CDN with SSL
- **Lambda Function**: Contact form backend
- **API Gateway**: REST endpoint for contact form
- **SES**: Email service for contact form
- **Route 53**: DNS management
- **Certificate Manager**: Free SSL certificate

## Testing

1. Visit `https://yourdomain.com`
2. Test contact form at `https://yourdomain.com/contact.html`
3. Check email delivery

## Costs (Monthly)
- S3: $1-5
- CloudFront: $1-10  
- Lambda: ~$0 (free tier)
- API Gateway: ~$0 (free tier)
- SES: $0.10 per 1000 emails
- Route 53: $0.50 per hosted zone

## Troubleshooting

**Contact form not working?**
- Verify email address in SES console
- Check API Gateway endpoint URL
- Ensure CORS is enabled

**SSL certificate pending?**
- Add DNS validation records in Route 53
- Wait 5-10 minutes for validation

**Website not loading?**
- Check CloudFront distribution status
- Verify S3 bucket policy
- Confirm DNS propagation