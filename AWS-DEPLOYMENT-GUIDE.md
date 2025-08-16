# CodePod AWS Deployment Guide

## Overview
This guide will help you deploy your CodePod website to AWS while keeping your server on Railway.

## Architecture
- **Frontend**: AWS S3 + CloudFront (static hosting)
- **Backend**: Railway (already deployed)
- **Payment**: Razorpay integration via Railway server

## Prerequisites

1. **AWS Account**: Sign up at https://aws.amazon.com
2. **AWS CLI**: Download and install from https://aws.amazon.com/cli/
3. **Railway Server**: Your server should already be deployed and running

## Step 1: Configure AWS CLI

```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key  
- Default region: `us-east-1`
- Default output format: `json`

## Step 2: Get Your Railway Server URL

1. Go to your Railway dashboard
2. Find your deployed server
3. Copy the public URL (e.g., `https://your-app.railway.app`)

## Step 3: Update Frontend Configuration

Run the configuration update script:

```bash
update-config.bat
```

Enter your Railway server URL when prompted.

## Step 4: Deploy to AWS

Run the deployment script:

```bash
deploy-to-aws.bat
```

You'll need to provide:
- **S3 Bucket Name**: Choose a unique name (e.g., `my-codepod-website-2024`)
- **Railway URL**: Your server URL from Step 2

## Step 5: Test Your Deployment

1. The script will output your website URL
2. Visit the URL to test your site
3. Try adding items to cart and checkout to verify Razorpay integration

## Step 6: Optional - Add Custom Domain

### Using Route 53 (Recommended)

1. Go to AWS Route 53 console
2. Create a hosted zone for your domain
3. Update your domain's nameservers
4. Create an A record pointing to your S3 website endpoint

### Using CloudFront (For HTTPS)

1. Create a CloudFront distribution
2. Set origin to your S3 bucket
3. Configure SSL certificate
4. Update DNS to point to CloudFront

## Troubleshooting

### Common Issues

1. **Bucket name already exists**: Choose a different, unique bucket name
2. **AWS CLI not found**: Install AWS CLI and restart command prompt
3. **Permission denied**: Check your AWS credentials and permissions
4. **CORS errors**: Ensure your Railway server has CORS configured for your domain

### Railway Server CORS Configuration

Add this to your Railway server's `index.js`:

```javascript
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', 'https://your-bucket-name.s3-website-us-east-1.amazonaws.com');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});
```

## Cost Estimation

### AWS S3
- Storage: ~$0.023 per GB/month
- Requests: ~$0.0004 per 1,000 requests
- Data transfer: First 1GB free, then ~$0.09 per GB

### CloudFront (Optional)
- First 1TB: $0.085 per GB
- Requests: $0.0075 per 10,000 requests

**Estimated monthly cost for small website**: $1-5 USD

## Security Best Practices

1. **Enable S3 bucket versioning**
2. **Use CloudFront for HTTPS**
3. **Set up AWS CloudTrail for logging**
4. **Configure S3 bucket notifications**
5. **Regular security audits**

## Monitoring

1. **AWS CloudWatch**: Monitor S3 and CloudFront metrics
2. **Railway Logs**: Monitor your server performance
3. **Razorpay Dashboard**: Track payment transactions

## Backup Strategy

1. **S3 Cross-Region Replication**: For disaster recovery
2. **Railway Database Backups**: Regular database snapshots
3. **Code Repository**: Keep your code in Git

## Support

- AWS Support: https://aws.amazon.com/support/
- Railway Support: https://railway.app/help
- Razorpay Support: https://razorpay.com/support/

## Next Steps

1. Set up monitoring and alerts
2. Configure custom domain
3. Implement CI/CD pipeline
4. Add SSL certificate
5. Optimize for performance

---

**Note**: Keep your Railway server running as it handles all payment processing and API requests.