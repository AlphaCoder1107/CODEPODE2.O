// Minimal payments-link server (single-file)
const express = require('express');
const cors = require('cors');
const fs = require('fs-extra');
const path = require('path');
const morgan = require('morgan');
require('dotenv').config();

const Razorpay = require('razorpay');

const app = express();
app.use(cors());
// capture raw body for webhook verification while still parsing JSON for other routes
app.use(express.json({ verify: (req, _res, buf) => { req.rawBody = buf; } }));
app.use(morgan('dev'));
const crypto = require('crypto');
const WEBHOOK_AUDIT = path.join(__dirname, 'webhook_audit.log');

const PORT = process.env.PORT || 8080;
const ORDERS_FILE = path.join(__dirname, 'orders.json');

const rzp = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID || '',
  key_secret: process.env.RAZORPAY_KEY_SECRET || ''
});

// Ensure orders file exists
(async () => {
  try {
    await fs.ensureFile(ORDERS_FILE);
    const d = await fs.readJson(ORDERS_FILE).catch(() => null);
    if (!d) await fs.writeJson(ORDERS_FILE, []);
  } catch (e) {
    console.warn('ensure orders failed', e && e.message);
  }
})();

function loadOrders() { try { return fs.readJsonSync(ORDERS_FILE); } catch (e) { return []; } }
function saveOrders(o) { try { fs.writeJsonSync(ORDERS_FILE, o, { spaces: 2 }); } catch (e) { console.warn('saveOrders failed', e && e.message) } }

// small helper to escape HTML when injecting values into server-rendered templates
function escapeHtml(input) {
  const s = (input === null || input === undefined) ? '' : String(input);
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

app.get('/api/health', (req, res) => res.json({ ok: true, pid: process.pid }));

// Public config for client: expose only the publishable Key ID (safe)
app.get('/api/config', (req, res) => {
  return res.json({ key: process.env.RAZORPAY_KEY_ID || '' });
});

// Serve static files from parent directory in development
if (process.env.NODE_ENV !== 'production') {
  app.use(express.static(path.join(__dirname, '..')));
}

// Serve cart.html dynamically with injected public Razorpay key so the static
// file doesn't need to contain a hardcoded publishable key.
app.get('/cart.html', (req, res) => {
  try {
    const SITE_ROOT = path.join(__dirname, '..');
    const cartPath = path.join(SITE_ROOT, 'cart.html');
    let html = fs.readFileSync(cartPath, 'utf8');
    const key = process.env.RAZORPAY_KEY_ID || '';
    const inject = `<script>window.RAZORPAY_KEY_ID = ${JSON.stringify(key)};</script>`;
    // Insert injection just before the cart.js include if present, otherwise append to head
    // If a server-side cart is provided via ?cart=..., render items into the template
  const cartParam = req.query && req.query.cart ? String(req.query.cart) : '';
  console.log('/cart.html query keys=', Object.keys(req.query || {}), 'cartParam_len=', (cartParam && cartParam.length) || 0);
    if (cartParam) {
      let parsed = null;
      try {
        // Express already decodes query params; try parse directly
        parsed = JSON.parse(cartParam);
      } catch (e) {
        parsed = null;
      }
      if (!parsed) {
        try {
          // Try base64 (common when sending binary-safe encodings)
          const buf = Buffer.from(cartParam, 'base64');
          const s = buf.toString('utf8');
          parsed = JSON.parse(s);
        } catch (e) { parsed = null; }
      }
      console.debug('server: cartParam present, parsed?', !!parsed);

      // parsed should be an array of items or an object with items
      const items = (parsed && Array.isArray(parsed)) ? parsed : (parsed && parsed.items ? parsed.items : []);
      // Build server-rendered item HTML
      function renderItems(itemsArr) {
        if (!itemsArr || !itemsArr.length) return '<p>Your cart is empty.</p>';
        return itemsArr.map(it => {
          const title = escapeHtml(it.title || 'Item');
          const qty = Number(it.qty || 1);
          const price = Number(it.price || 0).toFixed(2);
          const img = escapeHtml(it.img || '/pi_2W/img1 codepod.jpg');
          return `  <div class="cart-item">\n    <img src="${img}" alt=""/>\n    <div class="meta">\n      <strong>${title}</strong>\n      <div>Qty: ${qty}</div>\n      <div>Price: ₹${price}</div>\n    </div>\n  </div>`;
        }).join('\n');
      }

      const rendered = renderItems(items);
      // Replace placeholder div if present, otherwise append
      if (html.indexOf('<div id="cartList">') !== -1) {
        html = html.replace(/<div id="cartList">[\s\S]*?<\/div>/, `<div id="cartList">\n${rendered}\n</div>`);
      } else {
        html = html.replace('</body>', `<div id="cartList">\n${rendered}\n</div>\n</body>`);
      }
      // Also inject a small script so client knows this was server-rendered
      const srvNote = `<script>window.__serverRenderedCart = true; window.__serverCart = ${JSON.stringify({ items })};</script>`;
      if (html.indexOf('</body>') !== -1) html = html.replace('</body>', `  ${srvNote}\n</body>`); else html += `\n${srvNote}`;
      // Ensure the public key is still available
      if (html.indexOf('<script src="/assets/js/cart.js"></script>') !== -1) {
        html = html.replace('<script src="/assets/js/cart.js"></script>', inject + '\n  <script src="/assets/js/cart.js"></script>');
      } else if (html.indexOf('</head>') !== -1) {
        html = html.replace('</head>', `  ${inject}\n</head>`);
      } else {
        html = inject + '\n' + html;
      }
      res.set('Content-Type', 'text/html');
      return res.send(html);
    }

    // Default behavior: inject publishable key and return the static template
    if (html.indexOf('<script src="/assets/js/cart.js"></script>') !== -1) {
      html = html.replace('<script src="/assets/js/cart.js"></script>', inject + '\n  <script src="/assets/js/cart.js"></script>');
    } else if (html.indexOf('</head>') !== -1) {
      html = html.replace('</head>', `  ${inject}\n</head>`);
    } else {
      html = inject + '\n' + html;
    }
    res.set('Content-Type', 'text/html');
    return res.send(html);
  } catch (e) {
    console.error('failed to serve cart.html dynamically', e && e.message);
    return res.status(500).send('internal');
  }
});

// POST /cart/print - accept JSON body { items: [...] } and return server-rendered cart HTML
app.post('/cart/print', express.json(), (req, res) => {
  try {
    const items = Array.isArray(req.body) ? req.body : (req.body && Array.isArray(req.body.items) ? req.body.items : []);
    const SITE_ROOT = path.join(__dirname, '..');
    const cartPath = path.join(SITE_ROOT, 'cart.html');
    let html = fs.readFileSync(cartPath, 'utf8');

    function escape(s){ return escapeHtml(s || ''); }
    function renderItems(itemsArr) {
      if (!itemsArr || !itemsArr.length) return '<p>Your cart is empty.</p>';
      return itemsArr.map(it => {
        const title = escape(it.title || 'Item');
        const qty = Number(it.qty || 1);
        const price = Number(it.price || 0).toFixed(2);
        const img = escape(it.img || '/pi_2W/img1 codepod.jpg');
        return `  <div class="cart-item">\n    <img src="${img}" alt=""/>\n    <div class="meta">\n      <strong>${title}</strong>\n      <div>Qty: ${qty}</div>\n      <div>Price: ₹${price}</div>\n    </div>\n  </div>`;
      }).join('\n');
    }

    const rendered = renderItems(items);
    if (html.indexOf('<div id="cartList">') !== -1) {
      html = html.replace(/<div id="cartList">[\s\S]*?<\/div>/, `<div id="cartList">\n${rendered}\n</div>`);
    } else if (html.indexOf('</body>') !== -1) {
      html = html.replace('</body>', `<div id="cartList">\n${rendered}\n</div>\n</body>`);
    } else {
      html += `\n<div id="cartList">\n${rendered}\n</div>`;
    }

    // inject a small server-side flag for client scripts
    const srvNote = `<script>window.__serverRenderedCart = true; window.__serverCart = ${JSON.stringify({ items })};</script>`;
    if (html.indexOf('</body>') !== -1) html = html.replace('</body>', `  ${srvNote}\n</body>`); else html += `\n${srvNote}`;

    // ensure key injection
    const key = process.env.RAZORPAY_KEY_ID || '';
    const inject = `<script>window.RAZORPAY_KEY_ID = ${JSON.stringify(key)};</script>`;
    if (html.indexOf('<script src="/assets/js/cart.js"></script>') !== -1) {
      html = html.replace('<script src="/assets/js/cart.js"></script>', inject + '\n  <script src="/assets/js/cart.js"></script>');
    } else if (html.indexOf('</head>') !== -1) {
      html = html.replace('</head>', `  ${inject}\n</head>`);
    } else {
      html = inject + '\n' + html;
    }

    res.set('Content-Type', 'text/html');
    return res.send(html);
  } catch (e) {
    console.error('cart/print failed', e && e.stack ? e.stack : e && e.message);
    return res.status(500).send('internal');
  }
});

// Serve thank-you page with injected order details from query params
app.get('/thank-you.html', (req, res) => {
  try {
    const SITE_ROOT = path.join(__dirname, '..');
    const filePath = path.join(SITE_ROOT, 'thank-you.html');
    let html = fs.readFileSync(filePath, 'utf8');
    const order = (req.query.order) ? String(req.query.order) : '';
    const amount = (req.query.amount) ? String(req.query.amount) : '';
    const currency = (req.query.currency) ? String(req.query.currency) : '';
    const injected = `<script>window.CodePodOrder = ${JSON.stringify({ order, amount, currency })};</script>`;
    if (html.indexOf('</body>') !== -1) {
      html = html.replace('</body>', `  ${injected}\n  </body>`);
    } else {
      html = html + '\n' + injected;
    }
    res.set('Content-Type', 'text/html');
    return res.send(html);
  } catch (e) {
    console.error('failed to serve thank-you dynamically', e && e.message);
    return res.status(500).send('internal');
  }
});

// TODO: Remove this endpoint after v1.1 release (deprecated in Aug 2025)
app.post('/api/create-payment-link', async (req, res) => {
  // Deprecated endpoint: prefer Orders API
  console.warn('⚠️ /api/create-payment-link is deprecated; use /api/create-order instead');
  return res.status(410).json({ error: 'Deprecated endpoint' });

  try {
    const { amount, amount_paise, currency = 'INR', customer = {}, description = 'CodePod order' } = req.body || {};
    let paise = null;
    if (typeof amount_paise === 'number') paise = amount_paise;
    else if (typeof amount === 'number') paise = Math.round(amount * 100);
    else if (typeof amount === 'string' && !isNaN(Number(amount))) paise = Math.round(Number(amount) * 100);
    if (!paise || paise <= 0) return res.status(400).json({ error: 'invalid_amount' });

    // Use libphonenumber-js for robust phone parsing/validation
    const { parsePhoneNumberFromString } = require('libphonenumber-js');
    const rawPhone = (customer && customer.phone) ? String(customer.phone) : '';
    let normalizedPhone = '';
    const skipContact = Boolean(customer && customer.skip_contact);
    if (!skipContact && rawPhone) {
      try {
        const p = parsePhoneNumberFromString(rawPhone, 'IN');
        if (!p || !p.isValid()) {
          return res.status(400).json({ error: 'invalid_phone', message: 'Customer phone number looks invalid — please provide a valid India mobile number (e.g. 9876543210) or set customer.skip_contact=true for test checkouts.' });
        }
        // normalized as national number (10 digits) if available; otherwise strip digits
        normalizedPhone = (p && p.nationalNumber) ? String(p.nationalNumber) : String(p.format && p.format('NATIONAL') || '').replace(/[^0-9]/g, '');
        // Reject low-entropy numbers (few distinct digits)
        const distinctCount = new Set(String(normalizedPhone)).size;
        if (distinctCount < 4) {
          return res.status(400).json({ error: 'invalid_phone', message: 'Customer phone number looks invalid — too few distinct digits. Please provide a valid mobile number.' });
        }
      } catch (e) {
        return res.status(400).json({ error: 'invalid_phone', message: 'Customer phone number looks invalid — please provide a valid India mobile number or set customer.skip_contact=true for test checkouts.' });
      }
    }

    const orders = loadOrders();
    const localId = 'local_' + Date.now();
    const local = { id: localId, amount_paise: paise, currency, description, customer, status: 'CREATED', createdAt: new Date().toISOString() };
    orders.push(local); saveOrders(orders);

    const payload = {
      amount: paise,
      currency,
      accept_partial: false,
      description,
      reference_id: localId,
  customer: { name: customer.name || '', email: customer.email || '', contact: (normalizedPhone || '') },
      notify: { sms: false, email: false },
      reminder_enable: false
    };

    // Call Razorpay SDK to create a payment link. Add verbose error logging so
    // any SDK error shapes are recorded to the server log for debugging.
    let resp;
    try {
      resp = await rzp.paymentLink.create(payload);
    } catch (e) {
      // Try to print as much useful debugging information as possible
      try {
        const util = require('util');
        console.error('razorpay create failed (inspected):', util.inspect(e, { depth: 6 }));
        if (e && e.response) console.error('razorpay error response:', util.inspect(e.response, { depth: 6 }));
      } catch (inner) {
        console.error('razorpay create failed, could not inspect error:', inner && inner.stack ? inner.stack : inner);
      }
      // rethrow so outer catch logs and returns 500
      throw e;
    }
    local.razorpay_link_id = resp.id;
    local.razorpay_short_url = resp.short_url;
    local.razorpay_response = resp;
    saveOrders(orders);

    return res.json({ ok: true, short_url: resp.short_url, localOrderId: localId });
  } catch (err) {
    // Log detailed error for debugging (stack and any response body)
    console.error('create-payment-link failed', err && err.stack ? err.stack : (err && err.message) );
    if (err && err.response) console.error('razorpay-response:', err.response);
    return res.status(500).json({ error: 'create-payment-link-failed' });
  }
});

// Create a Razorpay Order (for Checkout.js flow)
app.post('/api/create-order', async (req, res) => {
  try {
    const { amount, currency = 'INR', receipt, customer = {}, description = 'CodePod order' } = req.body || {};
    let paise = null;
    if (typeof amount === 'number') paise = Math.round(amount);
    else if (typeof amount === 'string' && !isNaN(Number(amount))) paise = Math.round(Number(amount));
    // amount must be in paise already for this endpoint (frontend should multiply rupees*100)
    if (!paise || paise <= 0) return res.status(400).json({ error: 'invalid_amount', message: 'Amount (in paise) is required' });

    const orders = loadOrders();
    const localId = 'local_' + Date.now();
    const local = { id: localId, amount_paise: paise, currency, description, customer, status: 'ORDER_CREATED', createdAt: new Date().toISOString() };
    orders.push(local); saveOrders(orders);

    const options = {
      amount: paise,
      currency,
      receipt: receipt || localId,
      payment_capture: 1,
      notes: { reference: localId }
    };

    const order = await rzp.orders.create(options);
    // persist razorpay order id for reconciliation
    local.razorpay_order_id = order.id;
    local.razorpay_order = order;
    saveOrders(orders);

    return res.json({ ok: true, order, key: process.env.RAZORPAY_KEY_ID || '', localOrderId: localId });
  } catch (err) {
    console.error('create-order failed', err && err.stack ? err.stack : err && err.message);
    return res.status(500).json({ ok: false, error: 'create-order-failed' });
  }
});

// Verify Checkout.js payment signature (called from frontend handler)
app.post('/api/verify-payment', express.json(), (req, res) => {
  try {
    const { razorpay_payment_id, razorpay_order_id, razorpay_signature } = req.body || {};
    if (!razorpay_payment_id || !razorpay_order_id || !razorpay_signature) return res.status(400).json({ ok: false, error: 'missing_fields' });

    const expected = crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET || '').update(razorpay_order_id + '|' + razorpay_payment_id).digest('hex');
    if (expected !== razorpay_signature) {
      console.warn('verify-payment signature mismatch', { expected, got: razorpay_signature });
      return res.status(400).json({ ok: false, error: 'invalid_signature' });
    }

    // mark local order as PAID if found
    const orders = loadOrders();
    const matched = orders.find(o => o.razorpay_order_id === razorpay_order_id || (o.razorpay_order && o.razorpay_order.id === razorpay_order_id));
    if (matched) {
      matched.status = 'PAID';
      matched.razorpay_payment_id = razorpay_payment_id;
      matched.lastVerifiedAt = new Date().toISOString();
      saveOrders(orders);
      return res.json({ ok: true, matched: matched.id });
    }
    return res.status(404).json({ ok: false, error: 'order_not_found' });
  } catch (err) {
    console.error('verify-payment error', err && err.stack ? err.stack : err && err.message);
    return res.status(500).json({ ok: false, error: 'internal' });
  }
});

// Server-side printable receipt: /receipt.html?order=<localId|razorpayOrderId>
app.get('/receipt.html', (req, res) => {
  try {
    const q = req.query || {};
    const lookup = String(q.order || '').trim();
    if (!lookup) return res.status(400).send('Missing `order` query parameter');

    const orders = loadOrders();
    const o = orders.find(x => x.id === lookup || x.razorpay_order_id === lookup || (x.razorpay_order && x.razorpay_order.id === lookup));
    if (!o) return res.status(404).send('Order not found');

    const amountPaise = (o.amount_paise || (o.razorpay_order && o.razorpay_order.amount) || 0);
    const currency = o.currency || (o.razorpay_order && o.razorpay_order.currency) || 'INR';
    const paymentId = o.razorpay_payment_id || (o.razorpay_payment && o.razorpay_payment.id) || '';
    const status = (o.status || '').toUpperCase() || (paymentId ? 'PAID' : 'CREATED');
    const created = o.createdAt || o.lastWebhookAt || '';
    const customer = o.customer || {};

    function fmtAmount(a, c) {
      const p = Number(a || 0);
      const rupees = (p / 100).toFixed(2);
      if ((c || 'INR').toUpperCase() === 'INR') return '\u20B9' + rupees;
      return rupees + ' ' + (c || '');
    }

    const html = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Receipt — CodePod</title>
    <style>
      body{font-family:Inter,Arial,Helvetica,sans-serif;background:#f3f4f6;padding:24px}
      .receipt{max-width:800px;margin:0 auto;background:#fff;padding:28px;border-radius:8px;box-shadow:0 8px 30px rgba(2,6,23,0.08)}
      .heading{display:flex;justify-content:space-between;align-items:center}
      .title{font-size:20px;font-weight:600}
      .meta{color:#6b7280}
      table{width:100%;margin-top:18px;border-collapse:collapse}
      td,th{padding:10px;border-bottom:1px solid #eef2f7;text-align:left}
      .total{font-weight:700;font-size:1.05rem}
      .muted{color:#6b7280;font-size:0.95rem}
      .actions{margin-top:18px}
      .btn{display:inline-block;padding:8px 12px;border-radius:6px;background:#4f46e5;color:#fff;text-decoration:none}
      @media print{ .actions{display:none} body{background:#fff} .receipt{box-shadow:none} }
    </style>
  </head>
  <body>
    <div class="receipt">
      <div class="heading">
        <div>
          <div class="title">CodePod — Payment Receipt</div>
          <div class="meta">Order: <strong>${escapeHtml(lookup)}</strong></div>
        </div>
        <div style="text-align:right">
          <div class="muted">${escapeHtml(created)}</div>
          <div style="margin-top:8px">Status: <strong>${escapeHtml(status)}</strong></div>
        </div>
      </div>

      <table>
        <tr><th>Item</th><th style="width:180px">Details</th></tr>
        <tr><td>Order ID</td><td>${escapeHtml(o.id || '')}</td></tr>
        <tr><td>Amount</td><td class="total">${escapeHtml(fmtAmount(amountPaise, currency))} ${escapeHtml(currency)}</td></tr>
        <tr><td>Payment ID</td><td>${escapeHtml(paymentId || '—')}</td></tr>
        <tr><td>Status</td><td>${escapeHtml(status)}</td></tr>
        <tr><td>Customer</td><td>${escapeHtml(customer.name || '')} ${customer.email ? ('• ' + escapeHtml(customer.email)) : ''} ${customer.phone ? ('• ' + escapeHtml(customer.phone)) : ''}</td></tr>
      </table>

      <div class="actions">
        <a class="btn" href="#" onclick="window.print();return false">Print / Save PDF</a>
        <a class="btn" href="/" style="background:#10b981;margin-left:8px">Back to store</a>
      </div>
    </div>
  </body>
</html>`;

    res.set('Content-Type', 'text/html');
    return res.send(html);
  } catch (e) {
    console.error('receipt render failed', e && e.stack ? e.stack : e && e.message);
    return res.status(500).send('internal');
  }
});

app.get('/orders', (req, res) => res.json(loadOrders()));

// Webhook receiver for Razorpay events. Verifies HMAC signature using WEBHOOK_SECRET
app.post('/api/checkout/webhook', (req, res) => {
  try {
    const sigHeader = req.headers['x-razorpay-signature'] || req.headers['x-razorpay-signature'.toLowerCase()];
    const secret = process.env.WEBHOOK_SECRET || '';
    const raw = req.rawBody || (req.body && JSON.stringify(req.body)) || '';

  // compute HMAC
  const h = crypto.createHmac('sha256', secret).update(raw).digest('hex');
  const ok = sigHeader && (h === sigHeader);

    // audit log (append raw payload + verification result)
    try {
  const entry = `${new Date().toISOString()} verified=${ok} sigHeader=${sigHeader || ''}\n${raw}\n\n`;
      fs.appendFileSync(WEBHOOK_AUDIT, entry);
    } catch (e) {
      console.warn('failed to write webhook audit', e && e.message);
    }

    if (!ok) {
      console.warn('webhook signature mismatch, computed:', h, 'header:', sigHeader);
      return res.status(400).json({ ok: false, error: 'invalid_signature' });
    }

    // parse payload and try to find matching local order
    let payload = null;
    try { payload = typeof req.body === 'object' ? req.body : JSON.parse(raw.toString()); } catch (e) { payload = req.body; }

    const orders = loadOrders();
    let matched = null;

    // helper: try common Razorpay webhook locations for link id
    const tryFindLinkId = (p) => {
      if (!p) return null;
      if (p.payload && p.payload.payment && p.payload.payment.entity && p.payload.payment.entity.link_id) return p.payload.payment.entity.link_id;
      if (p.payload && p.payload.payment && p.payload.payment.entity && p.payload.payment.entity.id) return p.payload.payment.entity.id;
      if (p.payload && p.payload.payment_link && p.payload.payment_link.entity && p.payload.payment_link.entity.id) return p.payload.payment_link.entity.id;
      if (p.entity && p.entity.id) return p.entity.id;
      return null;
    };

    const linkId = tryFindLinkId(payload) || (() => {
      // fallback: search raw text for a plink_ id
      try {
        const m = String(raw).match(/plink_[A-Za-z0-9_-]{8,}/);
        return m ? m[0] : null;
      } catch (e) { return null; }
    })();

    if (linkId) {
      matched = orders.find(o => o.razorpay_link_id === linkId || (o.razorpay_response && o.razorpay_response.id === linkId));
    }

    // Also try matching by reference_id if present
    if (!matched) {
      try {
        const ref = payload && payload.payload && ((payload.payload.payment && payload.payload.payment.entity && payload.payload.payment.entity.reference_id) || (payload.payload.payment_link && payload.payload.payment_link.entity && payload.payload.payment_link.entity.reference_id));
        if (ref) matched = orders.find(o => o.id === ref || (o.razorpay_response && o.razorpay_response.reference_id === ref));
      } catch (e) { }
    }

    // As a last resort, look for the reference_id anywhere in the raw body
    if (!matched) {
      try {
        const mref = String(raw).match(/local_\d{9,}/);
        if (mref) matched = orders.find(o => o.id === mref[0]);
      } catch (e) { }
    }

    if (matched) {
      // update status based on event type
    const ev = payload && (payload.event || payload.type || (payload.payload && payload.payload.event));
    const evLower = ev ? String(ev).toLowerCase() : '';
    if (evLower.indexOf('paid') !== -1 || evLower.indexOf('payment.captured') !== -1) matched.status = 'PAID';
    else if (evLower.indexOf('failed') !== -1 || evLower.indexOf('payment.failed') !== -1) matched.status = 'FAILED';
    else matched.status = matched.status || 'UPDATED';
      matched.lastWebhookAt = new Date().toISOString();
      saveOrders(orders);
      console.log('webhook matched order', matched.id, 'event=', ev);
    } else {
      console.log('webhook received but no matching order found');
    }

    return res.json({ ok: true, matched: !!matched });
  } catch (err) {
    console.error('webhook handler error', err && err.stack ? err.stack : err && err.message);
    return res.status(500).json({ ok: false, error: 'internal' });
  }
});

// ...debug endpoint removed; rely on real HMAC verification only

console.log('About to call app.listen...');
const server = app.listen(PORT, '0.0.0.0', () => {
  try {
    console.log('✅ App.listen callback fired, Express bound to port', PORT);
    console.log('process.pid=', process.pid);
    try { require('fs').writeFileSync(require('path').join(__dirname, 'server.pid'), String(process.pid)); } catch (e) { /* ignore */ }
    try { console.log('server.address() ->', server.address()); } catch (e) { console.log('server.address() not available', e && e.message); }
  } catch (e) {
    console.error('Error in listen callback', e && e.stack);
  }
});

module.exports = app;
