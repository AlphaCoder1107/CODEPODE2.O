# Debugging Express Server Not Binding to Port 3001

You observed:

- Running `node index.js` logs **"Payments server listening on 3001"**.
- A Node process is active (`Get-Process node` shows PID 2252).
- But `netstat -ano | findstr :3001` shows **no process bound**.
- Requests to `/api/create-payment-link` fail with **actively refused**.

This means **Express never actually bound to the port**, even though logs suggest it.

---

## Step 1 — Add explicit startup logs

Edit `server/index.js`:

```js
console.log("About to call app.listen...");
app.listen(3001, "0.0.0.0", () => {
  console.log("✅ App.listen callback fired, Express bound to port 3001");
});
