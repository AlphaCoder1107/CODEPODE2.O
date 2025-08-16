#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');
const http = require('http');
const fs = require('fs');
const crypto = require('crypto');
// load server/.env so runner uses the same WEBHOOK_SECRET as the child
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const SERVER_DIR = path.join(__dirname, '..');
const SERVER_INDEX = path.join(SERVER_DIR, 'index.js');
const ORDERS_FILE = path.join(SERVER_DIR, 'orders.json');
const DEFAULT_PORT = process.env.PORT || 3001;
const HOST = 'localhost';
let chosenPort = Number(DEFAULT_PORT);
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || '';

function getUrlsForPort(p) {
  return {
    HEALTH_URL: `http://${HOST}:${p}/api/health`,
    CREATE_URL: `http://${HOST}:${p}/api/create-order`,
    WEBHOOK_URL: `http://${HOST}:${p}/api/checkout/webhook`
  };
}

function wait(ms) { return new Promise(r => setTimeout(r, ms)); }

function httpPostJson(url, obj) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(obj);
    const u = new URL(url);
    const opts = { method: 'POST', hostname: u.hostname, port: u.port, path: u.pathname + (u.search || ''), headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } };
    const req = http.request(opts, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { const parsed = JSON.parse(d); resolve({ status: res.statusCode, body: parsed }); } catch (e) { resolve({ status: res.statusCode, body: d }); }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function waitForHealth(url, timeout = 20000) {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    try {
      const res = await new Promise((resolve, reject) => {
        http.get(url, (r) => {
          let d = '';
          r.on('data', c => d += c);
          r.on('end', () => resolve({ status: r.statusCode, body: d }));
        }).on('error', reject);
      });
      if (res && res.status === 200) return true;
    } catch (e) { /* ignore */ }
    await wait(200);
  }
  return false;
}

async function run() {
  console.log('Selecting port for child server...');
  // If default port is available (no healthy server), use it. Otherwise pick an ephemeral free port
  const { HEALTH_URL: probeHealth } = getUrlsForPort(DEFAULT_PORT);
  let probeOk = false;
  try {
    // quick probe
    await new Promise((resolve, reject) => {
      const req = http.get(probeHealth, (res) => { res.resume(); resolve(); });
      req.on('error', reject);
      req.setTimeout(800, () => { req.abort(); resolve(); });
    });
    probeOk = true;
  } catch (e) { probeOk = false; }

  let child = null;
  if (probeOk) {
    // default port is occupied; choose ephemeral port
    const net = require('net');
    const s = net.createServer();
    await new Promise((resolve, reject) => s.listen(0, resolve));
    const freePort = s.address().port;
    s.close();
    chosenPort = freePort;
    console.log('Default port occupied; will start child on free port', chosenPort);
  } else {
    chosenPort = Number(DEFAULT_PORT);
    console.log('Default port free; will start child on', chosenPort);
  }

  // Start child server with controlled PORT and env (ensure WEBHOOK_SECRET is passed)
  const childEnv = Object.assign({}, process.env, { PORT: String(chosenPort), WEBHOOK_SECRET: WEBHOOK_SECRET });
  child = spawn(process.execPath, [SERVER_INDEX], { cwd: SERVER_DIR, stdio: ['ignore', 'inherit', 'inherit'], env: childEnv });
  child.on('error', (e) => console.warn('child process error', e && e.message));

  const { HEALTH_URL, CREATE_URL, WEBHOOK_URL } = getUrlsForPort(chosenPort);
  const healthy = await waitForHealth(HEALTH_URL, 20000);
  if (!healthy) {
    try { if (child) child.kill(); } catch (e) {}
    throw new Error('server did not become healthy in time on port ' + chosenPort);
  }
  console.log('Server started on port', chosenPort, 'and healthy');

  try {
  console.log('Server healthy, creating an order via Orders API...');

  // create an order; amount is in paise. Use a small test amount and skip contact info.
  const createResp = await httpPostJson(CREATE_URL, { amount: 100, customer: { name: 'RegressionTest', email: 'reg@test', skip_contact: true }, description: 'Regression test order' });
  if (createResp.status >= 400) throw new Error('create-order failed: ' + JSON.stringify(createResp.body));
  const orderObj = createResp.body && createResp.body.order;
  const localOrderId = createResp.body && createResp.body.localOrderId;
  if (!orderObj || !orderObj.id) throw new Error('create-order did not return a razorpay order id');

  // build a sample payload simulating payment captured for the order id
  const payload = { event: 'payment.captured', payload: { payment: { entity: { id: 'pay_' + Date.now(), order_id: orderObj.id, amount: orderObj.amount, currency: orderObj.currency, reference_id: localOrderId } } } };
  const body = JSON.stringify(payload);
  const sig = crypto.createHmac('sha256', WEBHOOK_SECRET).update(body).digest('hex');

  // send webhook
  console.log('Posting signed webhook for', localOrderId, 'razorpay_order_id=', orderObj.id);
    const u = new URL(WEBHOOK_URL);
  const opts = { method: 'POST', hostname: u.hostname, port: u.port, path: u.pathname + (u.search || ''), headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body), 'x-razorpay-signature': sig } };
    const postResult = await new Promise((resolve, reject) => {
      const req = http.request(opts, (res) => {
        let d = '';
        res.on('data', c => d += c);
        res.on('end', () => resolve({ status: res.statusCode, body: d }));
      });
      req.on('error', reject);
      req.write(body);
      req.end();
    });

  // no retry: expect server to validate real HMAC signature only

    // wait briefly and verify orders.json updated to PAID
    await wait(500);
    orders = JSON.parse(fs.readFileSync(ORDERS_FILE, 'utf8'));
    const ordAfter = orders.find(o => o.id === localOrderId);
    if (!ordAfter) throw new Error('order disappeared after webhook');
    if (ordAfter.status !== 'PAID') throw new Error('order status not PAID after webhook (status=' + ordAfter.status + ')');

    console.log('Test succeeded: order', localOrderId, '-> PAID');
    // kill server if we started it
    try { if (child) child.kill(); } catch (e) { }
    process.exit(0);
  } catch (err) {
    console.error('Regression run failed:', err && err.message || err);
    try { if (child) child.kill(); } catch (e) { }
    process.exit(1);
  }
}

run();
