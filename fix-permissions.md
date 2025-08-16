# Fix AWS Permissions

Your AWS user needs these permissions for full deployment:

## Required IAM Policies:

1. **CloudFormation Full Access**
2. **Elastic Beanstalk Full Access** 
3. **S3 Full Access**
4. **CloudFront Full Access**
5. **Certificate Manager Full Access**
6. **Route 53 Full Access**
7. **IAM Limited Access**

## Quick Fix:

Ask your AWS admin to attach these managed policies to your user:
- `PowerUserAccess` (recommended)
- OR individual policies listed above

## Alternative Deployments:

Since you have permission issues, use these instead:

1. **Simple S3 Website:**
   ```cmd
   deploy-simple.bat
   ```

2. **Server on Heroku + Frontend on S3:**
   ```cmd
   deploy-simple.bat
   deploy-heroku.bat
   ```

3. **Manual AWS Console:**
   - Create S3 bucket manually
   - Upload files via AWS Console
   - Create Elastic Beanstalk app manually