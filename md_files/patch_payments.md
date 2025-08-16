Nice — below is a complete, ready-to-drop-in implementation to open the Razorpay Checkout when the user clicks **Proceed to Buy**. It includes:

* Frontend `proceedToBuy()` code (protects from double-clicks, opens Checkout, posts verification).
* Minimal Express backend endpoints: `POST /api/checkout/create-order` and `POST /api/checkout/verify`.
* Notes on env vars, paise conversion, webhooks, and testing.

Copy the snippets into your existing files (`cart.html` / `assets/js/cart.js` on the client and `server/index.js` on the server). I wrote them to fit your current project layout described in the Roadmap.

---

# Frontend — cart.html / assets/js (client)

Place this inside your cart page (or import into `assets/js/cart.js`). Make sure `<script src="https://checkout.razorpay.com/v1/checkout.js"></script>` is loaded **before** calling `new Razorpay(...)`.

```html
<!-- Add this in your cart.html (inside <head> or before closing </body>) -->
<script src="https://checkout.razorpay.com/v1/checkout.js"></script>

<script>
/**
 * proceedToBuy(cart)
 * cart: array of items or summary object. For safety, send minimal info (ids/qty)
 * This function:
 * 1) POSTs cart to /api/checkout/create-order
 * 2) receives razorpayOrderId + amount + localOrderId
 * 3) opens Razorpay Checkout
 * 4) on handler, POSTs verification to /api/checkout/verify
 *
 * IMPORTANT: backend must calculate & validate final totals server-side.
 */

let _rzpIsOpen = false; // prevent duplicates

async function proceedToBuy(cart) {
  if (_rzpIsOpen) return;            // prevent double-clicks
  _rzpIsOpen = true;
  try {
    // show loader on proceed button if you have one
    const res = await fetch('/api/checkout/create-order', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ cart }) // keep payload small
    });

    if (!res.ok) {
      const txt = await res.text();
      alert('Failed to create order: ' + txt);
      _rzpIsOpen = false;
      return;
    }
    const data = await res.json();
    // data must include: razorpayKeyId, orderId, amount, localOrderId, customer(optional)
    const options = {
      key: data.razorpayKeyId,               // RAZORPAY_KEY_ID (public)
      amount: data.amount,                   // optional, in paise
      currency: data.currency || 'INR',
      name: 'CodePode',
      description: 'Order #' + data.localOrderId,
      order_id: data.orderId,                // Razorpay order_id from server
      prefill: {
        name: data.customer?.name || '',
        email: data.customer?.email || '',
        contact: data.customer?.phone || ''
      },
      theme: { color: '#528FF0' },           // optional
      handler: async function (response) {
        // response = { razorpay_payment_id, razorpay_order_id, razorpay_signature }
        try {
          // send to server for immediate verification (server should still use webhook as source-of-truth)
          const v = await fetch('/api/checkout/verify', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
              razorpay_payment_id: response.razorpay_payment_id,
              razorpay_order_id: response.razorpay_order_id,
              razorpay_signature: response.razorpay_signature,
              localOrderId: data.localOrderId
            })
          });
          const vr = await v.json();
          if (v.ok && vr.verified) {
            // redirect to receipt page or show success
            window.location.href = '/receipt.html?order=' + data.localOrderId;
          } else {
            alert('Payment verification failed. If amount was charged, we will reconcile using webhooks.');
            window.location.href = '/receipt.html?order=' + data.localOrderId + '&status=pending';
          }
        } catch (err) {
          console.error('verify error', err);
          alert('Verification failed (network). We will check via webhook. Check your orders page later.');
          window.location.href = '/receipt.html?order=' + data.localOrderId + '&status=pending';
        }
      },
      modal: {
        ondismiss: function(){
          // user closed checkout
          _rzpIsOpen = false;
        }
      }
    };

    const rzp = new Razorpay(options);
    rzp.open();

    // optional: handle payment.failed events by listening on window
    rzp.on('payment.failed', function (response){
      console.error('payment.failed', response);
      alert('Payment failed: ' + (response.error.description || 'Unknown'));
      _rzpIsOpen = false;
    });

  } catch (err) {
    console.error(err);
    alert('Unexpected error while initiating payment.');
  } finally {
    // keep _rzpIsOpen false only after checkout closed/handled via handlers above
    // here we don't reset to false immediately to avoid race conditions
  }
}
</script>
```

Add a button on your cart page that calls `proceedToBuy(cart)` with your cart object:

```html
<button id="checkoutBtn" onclick="proceedToBuy(getCart())">Proceed to Buy</button>
```

---

# Backend — Node.js / Express

Add / update these endpoints in `server/index.js`. Ensure you have `razorpay` package installed: `npm i razorpay`. Use `process.env.RAZORPAY_KEY_ID` and `process.env.RAZORPAY_KEY_SECRET`. Server must compute `amountPaise` from product prices stored on server or DB — **never trust frontend totals**.

```js
// server/index.js (snippet)
const express = require('express');
const Razorpay = require('razorpay');
const crypto = require('crypto');
const bodyParser = require('body-parser');

const app = express();
app.use(express.json()); // for non-webhook routes

const rzp = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET
});

// Utility: compute total server-side from cart (you must implement using your product DB)
function computeAmountPaise(cart) {
  // Example: cart = [{id: 'p1', qty: 2}, ...]
  // Fetch product prices from DB and sum up
  // For demonstration, assume cart has total field (NOT recommended in prod)
  const totalRupees = cart.total || 0;
  return Math.round(totalRupees * 100); // convert rupees to paise
}

app.post('/api/checkout/create-order', async (req, res) => {
  try {
    const { cart } = req.body;
    // 1) Validate cart & compute final total server-side
    const amountPaise = computeAmountPaise(cart); // integer paise
    if (!amountPaise || amountPaise <= 0) return res.status(400).send('Invalid amount');

    // 2) create local order record (persist). Minimal example: write to file or DB
    // localOrder = await db.createOrder({...})
    const localOrderId = 'local_' + Date.now();

    // 3) create Razorpay order
    const orderOptions = {
      amount: amountPaise,
      currency: 'INR',
      receipt: `cp_${localOrderId}`,
      notes: { localOrderId } // optional mapping
    };
    const razorpayOrder = await rzp.orders.create(orderOptions);

    // TODO: persist mapping between localOrderId and razorpayOrder.id and status=CREATED
    // Example response:
    res.json({
      razorpayKeyId: process.env.RAZORPAY_KEY_ID,
      orderId: razorpayOrder.id,
      amount: razorpayOrder.amount,
      currency: razorpayOrder.currency,
      localOrderId,
      customer: { name: '', email: '' }
    });
  } catch (err) {
    console.error(err);
    res.status(500).send('create-order-failed');
  }
});

// immediate verify endpoint (frontend calls this after checkout handler)
app.post('/api/checkout/verify', async (req, res) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, localOrderId } = req.body;
    const body = razorpay_order_id + '|' + razorpay_payment_id;
    const expectedSignature = crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET).update(body).digest('hex');

    if (expectedSignature === razorpay_signature) {
      // mark local order PAID (or PAYMENT_PENDING until webhook) in DB
      // await db.updateOrder(localOrderId, { status: 'PAID', razorpay_payment_id })
      return res.json({ verified: true });
    } else {
      console.warn('signature-mismatch', { expectedSignature, razorpay_signature });
      return res.status(400).json({ verified: false, reason: 'signature_mismatch' });
    }
  } catch (err) {
    console.error(err);
    res.status(500).send('verify-failed');
  }
});

// Webhook endpoint (preferred source-of-truth) - use raw body for signature verification
const rawBodyParser = bodyParser.raw({ type: 'application/json' });
app.post('/api/checkout/webhook', rawBodyParser, (req, res) => {
  const webhookSecret = process.env.WEBHOOK_SECRET; // set in prod
  const signature = req.headers['x-razorpay-signature'];
  const body = req.body.toString();
  const expected = crypto.createHmac('sha256', webhookSecret).update(body).digest('hex');

  if (expected !== signature) {
    console.warn('Invalid webhook signature');
    return res.status(400).send('invalid signature');
  }

  const event = JSON.parse(body);
  // handle event types: payment.captured, payment.failed, order.paid, etc.
  if (event.event === 'payment.captured') {
    const payment = event.payload.payment.entity;
    const rzpOrderId = payment.order_id;
    // find local order by rzpOrderId (or receipt)
    // mark PAID if not already processed (idempotent)
  }

  // always respond 200 quickly
  res.status(200).send('ok');
});

app.listen(process.env.PORT || 3001, () => console.log('Server running'));
```

---

# Important implementation notes & checklist

1. **Amounts must be in paise** — convert rupees × 100 on server. No client-side math for security.
2. **Server must validate the cart** (product prices, discounts, taxes) and compute final amount. Use your DB or authoritative pricing.
3. **Razorpay keys**:

   * `RAZORPAY_KEY_ID` (public) — safe to return to frontend.
   * `RAZORPAY_KEY_SECRET` (private) — must remain on the server only.
   * `WEBHOOK_SECRET` — used to verify webhook payloads.
4. **Immediate verify + webhook**:

   * Keep `/verify` for fast UX, but treat webhook (`/webhook`) as final source-of-truth (it’s server-to-server).
   * Webhook handler must be idempotent (check order status before update) and store raw payloads for debugging.
5. **Prevent duplicate charges**: disable button while pending and verify on server before creating a new Razorpay order for same local order.
6. **Testing**:

   * Use Razorpay **Test Mode** keys.
   * Use ngrok to expose local server for webhook URL and add it in Razorpay Dashboard -> Webhooks.
   * Use Razorpay test cards / wallets to simulate captured/failed events.

---

# Quick test flow (local)

1. Start server: `cd server && npm install && npm start`.
2. Open cart on your site (served from local dev server or S3 + local backend).
3. Click **Proceed to Buy** → checkout should open (Razorpay test mode).
4. Complete payment with a test card — frontend handler will call `/api/checkout/verify`.
5. Use ngrok to expose backend step 1 and configure webhook in Razorpay dashboard to `https://<ngrok>.io/api/checkout/webhook`.
6. Inspect logs / webhook audit to confirm `payment.captured` handled and local order marked PAID.

---

If you want, I can **commit these changes directly** into your repo structure (create the Express endpoint file and insert the frontend snippet into `cart.html`) and update the canvas doc to show where I changed files. Say the word and I’ll add them now.


# CodePode — Razorpay Checkout Integration ("Proceed to Buy")

**Purpose**
This document is a focused, step-by-step guide that shows exactly how to wire the Razorpay Checkout into CodePode's **Proceed to Buy** flow. It covers the frontend integration, backend endpoints, data persistence, webhook handling, local testing (ngrok), production considerations (AWS hosting, secrets), security, testing, and troubleshooting. Use this to implement, test, and deploy a reliable payment flow.

**Date:** 2025-08-15

---

## Quick summary

When the user clicks **Proceed to Buy** the frontend will:

1. Call the backend `POST /api/checkout/create-order` with a minimal cart payload.
2. Backend validates the cart, persists a local order with `status: CREATED`, and creates a Razorpay Order via Razorpay API (server-side) — returning `razorpayOrderId` and `RAZORPAY_KEY_ID` to the client.
3. Frontend opens the Razorpay Checkout widget with the returned `order_id`.
4. On successful payment, frontend receives `razorpay_payment_id`, `razorpay_order_id` and `razorpay_signature` and calls `POST /api/checkout/verify` for immediate verification (UX). The server verifies the signature and responds; the webhook remains the source-of-truth.
5. Razorpay posts payment events to your webhook endpoint (`/api/checkout/webhook`). The server verifies webhook signature, marks the order `PAID` if event is `payment.captured`, writes audit logs, and ensures idempotency.

---

## Files to change / add

* Frontend

  * `cart.html` — add the proceed button and include checkout script.
  * `assets/js/cart.js` — add `proceedToBuy(cart)` function or call shared checkout module.
* Backend

  * `server/index.js` — add endpoints:

    * `POST /api/checkout/create-order`
    * `POST /api/checkout/verify`
    * `POST /api/checkout/webhook` (raw body parser)
  * `server/orders.json` (dev persistence) or database table `orders` (prod)
  * `server/webhook_audit.log` (append-only raw payloads for debugging)
* Config

  * `server/.env.example` — include `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `WEBHOOK_SECRET` and `NODE_ENV`.

---

## Environment variables (server)

```
RAZORPAY_KEY_ID=rzp_test_xxx
RAZORPAY_KEY_SECRET=xxxxxxxx
WEBHOOK_SECRET=your_webhook_secret_here
NODE_ENV=development
PORT=3001
```

* Use test keys while developing. Move secrets to AWS Secrets Manager / Parameter Store in production.

---

## Frontend — Implementation details

**Important rules**

* Do not compute or trust final amounts on the client. Frontend sends the cart (ids + quantities) but server re-calculates prices, taxes, discounts, and final amount.
* Disable the checkout button once pressed to prevent duplicate checkout windows.
* Include `https://checkout.razorpay.com/v1/checkout.js` on the page.

**HTML snippet (cart.html)**

```html
<!-- include checkout script once in your page -->
<script src="https://checkout.razorpay.com/v1/checkout.js"></script>
<button id="checkoutBtn">Proceed to Buy</button>
<script src="/assets/js/cart.js"></script>
```

**Frontend JS (assets/js/cart.js)**

```js
let _rzpInProgress = false;
async function proceedToBuy(cart) {
  if (_rzpInProgress) return;
  _rzpInProgress = true;
  try {
    const resp = await fetch('/api/checkout/create-order', {
      method: 'POST', headers: {'Content-Type':'application/json'},
      body: JSON.stringify({cart})
    });
    if(!resp.ok) throw new Error('create-order-failed');
    const data = await resp.json();

    const options = {
      key: data.razorpayKeyId,
      amount: data.amount, // paise
      currency: data.currency || 'INR',
      name: 'CodePode',
      description: 'Order #' + data.localOrderId,
      order_id: data.orderId,
      prefill: {name: data.customer?.name || '', email: data.customer?.email || ''},
      handler: async function(response) {
        // immediate verification for UX
        try {
          const v = await fetch('/api/checkout/verify', {
            method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ ...response, localOrderId: data.localOrderId })
          });
          const vr = await v.json();
          if (v.ok && vr.verified) {
            window.location.href = '/receipt.html?order=' + data.localOrderId;
          } else {
            // show pending but rely on webhook
            window.location.href = '/receipt.html?order=' + data.localOrderId + '&status=pending';
          }
        } catch (err) {
          window.location.href = '/receipt.html?order=' + data.localOrderId + '&status=pending';
        }
      },
      modal: { ondismiss: function(){ _rzpInProgress = false; } }
    };

    const rzp = new Razorpay(options);
    rzp.open();

    rzp.on('payment.failed', function(resp){
      alert('Payment failed: ' + (resp.error?.description || 'Unknown'));
      _rzpInProgress = false;
    });

  } catch (err) {
    console.error(err);
    alert('Payment initiation error');
    _rzpInProgress = false;
  }
}

// Example: wire button
document.getElementById('checkoutBtn').addEventListener('click', ()=>proceedToBuy(getCart()));
```

**Notes:**

* `getCart()` should return a minimal cart object: `{ items: [{id, qty}], shipping: {...} }`.
* `data.amount` returned by the server is in **paise**. Client can optionally show but not compute it.

---

## Backend — Node.js / Express (detailed)

**Install dependencies**

```
npm install express razorpay body-parser dotenv uuid fs-extra
```

**Key responsibilities**

* Validate cart + compute final amount in paise
* Create a local order and persist (dev: `orders.json`, prod: DB)
* Create a Razorpay order using the server-side SDK
* Serve `razorpayKeyId` (public) and `razorpayOrderId` to client
* Verify checkout signatures on `/verify`
* Receive webhooks on `/webhook` (raw body) and mark orders `PAID`/`FAILED` idempotently

**Server skeleton (server/index.js)**

```js
require('dotenv').config();
const express = require('express');
const Razorpay = require('razorpay');
const crypto = require('crypto');
const bodyParser = require('body-parser');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs-extra');

const app = express();
app.use(express.json());
const rzp = new Razorpay({ key_id: process.env.RAZORPAY_KEY_ID, key_secret: process.env.RAZORPAY_KEY_SECRET });

const ORDERS_FILE = './server/orders.json';
fs.ensureFileSync(ORDERS_FILE);

function loadOrders(){ try { return fs.readJsonSync(ORDERS_FILE); } catch(e){ return []; } }
function saveOrders(arr){ fs.writeJsonSync(ORDERS_FILE, arr, {spaces:2}); }

function computeAmountPaise(cart){
  // TODO: replace with DB-backed price lookup and tax calc
  const totalRupees = cart.items.reduce((s,it)=> s + (it.unit_price || 0) * it.qty, 0);
  return Math.round(totalRupees * 100);
}

app.post('/api/checkout/create-order', async (req,res)=>{
  const { cart, customer } = req.body;
  const amountPaise = computeAmountPaise(cart);
  if(!amountPaise || amountPaise <= 0) return res.status(400).send('Invalid amount');

  const localOrderId = uuidv4();
  const orders = loadOrders();
  const localOrder = { id: localOrderId, items: cart.items, amount_paise: amountPaise, currency:'INR', status:'CREATED', created_at: new Date().toISOString() };
  orders.push(localOrder); saveOrders(orders);

  const orderOptions = { amount: amountPaise, currency: 'INR', receipt: `cp_${localOrderId}`, notes: { localOrderId } };
  const razorpayOrder = await rzp.orders.create(orderOptions);

  // persist razorpay_order_id mapping
  localOrder.razorpay_order_id = razorpayOrder.id; saveOrders(orders);

  res.json({ razorpayKeyId: process.env.RAZORPAY_KEY_ID, orderId: razorpayOrder.id, amount: razorpayOrder.amount, currency:'INR', localOrderId, customer: customer || {} });
});

app.post('/api/checkout/verify', async (req,res)=>{
  const { razorpay_order_id, razorpay_payment_id, razorpay_signature, localOrderId } = req.body;
  const body = razorpay_order_id + '|' + razorpay_payment_id;
  const expectedSignature = crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET).update(body).digest('hex');
  if(expectedSignature !== razorpay_signature) return res.status(400).json({ verified:false, reason:'signature_mismatch' });

  const orders = loadOrders();
  const o = orders.find(x=>x.id === localOrderId || x.razorpay_order_id === razorpay_order_id);
  if(o){ o.razorpay_payment_id = razorpay_payment_id; o.status = 'PAYMENT_PENDING'; o.updated_at = new Date().toISOString(); saveOrders(orders); }
  return res.json({ verified:true });
});

// webhook must use raw body
app.post('/api/checkout/webhook', bodyParser.raw({type:'application/json'}), (req,res)=>{
  const sig = req.headers['x-razorpay-signature'];
  const secret = process.env.WEBHOOK_SECRET;
  const body = req.body.toString();
  const expected = crypto.createHmac('sha256', secret).update(body).digest('hex');
  if(expected !== sig) return res.status(400).send('invalid signature');

  const event = JSON.parse(body);
  // persist raw payload for audit
  fs.appendFileSync('./server/webhook_audit.log', new Date().toISOString() + ' ' + body + '
');

  if(event.event === 'payment.captured'){
    const payment = event.payload.payment.entity;
    const rzpOrderId = payment.order_id;

    const orders = loadOrders();
    const o = orders.find(x=> x.razorpay_order_id === rzpOrderId || x.id === payment.notes?.localOrderId);
    if(o && o.status !== 'PAID'){
      o.status = 'PAID'; o.razorpay_payment_id = payment.id; o.updated_at = new Date().toISOString(); saveOrders(orders);
    }
  }

  res.status(200).send('ok');
});

app.listen(process.env.PORT || 3001, ()=> console.log('Server started'));
```

**Production notes:**

* Replace `orders.json` with RDS (Postgres/MySQL) or DynamoDB.
* Add database transactions and locking to guarantee idempotency under concurrency.

---

## Webhook setup (Razorpay dashboard)

1. In Razorpay Dashboard → Settings → Webhooks, add your webhook URL: `https://<your-domain>/api/checkout/webhook`.
2. Choose events to subscribe: at minimum `payment.captured`, `payment.failed`, `order.paid`.
3. Save and copy the generated webhook `secret` → set this as `WEBHOOK_SECRET` on the server.

**Local dev**

* Run `ngrok http 3001` and use `https://<ngrok>.io/api/checkout/webhook` as the webhook URL. Keep ngrok running while testing.

---

## Testing & QA checklist

* [ ] Use Razorpay **Test Mode** keys for all tests.
* [ ] E2E: click Proceed to Buy, complete payment with test card, confirm `verify` endpoint returns `verified:true`.
* [ ] Confirm webhook delivery: payment event appears in Razorpay Dashboard → Webhooks and server `webhook_audit.log` records payload.
* [ ] Idempotency: replay same webhook payload (Razorpay has re-delivery) — order must remain `PAID` and not duplicate.
* [ ] Edge cases: partial payments, refunds, network failures between payment and verify endpoint.
* [ ] Reconciliation: run a script to compare `PAID` orders with Razorpay payouts.

---

## Security & compliance

* **Never expose** `RAZORPAY_KEY_SECRET` or `WEBHOOK_SECRET` in frontend or checked-in files. Use `.env` for dev and Secrets Manager in prod.
* Use HTTPS always — CloudFront/ALB or API Gateway + Lambda provide TLS.
* Use raw body parsing for webhook route when verifying signatures.
* Do not log card data; Razorpay Checkout handles card data — you must not capture or store card numbers.

---

## Deployment on AWS (overview)

**Frontend**

* Build static site and host on S3 + CloudFront with ACM-managed TLS cert. Point domain via Route53.
  **Backend**
* Options:

  * Elastic Beanstalk (fast): simple node app deployment.
  * ECS Fargate (recommended for containers): build Docker image, store in ECR, deploy to ECS service.
  * Lambda + API Gateway: serverless option (ensure proper raw body handling on webhook).
    **Database**
* RDS Postgres or DynamoDB for serverless.
  **Secrets**
* Use AWS Secrets Manager to store `RAZORPAY_KEY_*` and `WEBHOOK_SECRET`. Grant IAM role to backend to read secrets.

**CI/CD**

* GitHub Actions to `aws s3 sync` built front-end and deploy backend (EB/ECS) on push to `main`.
* Store AWS credentials and Razorpay live keys in GitHub Secrets for deployment workflows.

---

## Troubleshooting common issues

* **Payment doesn't appear in Razorpay dashboard** — check whether you are using Test vs Live keys; check `order.receipt` mapping.
* **Signature mismatch** — confirm you used the correct `RAZORPAY_KEY_SECRET` for verify and `WEBHOOK_SECRET` for webhook verification and that webhook uses raw body.
* **Webhook not delivered** — check public endpoint reachable (use ngrok for dev), check firewall, and verify webhook URL in dashboard.
* **Amounts mismatch** — server must compute final totals and send amount in **paise** to Razorpay.
* **Duplicate processing** — implement idempotent webhook handler (check order status before updating) and store processed event IDs.

---

## Example troubleshooting checklist

1. Reproduce with Test Mode.
2. Inspect server logs and `webhook_audit.log`.
3. Validate webhook signature using `crypto.createHmac('sha256', secret).update(rawBody).digest('hex')`.
4. Confirm `receipt` (cp\_<local>) present in Razorpay order or payment notes.

---

## Next steps / recommended immediate tasks

1. Implement `server/orders.json` and wire create/verify/webhook to persist & transition orders. (Minimal friction)
2. Add idempotent event store (store event id) and webhook audit log.
3. Add `receipt.html` page and link redirect after verify/webhook.
4. Prepare GitHub Actions to deploy frontend to S3 and backend to Beanstalk/ECS.

---

## Changelog

* 2025-08-15 — Initial detailed checkout integration guide created from `PAYMENT_INTEGRATION_STATUS.md` and roadmap.

---

If you want, I can now:

* Patch your repository with the backend `server/index.js` and `orders.json` example.
* Insert the frontend snippet into `cart.html` or `assets/js/cart.js`.
* Provide a GitHub Actions workflow for frontend S3 deploy + backend Elastic Beanstalk deployment.

Pick one and I will implement it immediately and update the canvas file with changes.
