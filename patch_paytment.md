# Upgrade to Razorpay Checkout.js with Orders API

The current implementation redirects users to a Razorpay **Payment Link** (short\_url). This works, but a smoother experience is achieved by embedding the **Razorpay Checkout.js** popup using the **Orders API**.

---

## Why Switch to Orders API?

* ✅ Native embedded popup instead of redirecting away.
* ✅ Better control over order lifecycle (created, paid, failed).
* ✅ Direct order\_id references allow secure backend verification.
* ✅ Recommended by Razorpay for production ecommerce flows.

---

## Step 1 — Update Backend to Use Orders API

In `server/index.js`, add a new route `/api/create-order`:

```js
const Razorpay = require("razorpay");
const express = require("express");
const router = express.Router();

// Init Razorpay client with keys from .env
const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

router.post("/api/create-order", async (req, res) => {
  try {
    const { amount, currency = "INR", receipt } = req.body;

    const options = {
      amount: amount, // in paise
      currency,
      receipt: receipt || `rcpt_${Date.now()}`,
      payment_capture: 1,
    };

    const order = await razorpay.orders.create(options);
    res.json({ ok: true, order });
  } catch (err) {
    console.error("Order creation failed", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

module.exports = router;
```

This creates an **order\_id** on Razorpay.

---

## Step 2 — Frontend Integration with Checkout.js

In `cart.html` (or `cart.js`):

```html
<script src="https://checkout.razorpay.com/v1/checkout.js"></script>
<script>
document.getElementById("proceedBtn").addEventListener("click", async () => {
  try {
    // Call backend to create order
    const resp = await fetch("/api/create-order", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ amount: 2099 * 100 })
    });

    const data = await resp.json();
    if (!data.ok) throw new Error(data.error || "Order creation failed");

    const options = {
      key: "YOUR_KEY_ID", // from Razorpay Dashboard
      amount: data.order.amount,
      currency: data.order.currency,
      name: "CodePod",
      description: "DIY Kit Purchase",
      order_id: data.order.id,
      handler: function (response) {
        alert("Payment successful: " + response.razorpay_payment_id);
        // TODO: send response + order_id to backend for verification
      },
      prefill: {
        name: "Cart Buyer",
        email: "buyer@example.com",
        contact: "9876543210"
      },
      theme: { color: "#528FF0" }
    };

    const rzp1 = new Razorpay(options);
    rzp1.open();
  } catch (err) {
    alert("Checkout failed: " + err.message);
  }
});
</script>
```

---

## Step 3 — Backend Verification

After a successful payment, Razorpay sends a **payment authorized** webhook. You must:

1. Validate HMAC signature.
2. Match `order_id` against your stored order.
3. Update `orders.json` (or DB) to mark it as PAID.

Example verification snippet (already in your webhook handler):

```js
const crypto = require("crypto");

function verifySignature(body, signature) {
  const expected = crypto
    .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET)
    .update(JSON.stringify(body))
    .digest("hex");
  return expected === signature;
}
```

---

## Debugging Checklist

* ✅ Ensure `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` are in `.env`.
* ✅ Test `/api/create-order` manually → returns `order.id`.
* ✅ Confirm Checkout.js popup opens with order details.
* ✅ Verify webhook updates order status in `orders.json`.
* 🔲 Add error logging for failed payments.
* 🔲 Confirm amounts are always passed in **paise**.

---

## Recommendation

Switching from Payment Links to Orders API + Checkout.js provides a professional embedded checkout flow. This is the recommended path for CodePod ecommerce.

**Next Action:** Implement `/api/create-order` backend route and patch frontend to use Checkout.js with `order_id`. Then test a real transaction end-to-end.
