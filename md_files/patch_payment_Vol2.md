# NEXT\_STEPS — Verify webhook replay, fix ngrok, and confirm E2E webhook handling

**Goal:** re-run a *signed* webhook POST to your public ngrok URL, confirm the server appends the raw payload to `webhook_audit.log`, records the event id in `processed_webhooks.json`, and updates the matching order in `orders.json`. If replay fails, diagnose why (signature mismatch / unreachable / ngrok flakiness / server binding / firewall).

Save this as `NEXT_STEPS_WEBHOOK_TEST.md` in your repo or follow the steps below.

---

## Preconditions (things to confirm first)

1. Server is running and healthy on port `3001`. Confirm locally:

```powershell
# from server host
Invoke-RestMethod -Uri http://127.0.0.1:3001/api/health -UseBasicParsing
# expected: JSON with ok:true
```

2. ngrok tunnel is up and pointing to port 3001. Confirm the public URL you told Razorpay is live:

```
https://e3ef699ff7cb.ngrok-free.app
```

Test the webhook path quickly:

```bash
# from any machine (curl)
curl -v https://e3ef699ff7cb.ngrok-free.app/api/checkout/webhook
# or POST a small test (this will 400 because no signature): 
curl -v -X POST -H "Content-Type: application/json" -d '{}' https://e3ef699ff7cb.ngrok-free.app/api/checkout/webhook
```

3. Confirm `.env.local` on the server has `WEBHOOK_SECRET` set (used to compute/verify signatures).

4. Confirm `orders.json` contains an order with a `razorpay_order_id` or receipt that you can use for the replay mapping.

---

## Step A — Fix or re-create the ngrok tunnel if flaky

You mentioned `ERR_NGROK_108` (session limit). Do one of the following:

* Stop other ngrok processes (on the machine and from Dashboard). Then recreate tunnel:

```powershell
# kill other ngrok instances on Windows PowerShell (careful)
Get-Process -Name ngrok -ErrorAction SilentlyContinue | Stop-Process -Force

# start a fresh tunnel from server directory
ngrok http 3001
# copy the new HTTPS URL and update Razorpay webhook to https://<your-new-url>/api/checkout/webhook
```

* If you use ngrok frequently, log in and set your authtoken so session limits are less likely:

```bash
ngrok authtoken <your_token>
```

**Confirm**: after starting ngrok, the HTTP inspector at `http://127.0.0.1:4040` should show incoming requests; use that to observe replays.

---

## Step B — Create (or use) a signed webhook payload

You must compute HMAC-SHA256 over the raw JSON body using `WEBHOOK_SECRET` and send it as the header `X-Razorpay-Signature`. Below are two safe options: Node script (recommended) and PowerShell inline.

### Option 1 — Node script (recommended)

Create `scripts/replay_webhook.js` in your repo:

```js
// scripts/replay_webhook.js
// Usage: node replay_webhook.js <payloadJsonFile> <webhookUrl> <webhookSecret>
const fs = require('fs');
const crypto = require('crypto');
const https = require('https');
const http = require('http');
const url = require('url');

const [,, payloadFile, webhookUrl, webhookSecret] = process.argv;
if(!payloadFile || !webhookUrl || !webhookSecret){ 
  console.error('Usage: node replay_webhook.js payload.json https://.../api/checkout/webhook <WEBHOOK_SECRET>'); process.exit(1);
}

const raw = fs.readFileSync(payloadFile).toString();
const signature = crypto.createHmac('sha256', webhookSecret).update(raw).digest('hex');

const parsed = url.parse(webhookUrl);
const opts = {
  hostname: parsed.hostname,
  port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
  path: parsed.path,
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(raw),
    'X-Razorpay-Signature': signature
  }
};

const client = parsed.protocol === 'https:' ? https : http;
const req = client.request(opts, (res) => {
  console.log('Status:', res.statusCode);
  res.setEncoding('utf8');
  res.on('data', d => process.stdout.write(d));
});
req.on('error', (e) => console.error('Request error', e));
req.write(raw);
req.end();
```

Create a sample payload file `sample_webhook.json`. If you have a real webhook from Razorpay (payload you captured earlier) use that, otherwise prepare a minimal `payment.captured` shaped payload with realistic `payload.payment.entity` fields including `id`, `order_id`, and `notes.localOrderId` that matches a local order.

Example minimal `sample_webhook.json`:

```json
{
  "id": "evt_test_12345",
  "entity": "event",
  "account_id": "acc_test",
  "event": "payment.captured",
  "payload": {
    "payment": {
      "entity": {
        "id": "pay_test_123",
        "order_id": "order_test_abc",
        "amount": 129900,
        "notes": { "localOrderId": "PUT_YOUR_LOCAL_ORDER_ID_HERE" }
      }
    }
  }
}
```

Run the replay:

```bash
node scripts/replay_webhook.js sample_webhook.json https://e3ef699ff7cb.ngrok-free.app/api/checkout/webhook "YOUR_WEBHOOK_SECRET"
```

Watch the server console, `webhook_audit.log`, and `processed_webhooks.json`. Also inspect ngrok inspector at `http://127.0.0.1:4040` if running locally.

---

### Option 2 — PowerShell (compute signature and POST)

If you prefer PowerShell, compute HMAC and post:

```powershell
# variables
$payload = Get-Content -Raw -Path .\sample_webhook.json
$secret = 'YOUR_WEBHOOK_SECRET'
# compute hex hmac
$hmac = [System.BitConverter]::ToString((New-Object System.Security.Cryptography.HMACSHA256([System.Text.Encoding]::UTF8.GetBytes($secret))).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($payload))).Replace('-','').ToLower()

# POST with signature
$headers = @{ 'X-Razorpay-Signature' = $hmac; 'Content-Type' = 'application/json' }
Invoke-RestMethod -Uri 'https://e3ef699ff7cb.ngrok-free.app/api/checkout/webhook' -Method POST -Headers $headers -Body $payload
```

---

## Step C — What to check immediately after replay

1. **Server console logs** — should show webhook request and any debug messages (signature verified, order updated, etc).
2. **webhook\_audit.log** — new raw JSON payload appended with timestamp. Example:

```
2025-08-15T12:34:56.789Z {"id":"evt_test_12345", ... }
```

3. **processed\_webhooks.json** — the `event.id` should appear in the array (or fallback id used by your code).
4. **orders.json** — the matching local order (via `notes.localOrderId` or `razorpay_order_id`) should now have `status: "PAID"` and `razorpay_payment_id` set (if your sample contained `payment.entity.id`).
5. **ngrok inspector** — shows request and response, useful to inspect headers and raw body.
6. **Razorpay dashboard** — if you used actual Razorpay-generated test webhook (less likely for a manual replay), you can also check the Webhooks delivery logs.

If anything is missing:

* If `webhook_audit.log` is empty: the request never reached server. Check ngrok connectivity, firewall, or binding (server listening host). Re-run `curl` to the public URL to confirm it takes a connection.
* If `webhook_audit.log` has the raw payload but `processed_webhooks.json` did not update or order not updated: check signature mismatch or parsing error. Inspect server logs for `Invalid webhook signature` or exceptions. Compute the expected signature locally (see Node script) and compare to header sent.
* If `processed_webhooks.json` updated but `orders.json` not updated: the payload's `payment.entity.order_id` or `notes.localOrderId` didn't match any local order. Verify `localOrderId` value in payload.

---

## Step D — If replay fails: targeted debugging steps

1. **Verify signature calculation**

   * Compute the signature exactly with the same raw JSON bytes the server receives (no pretty-print changes, no extra CRLF). Use the Node script to compute signature on the same `sample_webhook.json` file you POST.
2. **Check server logs for `Invalid webhook signature`** — if present, signature wrong. Use the Node script to compute hex HMAC and compare.
3. **If request never arrives** — check:

   * ngrok dashboard for request attempts
   * firewall rules (Windows Defender) blocking inbound to node/port
   * server binding: ensure `server.address()` prints `0.0.0.0:3001` or `127.0.0.1:3001` and ngrok maps to the same
4. **If audit has entry but processing fails** — wrap webhook handler with try/catch and log full error stack; inspect JSON shape.
5. **If ngrok is flaky** — re-create a new tunnel and update the webhook URL in Razorpay to the new public URL.

---

## Step E — After a successful replay

1. Confirm `orders.json` shows the order transitioned to `PAID`.
2. Add a small test script to automate replays in future (I can generate that).
3. If you plan to run many tests, consider switching from file-based persistence to a simple SQLite local DB to avoid race conditions; I can provide migration steps.
4. Document the successful test in your roadmap / canvas doc and mark the webhook-test step completed.

---

## Quick checklist you can follow now

* [ ] Ensure server running and `/api/health` OK.
* [ ] Start/recreate ngrok and update Razorpay if needed.
* [ ] Prepare `sample_webhook.json` with `notes.localOrderId` equal to a real `orders.json` id (or use an existing payment payload).
* [ ] Run the Node replay:
  `node scripts/replay_webhook.js sample_webhook.json https://e3ef699ff7cb.ngrok-free.app/api/checkout/webhook "<WEBHOOK_SECRET>"`
* [ ] Inspect server console + `server/webhook_audit.log` + `server/processed_webhooks.json` + `server/orders.json`.
* [ ] If failed, follow the debugging steps above.

---

## Offer

I can run the signed replay **for you** from this environment only if you give me **the public ngrok URL** and **the webhook secret**. I will:

* compute the correct HMAC,
* POST `sample_webhook.json` to your ngrok webhook endpoint,
* then report whether `webhook_audit.log`, `processed_webhooks.json`, and `orders.json` changed.

**Security note:** sharing `WEBHOOK_SECRET` in chat is sensitive. If you prefer not to paste secrets here, run the Node script locally — it requires no external access. I’ll help you interpret the results.

---
