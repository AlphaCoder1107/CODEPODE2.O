// Simple regression test for webhook replay
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const ORDERS = path.join(__dirname, 'orders.json');
const AUDIT = path.join(__dirname, 'webhook_audit.log');
const REPLAY = path.join(__dirname, 'replay-webhook.js');

const TEST_ORDER_ID = process.env.TEST_ORDER_ID || 'local_1755309608285';

function die(msg) { console.error('FAIL:', msg); process.exit(2); }
function ok(msg) { console.log('OK:', msg); }

if (!fs.existsSync(ORDERS)) die('orders.json not found');
if (!fs.existsSync(REPLAY)) die('replay-webhook.js not found');

// snapshot audit size and order status
const beforeAudit = fs.existsSync(AUDIT) ? fs.statSync(AUDIT).size : 0;
let orders = JSON.parse(fs.readFileSync(ORDERS, 'utf8'));
const ord = orders.find(o => o.id === TEST_ORDER_ID);
if (!ord) die('test order id not found: ' + TEST_ORDER_ID);
const beforeStatus = ord.status || '';

// run replay (signed using .env WEBHOOK_SECRET)
console.log('Running replay for', TEST_ORDER_ID);
const r = spawnSync(process.execPath, [REPLAY, TEST_ORDER_ID], { cwd: __dirname, stdio: 'inherit', env: process.env });
if (r.error) die('failed to run replay: ' + r.error.message);
if (r.status !== 0) die('replay script failed with code ' + r.status);

// wait briefly for server to process and write files
const WAIT_MS = 400;
Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, WAIT_MS);

// re-read audit and orders
const afterAudit = fs.existsSync(AUDIT) ? fs.statSync(AUDIT).size : 0;
orders = JSON.parse(fs.readFileSync(ORDERS, 'utf8'));
const ordAfter = orders.find(o => o.id === TEST_ORDER_ID);
if (!ordAfter) die('order disappeared after replay');

if (afterAudit <= beforeAudit) die('webhook_audit.log not appended');
ok('webhook_audit.log appended (' + beforeAudit + ' -> ' + afterAudit + ')');

if (ordAfter.status === beforeStatus) die('order status did not change (before=' + beforeStatus + ', after=' + ordAfter.status + ')');
ok('order status changed: ' + beforeStatus + ' -> ' + ordAfter.status);

console.log('Regression test passed');
process.exit(0);
