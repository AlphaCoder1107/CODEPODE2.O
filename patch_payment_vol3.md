````markdown
# ✅ Final 10% Integration Guide: Razorpay Checkout.js + Orders API in CodePod

This guide covers the **last steps** required to make Razorpay Checkout **fully functional** in CodePod.  
By the end, clicking **Proceed to Buy** will open the Razorpay Checkout popup, process the payment, and confirm it on your backend.

---

## 1. Prerequisites

- You already have:
  - `/api/create-order` implemented (server → Razorpay Orders API).
  - `/api/verify-payment` implemented (server → HMAC signature verification).
  - `/api/checkout/webhook` implemented (server → idempotent webhook handler).
  - Cart frontend logic that calls `/api/create-order`.

- Make sure `.env` contains your **real Razorpay keys** (test or live depending on environment):

  ```env
  RAZORPAY_KEY_ID=rzp_test_12345
  RAZORPAY_KEY_SECRET=your_secret_here
  WEBHOOK_SECRET=your_webhook_secret_here
````

---

## 2. Update Proceed to Buy → Checkout.js Flow

In your `cart.js` (or wherever you handle **Proceed to Buy**):

```js
document.querySelector("#proceed-to-buy").addEventListener("click", async () => {
  try {
    // Step 1: Ask backend to create an order
    const response = await fetch("/api/create-order", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ amount: window.CodePodCart.getTotal() * 100 }) // in paise
    });

    const order = await response.json();

    if (!order || !order.id) {
      alert("❌ Failed to create order. Try again.");
      return;
    }

    // Step 2: Configure Checkout.js
    const options = {
      key: RAZORPAY_KEY_ID,   // <- injected from server-side or set globally in page
      amount: order.amount,
      currency: order.currency,
      name: "CodePod",
      description: "CodePod Purchase",
      order_id: order.id,     // Razorpay Order ID from backend
      prefill: {
        name: "John Doe",     // optionally get from logged-in user profile
        email: "john@example.com",
        contact: "9876543210"
      },
      theme: { color: "#3399cc" },
      handler: async function (response) {
        // Step 3: Send payment result to backend for verification
        const verifyRes = await fetch("/api/verify-payment", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(response) // contains payment_id, order_id, signature
        });

        const verifyData = await verifyRes.json();
        if (verifyData.ok) {
          alert("✅ Payment successful! Order confirmed.");
          window.location.href = "/thank-you.html";
        } else {
          alert("⚠️ Payment verification failed.");
        }
      }
    };

    // Step 4: Open Razorpay Checkout popup
    const rzp = new Razorpay(options);
    rzp.open();

  } catch (err) {
    console.error("Payment error:", err);
    alert("❌ Something went wrong during checkout.");
  }
});
```

---

## 3. Exposing the Key ID to Frontend

The `RAZORPAY_KEY_ID` must be available in the browser.
Options:

* **Inject into HTML**:

  ```html
  <script>
    const RAZORPAY_KEY_ID = "<%= process.env.RAZORPAY_KEY_ID %>";
  </script>
  ```
* Or serve via a small API (`/api/config`) that returns safe public config.

⚠️ Never expose `RAZORPAY_KEY_SECRET` — it stays on server only.

---

## 4. Backend Verification Flow

You already have `/api/verify-payment` implemented.
Confirm it validates with:

```js
const crypto = require("crypto");

app.post("/api/verify-payment", (req, res) => {
  const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;

  const hmac = crypto.createHmac("sha256", process.env.RAZORPAY_KEY_SECRET);
  hmac.update(razorpay_order_id + "|" + razorpay_payment_id);
  const digest = hmac.digest("hex");

  if (digest === razorpay_signature) {
    // ✅ Verified
    updateOrderStatus(razorpay_order_id, "PAID");
    res.json({ ok: true });
  } else {
    res.status(400).json({ ok: false, error: "Invalid signature" });
  }
});
```

---

## 5. Webhook Confirmation (Backup)

* Razorpay will also POST to `/api/checkout/webhook`.
* You already implemented idempotent webhook handling (`processed_webhooks.json` + `orders.json`).
* This ensures order status updates even if client verification fails.

---

## 6. Testing Checklist

1. Start server:

   ```bash
   cd server
   node index.js
   ```

2. Add an item to cart → go to **cart page** → click **Proceed to Buy**.

3. Expected behavior:

   * `/api/create-order` responds with `{ id, amount, currency }`.
   * Checkout.js popup appears.
   * You can complete payment using test credentials (for test mode).
   * `handler()` posts to `/api/verify-payment` and returns `{ ok: true }`.
   * Backend updates `orders.json` with `status: PAID`.
   * Webhook event (if configured in Razorpay dashboard) also arrives and is logged.

---

## 7. Next Enhancements (Optional)

* 🔄 **Undo in mini-drawer** → UX improvement.
* 💾 **Sync cart to backend** for logged-in users.
* 📦 **CI test harness** → auto-create order, auto-post webhook, validate order marked PAID.
* 🔐 **Environment split** → separate `.env.test` vs `.env.live` Razorpay keys.

---

## ✅ Summary

* You’re **one step away** from a robust Razorpay integration.
* Frontend now must:

  * Call `/api/create-order`.
  * Pass `order.id` to Checkout.js.
  * Post payment success back to `/api/verify-payment`.
* With live keys in `.env`, this will open Razorpay Checkout popup and complete real payments.

```

---

Would you like me to also **write the exact `thank-you.html` page** (with order confirmation message) so the flow feels complete after payment success?
```
