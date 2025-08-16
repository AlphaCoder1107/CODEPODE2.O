# AWS Console Setup Guide

## Quick Fix: Create S3 Bucket via AWS Console

### Step 1: Create S3 Bucket
1. Go to **AWS Console** → **S3**
2. Click **Create bucket**
3. Bucket name: `codepode.in`
4. Region: `US East (N. Virginia) us-east-1`
5. **Uncheck** "Block all public access"
6. Click **Create bucket**

### Step 2: Enable Website Hosting
1. Click on your bucket `codepode.in`
2. Go to **Properties** tab
3. Scroll to **Static website hosting**
4. Click **Edit**
5. Select **Enable**
6. Index document: `index.html`
7. Error document: `index.html`
8. Click **Save changes**

### Step 3: Upload Website Files
1. Go to **Objects** tab
2. Click **Upload**
3. **Add files** → Select all your HTML files (index.html, contact.html, etc.)
4. **Add folder** → Select `assets` folder
5. **Add folder** → Select `pi_2W` folder  
6. **Add folder** → Select `pi_3B` folder
7. Click **Upload**

### Step 4: Make Files Public
1. Select all uploaded files
2. Click **Actions** → **Make public using ACL**
3. Click **Make public**

### Step 5: Test Your Website
Your website will be available at:
`http://codepode.in.s3-website-us-east-1.amazonaws.com`

## Alternative: Install AWS CLI

### Option 1: Download AWS CLI
1. Go to: https://aws.amazon.com/cli/
2. Download AWS CLI for Windows
3. Install and restart command prompt
4. Run: `aws configure`

### Option 2: Use PowerShell
Open **Command Prompt** (not PowerShell) and run the batch files.

## Files to Upload
- index.html
- contact.html
- cart.html
- footer.html
- pi_2W.html
- pi3_W.html
- pi3-modelbplus.html
- assets/ (entire folder)
- pi_2W/ (entire folder)
- pi_3B/ (entire folder)