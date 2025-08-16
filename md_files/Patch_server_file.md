# Patch & commit: Replace `server/index.js` with a safe, non-blocking skeleton

This document explains exactly how to **patch your `server/index.js`** to the safe skeleton (non-blocking startup, route-scoped raw parser for webhooks, health endpoint, heartbeat, async file ensures), **how to test it locally**, and the exact **git** commands to commit the change. Follow the steps below — copy/paste the new file contents, run the checks, then commit.

> **Important:** Back up your current `server/index.js` before overwriting. The skeleton is designed to be minimal and safe; reintroduce existing business logic incrementally after verifying the skeleton works.

---

## 1) Backup current file (do this first)

From your repo root:

```bash
cd server
cp index.js index.js.bak
# or on Windows PowerShell:
Copy-Item index.js index.js.bak
```

---

## 2) Replace `server/index.js` with the safe skeleton

Create (or overwrite) `server/index.js` with the content below. This version uses async file initialization (no blocking `readJsonSync` at startup), `bodyParser.raw` only on the webhook route, `morgan` request logging, a `GET /api/health` endpoint, and a heartbeat log so you can see the process is alive.

```js
// server/index.js
require('dotenv').config();
const express = require('express');
const morgan = require('morgan');
const bodyParser = require('body-parser');
const fs = require('fs-extra');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const Razorpay = require('razorpay');
const crypto = require('crypto');

const app = express();
app.use(morgan('dev'));
app.use(express.json()); // normal JSON for the app

const PORT = process.env.PORT || 3001;
const ORDERS_FILE = path.join(__dirname, 'orders.json');
const PROCESSED_FILE = path.join(__dirname, 'processed_webhooks.json');
const WEBHOOK_AUDIT = path.join(__dirname, 'webhook_audit.log');

// Ensure storage files exist (async, non-blocking)
(async () => {
  try {
    await fs.ensureFile(ORDERS_FILE);
    await fs.ensureFile(PROCESSED_FILE);
    await fs.ensureFile(WEBHOOK_AUDIT);
    console.log('Storage files ensured (async)');
  } catch (err) {
    console.warn('Failed to ensure storage files:', err);
  }
})();

// heartbeat to show process is responsive
const startTime = Date.now();
setInterval(() => {
  const uptime = Math.round((Date.now() - startTime) / 1000);
  const memMB = Math.round(process.memoryUsage().rss / 1024 / 1024);
  console.log(`heartbeat: pid=${process.pid} uptime=${uptime}s rss=${memMB}MB`);
}, 30_000);

// health endpoint
app.get('/api/health', (req, res) => {
  res.json({ ok: true, pid: process.pid, uptime: process.uptime() });
});

// Example ping
app.get('/api/ping', (req, res) => res.send('pong'));

// Helper persistence functions (file-based for dev)
function loadJsonSafe(filePath) {
  try {
    const data = fs.readJsonSync(filePath);
    return Array.isArray(data) ? data : [];
  } catch (e) {
    return [];
  }
}
function saveJsonSafe(filePath, data) {
  try {
    fs.writeJsonSync(filePath, data, { spaces: 2 });
  } catch (e) {
    console.error('Failed to save', filePath, e);
  }
}
function appendAudit(text) {
  try {
    fs.appendFileSync(WEBHOOK_AUDIT, `${new Date().toISOString()} ${text}\n`);
  } catch (e) {
    console.error('Failed to append audit log', e);
  }
}

// Minimal Razorpay client (keys must be in .env)
const rzp = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID || '',
  key_secret: process.env.RAZORPAY_KEY_SECRET || ''
});

// Simple amount calculator (dev only) - replace with DB logic in prod
function computeAmountPaise(cart) {
  const totalRupees = (cart?.items || []).reduce((s, it) => s + ((it.unit_price || 0) * (it.qty || 0)), 0);
  return Math.round(totalRupees * 100);
}

/**
 * POST /api/checkout/create-order
 * - validate cart (server-side)
 * - persist local order with status CREATED
 * - create Razorpay order and return order id + razorpay key id
 */
app.post('/api/checkout/create-order', async (req, res) => {
  try {
    const { cart, customer } = req.body;
    const amountPaise = computeAmountPaise(cart || {});
    if (!amountPaise || amountPaise <= 0) return res.status(400).send('Invalid amount');

    const localOrderId = uuidv4();
    const orders = loadJsonSafe(ORDERS_FILE);
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
    saveJsonSafe(ORDERS_FILE, orders);

    const orderOptions = {
      amount: amountPaise,
      currency: 'INR',
      receipt: `cp_${localOrderId}`,
      notes: { localOrderId }
    };
    const razorpayOrder = await rzp.orders.create(orderOptions);

    // persist razorpay_order_id mapping
    localOrder.razorpay_order_id = razorpayOrder.id;
    saveJsonSafe(ORDERS_FILE, orders);

    return res.json({
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

/**
 * POST /api/checkout/verify
 * - called by client after Checkout handler for UX
 * - still treat webhook as source-of-truth
 */
app.post('/api/checkout/verify', (req, res) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, localOrderId } = req.body;
    const body = (razorpay_order_id || '') + '|' + (razorpay_payment_id || '');
    const expected = crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET || '').update(body).digest('hex');
    if (expected !== razorpay_signature) {
      console.warn('signature_mismatch', { expected, got: razorpay_signature });
      return res.status(400).json({ verified: false, reason: 'signature_mismatch' });
    }

    const orders = loadJsonSafe(ORDERS_FILE);
    const o = orders.find(x => x.id === localOrderId || x.razorpay_order_id === razorpay_order_id);
    if (o) {
      o.razorpay_payment_id = razorpay_payment_id;
      o.status = 'PAYMENT_PENDING';
      o.updated_at = new Date().toISOString();
      saveJsonSafe(ORDERS_FILE, orders);
    }
    return res.json({ verified: true });
  } catch (err) {
    console.error('verify error', err);
    return res.status(500).send('verify-failed');
  }
});

/**
 * Webhook route: use route-scoped raw parser (do NOT set raw globally)
 * - verifies X-Razorpay-Signature using WEBHOOK_SECRET
 * - appends raw payload to audit log
 * - uses processed_webhooks.json and idempotency check
 */
app.post('/api/checkout/webhook', bodyParser.raw({ type: 'application/json' }), (req, res) => {
  try {
    const raw = req.body.toString();
    appendAudit(raw);

    const sig = req.headers['x-razorpay-signature'] || '';
    const webhookSecret = process.env.WEBHOOK_SECRET || '';
    const expected = crypto.createHmac('sha256', webhookSecret).update(raw).digest('hex');
    if (expected !== sig) {
      console.warn('Invalid webhook signature', { expected, got: sig });
      return res.status(400).send('invalid signature');
    }

    const event = JSON.parse(raw);
    const eventId = event && event.id ? event.id : (event.payload?.payment?.entity?.id || null);

    const processed = loadJsonSafe(PROCESSED_FILE);
    if (eventId && processed.includes(eventId)) {
      console.log('Webhook already processed:', eventId);
      return res.status(200).send('already processed');
    }

    // save processed id early to avoid double processing if crash occurs later
    if (eventId) {
      processed.push(eventId);
      saveJsonSafe(PROCESSED_FILE, processed);
    }

    // handle events
    if (event.event === 'payment.captured' || event.event === 'order.paid') {
      const payment = event.payload?.payment?.entity || null;
      if (payment) {
        const rzpOrderId = payment.order_id;
        const orders = loadJsonSafe(ORDERS_FILE);
        const o = orders.find(x => x.razorpay_order_id === rzpOrderId || (payment.notes?.localOrderId && x.id === payment.notes.localOrderId));
        if (o && o.status !== 'PAID') {
          o.status = 'PAID';
          o.razorpay_payment_id = payment.id;
          o.updated_at = new Date().toISOString();
          saveJsonSafe(ORDERS_FILE, orders);
          console.log('Order marked PAID:', o.id);
        } else {
          console.log('Order not found or already PAID for rzpOrderId:', rzpOrderId);
        }
      }
    } else if (event.event === 'payment.failed') {
      const payment = event.payload?.payment?.entity || null;
      if (payment) {
        const rzpOrderId = payment.order_id;
        const orders = loadJsonSafe(ORDERS_FILE);
        const o = orders.find(x => x.razorpay_order_id === rzpOrderId || (payment.notes?.localOrderId && x.id === payment.notes.localOrderId));
        if (o && o.status !== 'FAILED') {
          o.status = 'FAILED';
          o.updated_at = new Date().toISOString();
          saveJsonSafe(ORDERS_FILE, orders);
          console.log('Order marked FAILED:', o.id);
        }
      }
    }

    return res.status(200).send('ok');
  } catch (err) {
    console.error('webhook processing error', err);
    return res.status(500).send('webhook-error');
  }
});

// start server
app.listen(PORT, () => {
  console.log(`Cart API listening on port ${PORT}`);
});
```

---

## 3) Install required packages (if not already present)

From `/server`:

```bash
npm install express morgan body-parser fs-extra uuid razorpay dotenv
# if you want nodemon for dev:
npm install -D nodemon
```

Add a `start` script in `server/package.json` if needed:

```json
"scripts": {
  "start": "node index.js",
  "dev": "nodemon index.js"
}
```

---

## 4) Start the server and run quick checks

Stop any existing server bound to port 3001 first (example commands):

**Windows (PowerShell):**

```powershell
netstat -ano | findstr :3001
# find PID from output, then:
taskkill /PID <PID> /F
```

**macOS / Linux:**

```bash
lsof -i :3001
kill -9 <PID>
```

Now start the server:

```bash
cd server
npm start
# or for dev:
npm run dev
```

Expected console output:

```
Storage files ensured (async)
Cart API listening on port 3001
heartbeat: ...
```

Test endpoints:

```bash
curl -i http://localhost:3001/api/health
# or
curl -i http://localhost:3001/api/ping
```

You should get a quick response. If `curl` returns quickly, the server is responsive.

---

## 5) If tests pass — commit the change

From repo root:

```bash
git add server/index.js
git add server/package.json   # if you modified scripts or installed packages
git add server/processed_webhooks.json server/orders.json server/webhook_audit.log
git commit -m "chore(server): replace index.js with safe non-blocking skeleton; add storage files"
git push
```

> If you don't want to push yet, use `git commit` only. If you already have CI that runs on push, be mindful.

---

## 6) Rollback plan (if something breaks)

If you need to revert the change:

```bash
cd server
mv index.js.bak index.js
# or
git checkout -- server/index.js
npm start
```

---

## 7) Next steps (after healthy skeleton)

1. Reintroduce your original business logic incrementally:

   * Merge your old handlers (create-order, verify, webhook logic) back into this skeleton — preferably one endpoint at a time.
   * Keep the route-scoped `bodyParser.raw` for webhooks only.
   * Replace `loadJsonSafe`/`saveJsonSafe` with async functions or a DB for production.

2. Add improved logging for operations (file reads/writes, remote API calls).

3. Use `pm2` in production or `nodemon` in dev.

---

## 8) Troubleshooting tips (if server still appears stuck)

* Look for long synchronous operations (large file reads, synchronous crypto work).
* Temporarily add `console.log(...)` lines around suspected code to find the blocking line.
* Run `node --inspect index.js` and attach chrome devtools: `chrome://inspect` to snapshot the event loop.
* If you see `heartbeat` logs in the console but curl still times out, check firewall / host binding (0.0.0.0 vs 127.0.0.1) or reverse proxy.

---

If you want, I can now:

* Create the files and commit the change for you (I will update the repo and show the diff), or
* Produce a merged patch that preserves your original endpoints while applying the safe improvements.

Tell me if you want me to **commit this patch** to the repo, or if you'd rather apply it yourself.
