// Simple webhook replay tool
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const http = require('http');
const https = require('https');

require('dotenv').config({ path: path.join(__dirname, '.env') });
const ORDERS = path.join(__dirname, 'orders.json');
const WEBHOOK_URL = process.env.WEBHOOK_URL || 'http://localhost:3001/api/checkout/webhook';
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || process.env.WEBHOOK_SECRET_FALLBACK || '';

function usage() {
  console.log('Usage: node replay-webhook.js <localOrderId>');
  console.log('Example: node replay-webhook.js local_1755309608285');
}

async function main() {
  const id = process.argv[2];
  if (!id) return usage();
  if (!fs.existsSync(ORDERS)) return console.error('orders.json not found');
  const orders = JSON.parse(fs.readFileSync(ORDERS, 'utf8'));
  const ord = orders.find(o => o.id === id);
  if (!ord) return console.error('order not found:', id);
  if (!ord.razorpay_link_id && !(ord.razorpay_response && ord.razorpay_response.id)) return console.error('order has no razorpay link id:', id);

  const linkId = ord.razorpay_link_id || (ord.razorpay_response && ord.razorpay_response.id);

  // Build sample payload similar to Razorpay's payment_link.* events
  const payload = {
    entity: {},
    event: 'payment_link.paid',
    payload: {
      payment_link: {
        entity: ord.razorpay_response || { id: linkId, reference_id: ord.id, short_url: ord.razorpay_short_url }
      }
    }
  };

  const body = JSON.stringify(payload);
  const sig = crypto.createHmac('sha256', WEBHOOK_SECRET).update(body).digest('hex');

  const url = new URL(WEBHOOK_URL);
  const opts = {
    hostname: url.hostname,
    port: url.port || (url.protocol === 'https:' ? 443 : 80),
    path: url.pathname + (url.search || ''),
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
      'x-razorpay-signature': sig
    }
  };

  const lib = url.protocol === 'https:' ? https : http;
  const req = lib.request(opts, (res) => {
    let d = '';
    res.on('data', c => d += c);
    res.on('end', () => {
      console.log('Status:', res.statusCode);
      console.log('Response:', d);
    });
  });
  req.on('error', (e) => console.error('request error', e));
  req.write(body);
  req.end();
}

main();
