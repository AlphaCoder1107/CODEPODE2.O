Great — below is a complete, **actionable step-by-step guide** (markdown) that shows exactly what to add/change to **implement persisted `orders.json`** and an **idempotent webhook processor** (with audit logs and processed-event tracking). It includes full updated `server/index.js` code you can drop into your repo, the small files to create, commands to run, and tests to verify duplication handling.

Copy this into your repo as `IMPLEMENT_IDEMPOTENT_WEBHOOK.md` (or paste the relevant parts into your existing roadmap/canvas doc). I've made the implementation intentionally simple and safe for local/dev use (file persistence). In production you should switch the persistence parts to a proper DB (Postgres/DynamoDB) and use DB transactions.

---

# Implement idempotent webhook + persisted orders.json

## Goal

* Persist orders created by `/api/checkout/create-order` into `server/orders.json`.
* Audit every incoming webhook payload into `server/webhook_audit.log`.
* Maintain a `server/processed_webhooks.json` file of processed event IDs to ensure idempotency (if a webhook is re-delivered, we ignore it).
* Update order state (`CREATED` → `PAYMENT_PENDING` → `PAID`) reliably.

---

## Files to add / update

1. **Update** `server/index.js` (replace or patch with the code below).
2. **Create** these files (empty/initial content):

```
server/orders.json               # initialize with []
server/processed_webhooks.json   # initialize with []
server/webhook_audit.log         # created by server append
```

Commands (run from repo root):

```bash
mkdir -p server
echo "[]" > server/orders.json
echo "[]" > server/processed_webhooks.json
touch server/webhook_audit.log
```

Install required packages:

```bash
cd server
npm install express razorpay body-parser dotenv uuid fs-extra morgan
# if you already have some of them installed, npm will skip duplicates
```

---

## Full `server/index.js` (drop in /server/index.js)

Replace your existing `server/index.js` with the code below (or merge the changes into your file). This includes: persisted orders, processed-events idempotency, audit log, simple computeAmountPaise placeholder, and helpful logs.

```js
// server/index.js
require('dotenv').config();
const express = require('express');
const Razorpay = require('razorpay');
const crypto = require('crypto');
const bodyParser = require('body-parser');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs-extra');
const path = require('path');
const morgan = require('morgan');

const app = express();
app.use(express.json());
app.use(morgan('dev'));

const PORT = process.env.PORT || 3001;
const ORDERS_FILE = path.join(__dirname, 'orders.json');
const PROCESSED_FILE = path.join(__dirname, 'processed_webhooks.json');
const WEBHOOK_AUDIT = path.join(__dirname, 'webhook_audit.log');

// Ensure files exist
fs.ensureFileSync(ORDERS_FILE);
fs.ensureFileSync(PROCESSED_FILE);
fs.ensureFileSync(WEBHOOK_AUDIT);

// Helper functions for file persistence
function loadOrders() {
  try {
    const arr = fs.readJsonSync(ORDERS_FILE);
    return Array.isArray(arr) ? arr : [];
  } catch (e) {
    return [];
  }
}
function saveOrders(arr) {
  // atomic-ish write
  fs.writeJsonSync(ORDERS_FILE, arr, { spaces: 2 });
}

function loadProcessed() {
  try {
    const arr = fs.readJsonSync(PROCESSED_FILE);
    return Array.isArray(arr) ? arr : [];
  } catch (e) {
    return [];
  }
}
function saveProcessed(arr) {
  fs.writeJsonSync(PROCESSED_FILE, arr, { spaces: 2 });
}

function appendAuditLog(text) {
  // append with timestamp
  fs.appendFileSync(WEBHOOK_AUDIT, (new Date().toISOString() + ' ' + text + '\n'));
}

// Razorpay client
const rzp = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID || '',
  key_secret: process.env.RAZORPAY_KEY_SECRET || ''
});

// Simple (dev) total calculation
function computeAmountPaise(cart) {
  // WARNING: replace this with DB price lookup in production
  // Expected cart: { items: [{id, qty, unit_price}], ... }
  const totalRupees = (cart.items || []).reduce((s, it) => s + (it.unit_price || 0) * (it.qty || 0), 0);
  return Math.round(totalRupees * 100); // paise
}

// Create order endpoint
app.post('/api/checkout/create-order', async (req, res) => {
  try {
    const { cart, customer } = req.body;
    const amountPaise = computeAmountPaise(cart || {});
    if (!amountPaise || amountPaise <= 0) return res.status(400).send('Invalid amount');

    const localOrderId = uuidv4();
    const orders = loadOrders();
    const localOrder = {
      id: localOrderId,
      items: cart.items || [],
      amount_paise: amountPaise,
      currency: 'INR',
      status: 'CREATED',
      created_at: new Date().toISOString(),
      customer: customer || {}
    };
    orders.push(localOrder);
    saveOrders(orders);

    const orderOptions = {
      amount: amountPaise,
      currency: 'INR',
      receipt: `cp_${localOrderId}`,
      notes: { localOrderId }
    };
    const razorpayOrder = await rzp.orders.create(orderOptions);

    // map rzp order id into local order and persist
    localOrder.razorpay_order_id = razorpayOrder.id;
    saveOrders(orders);

    res.json({
      razorpayKeyId: process.env.RAZORPAY_KEY_ID,
      orderId: razorpayOrder.id,
      amount: razorpayOrder.amount,
      currency: razorpayOrder.currency,
      localOrderId,
      customer: customer || {}
    });
  } catch (err) {
    console.error('create-order error', err);
    res.status(500).send('create-order-failed');
  }
});

// Immediate verify endpoint (called by frontend handler)
app.post('/api/checkout/verify', async (req, res) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, localOrderId } = req.body;
    const body = razorpay_order_id + '|' + razorpay_payment_id;
    const expectedSignature = crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET || '').update(body).digest('hex');

    if (expectedSignature !== razorpay_signature) {
      console.warn('signature_mismatch', { expectedSignature, razorpay_signature });
      return res.status(400).json({ verified: false, reason: 'signature_mismatch' });
    }

    // Mark local order as PAYMENT_PENDING (we’ll mark PAID in webhook)
    const orders = loadOrders();
    const o = orders.find(x => x.id === localOrderId || x.razorpay_order_id === razorpay_order_id);
    if (o) {
      o.razorpay_payment_id = razorpay_payment_id;
      o.status = 'PAYMENT_PENDING';
      o.updated_at = new Date().toISOString();
      saveOrders(orders);
    }

    res.json({ verified: true });
  } catch (err) {
    console.error('verify error', err);
    res.status(500).send('verify-failed');
  }
});

// Webhook endpoint (raw body required for signature verification)
app.post('/api/checkout/webhook', bodyParser.raw({ type: 'application/json' }), (req, res) => {
  try {
    const webhookSecret = process.env.WEBHOOK_SECRET || '';
    const signature = req.headers['x-razorpay-signature'];
    const raw = req.body.toString();

    // audit raw payload
    appendAuditLog(raw);

    // verify signature
    const expected = crypto.createHmac('sha256', webhookSecret).update(raw).digest('hex');
    if (expected !== signature) {
      console.warn('Invalid webhook signature', { expected, signature });
      return res.status(400).send('invalid signature');
    }

    const event = JSON.parse(raw);
    const eventId = event && (event.id || (event.payload && event.payload.payment && event.payload.payment.entity && event.payload.payment.entity.id)) || null;

    // load processed set
    const processed = loadProcessed();
    if (eventId && processed.includes(eventId)) {
      console.log('Webhook already processed:', eventId);
      return res.status(200).send('already processed');
    }

    // mark as processed (save before doing heavy work to avoid duplicate processing if the process crashes after work)
    if (eventId) {
      processed.push(eventId);
      saveProcessed(processed);
    }

    // handle event types
    if (event.event === 'payment.captured' || (event.event === 'order.paid')) {
      const payment = event.payload && event.payload.payment && event.payload.payment.entity;
      if (payment) {
        const rzpOrderId = payment.order_id;
        const orders = loadOrders();
        const o = orders.find(x => x.razorpay_order_id === rzpOrderId || (payment.notes && payment.notes.localOrderId && x.id === payment.notes.localOrderId));
        if (o) {
          if (o.status !== 'PAID') {
            o.status = 'PAID';
            o.razorpay_payment_id = payment.id;
            o.updated_at = new Date().toISOString();
            saveOrders(orders);
            console.log('Order marked PAID:', o.id);
          } else {
            console.log('Order already PAID:', o.id);
          }
        } else {
          console.warn('No local order found for rzpOrderId:', rzpOrderId);
        }
      }
    } else if (event.event === 'payment.failed') {
      const payment = event.payload && event.payload.payment && event.payload.payment.entity;
      if (payment) {
        const rzpOrderId = payment.order_id;
        const orders = loadOrders();
        const o = orders.find(x => x.razorpay_order_id === rzpOrderId || (payment.notes && payment.notes.localOrderId && x.id === payment.notes.localOrderId));
        if (o && o.status !== 'FAILED') {
          o.status = 'FAILED';
          o.updated_at = new Date().toISOString();
          saveOrders(orders);
          console.log('Order marked FAILED:', o.id);
        }
      }
    }

    // always respond 200 quickly
    res.status(200).send('ok');
  } catch (err) {
    console.error('webhook processing error', err);
    res.status(500).send('webhook-error');
  }
});

// root health check or serving static - tiny health response
app.get('/api/health', (req, res) => res.json({ ok: true }));

app.listen(PORT, () => console.log(`Cart API listening on port ${PORT}`));
```

---

## Notes about the implementation

* **Processed-event check:** we persist `processed_webhooks.json` (array of event IDs). On each webhook we check whether `event.id` exists in that array; if yes — return `200` immediately (idempotent). We save the event ID *before* processing to avoid double work if the server crashes after processing started.
* **Audit log:** `webhook_audit.log` contains raw payloads with timestamps — useful for debugging.
* **Local atomicity:** `fs.writeJsonSync` is used; for a single-instance dev server this is acceptable. For production with multiple app instances, use a shared DB and model the processed\_event table with unique constraint on event\_id to guarantee idempotency.
* **Order lookup:** We match using `razorpay_order_id` saved in local order (or `payment.notes.localOrderId` if Razorpay sends it).
* **Event IDs:** Razorpay webhooks typically have `event.id` you can use; if not present, we attempt to fallback to `payment.id`. Adjust logic based on actual webhook shape if needed.

---

## How to test locally (step-by-step)

1. Start server:

```bash
cd server
node index.js
# or npm start if configured
```

2. Start ngrok to expose local webhook URL:

```bash
ngrok http 3001
# copy public URL, e.g. https://abcd1234.ngrok.io
```

3. Register webhook in Razorpay dev dashboard:

* URL: `https://<ngrok>.io/api/checkout/webhook`
* Events: `payment.captured`, `payment.failed`, `order.paid`
* Copy the webhook secret and set in your `.env` (or export in shell):

```
WEBHOOK_SECRET=<the-secret-from-dashboard>
```

4. Create an order (via frontend or curl) — easiest is to open your cart page and click Proceed to Buy (which calls `/api/checkout/create-order`), complete checkout in Razorpay test mode.

5. Confirm immediate verification: front-end `handler` will call `/api/checkout/verify` which will set order.status to `PAYMENT_PENDING`.

6. Confirm webhook processed:

* Check `server/webhook_audit.log` for raw payload.
* Check `server/processed_webhooks.json` contains the event id.
* Check `server/orders.json` shows status `PAID`.

7. **Replay webhook and confirm idempotency**:

* Save the last webhook raw payload from `webhook_audit.log` to a file `sample_webhook.json`.
* Compute correct signature (local helper below).
* Re-post the webhook using curl:

```bash
# compute signature using node (see next block)
# assume SIGNATURE=<computed_signature>
curl -v -H "Content-Type: application/json" -H "X-Razorpay-Signature: $SIGNATURE" \
  -d @sample_webhook.json \
  https://<ngrok>.io/api/checkout/webhook
```

* The server should log `Webhook already processed:` or return `200` and not re-mark the order or create duplicates.

### Helper: compute signature (for replays)

Create `scripts/compute_signature.js`:

```js
// scripts/compute_signature.js
const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const payloadFile = process.argv[2]; // e.g. sample_webhook.json
const secret = process.argv[3]; // webhook secret

if (!payloadFile || !secret) {
  console.error('Usage: node compute_signature.js <payloadFile> <webhookSecret>');
  process.exit(1);
}

const raw = fs.readFileSync(path.resolve(payloadFile)).toString();
const sig = crypto.createHmac('sha256', secret).update(raw).digest('hex');
console.log(sig);
```

Run:

```bash
node scripts/compute_signature.js sample_webhook.json <WEBHOOK_SECRET>
# The script prints the signature you can use in X-Razorpay-Signature header
```

---

## Quick checklist after implementation

* [ ] `server/orders.json` created and updated when creating orders.
* [ ] `server/processed_webhooks.json` created and updated when webhook received.
* [ ] `server/webhook_audit.log` contains raw webhook payloads.
* [ ] Replaying the same webhook does not change order state or duplicate processing.
* [ ] `/api/checkout/verify` marks order `PAYMENT_PENDING` (frontend UX) while webhook sets `PAID`.
* [ ] Test both `payment.captured` and `payment.failed` flows.

---

## Production follow-ups (recommended after tests)

* Replace file-storage with a database (RDS/DynamoDB). In the DB:

  * `orders` table for orders.
  * `webhook_events` table with unique constraint on `event_id` to enforce idempotency atomically.
* Use a transaction: insert event id into `webhook_events` with unique constraint, if it fails (duplicate) skip processing.
* Add monitoring/alerts for webhook failures and signature mismatches.
* Rotate `WEBHOOK_SECRET` if compromised, and update server config.

---