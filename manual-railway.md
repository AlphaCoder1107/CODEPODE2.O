# Manual Railway Deployment (5 minutes)

AWS EB keeps failing. Use Railway instead - it's free and works perfectly.

## Steps:

1. **Go to**: https://railway.app
2. **Sign up** with GitHub
3. **New Project** → **Empty Project**
4. **Upload** the `server` folder
5. **Variables** tab → Add:
   - `RAZORPAY_KEY_ID` = `rzp_test_R5XmEfkjyyHrMQ`
   - `RAZORPAY_KEY_SECRET` = `dCJ1EXoJzEPHxbfQlKRLHW7y`
   - `WEBHOOK_SECRET` = `0f3b2a8e9c6d4f1a2b3c4d5e6f708192a1b2c3d4e5f60718293a4c5b6d7e8f90`
   - `NODE_ENV` = `production`
6. **Deploy** (automatic)
7. **Settings** → **Generate Domain** → Copy URL

## After Railway Deployment:

1. Copy your Railway URL (e.g., `https://your-app.railway.app`)
2. Run: `update-frontend.bat`
3. Enter your Railway URL
4. Done!

## Result:
- ✅ Frontend: AWS S3 (fast)
- ✅ Server: Railway (reliable)
- ✅ Full payment integration
- ✅ No AWS permission issues