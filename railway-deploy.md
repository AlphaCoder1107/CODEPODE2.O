# Deploy Server to Railway (Free)

## Quick Deploy:

1. **Go to Railway**: https://railway.app
2. **Sign up** with GitHub
3. **New Project** → **Deploy from GitHub repo** or **Empty Project**
4. **Upload** the `external-server` folder
5. **Set Environment Variables**:
   - `RAZORPAY_KEY_ID` = `rzp_test_R5XmEfkjyyHrMQ`
   - `RAZORPAY_KEY_SECRET` = `dCJ1EXoJzEPHxbfQlKRLHW7y`
   - `WEBHOOK_SECRET` = `0f3b2a8e9c6d4f1a2b3c4d5e6f708192a1b2c3d4e5f60718293a4c5b6d7e8f90`
   - `PORT` = `8080`
6. **Deploy**

## Alternative: Render.com

1. **Go to**: https://render.com
2. **New Web Service**
3. **Upload** `external-server` folder
4. **Set same environment variables**
5. **Deploy**

## After Server Deployment:

1. Get your server URL (e.g., `https://your-app.railway.app`)
2. Run: `update-frontend.bat`
3. Enter your server URL
4. Test: Visit your S3 website and try checkout

Your site will be fully functional with payment integration!