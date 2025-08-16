@echo off
echo 🧪 Testing Deployment

set /p SERVER_URL="Enter your server URL: "
set /p WEBSITE_URL="Enter your website URL: "

echo.
echo Testing server endpoints...

echo 1️⃣ Health check...
curl -s %SERVER_URL%/api/health

echo.
echo 2️⃣ Config check...
curl -s %SERVER_URL%/api/config

echo.
echo 3️⃣ Testing payment creation...
curl -X POST %SERVER_URL%/api/create-order ^
  -H "Content-Type: application/json" ^
  -d "{\"amount\":10000,\"currency\":\"INR\",\"description\":\"Test order\"}"

echo.
echo 4️⃣ Testing website...
curl -I %WEBSITE_URL%

echo.
echo ✅ Tests complete!
echo.
echo 📝 Manual tests:
echo 1. Visit: %WEBSITE_URL%
echo 2. Add items to cart
echo 3. Test checkout process
echo 4. Verify payment integration
echo.
pause