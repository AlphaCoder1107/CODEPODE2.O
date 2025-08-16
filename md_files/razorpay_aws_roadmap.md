# CodePode Payment Integration — Roadmap & Current Status

**Source:** This document is a merged roadmap and current-status report, rewritten from the project's existing status doc (`PAYMENT_INTEGRATION_STATUS.md`) and expanded into an action-oriented roadmap for going from local dev → production on AWS.

**Date:** 2025-08-15

---

## 1. One-line summary

The Razorpay checkout flow is integrated end-to-end in dev: client cart, `cart.html`, and a minimal Express backend (`server/`) provide create-order, verify, and webhook endpoints. Local testing uses ngrok. Remaining work: persist orders, harden webhook processing, complete production deployment on AWS (S3 + CloudFront frontend, Beanstalk/ECS/Lambda backend), and add CI/CD + monitoring.

*(This file consolidates what exists in **`PAYMENT_INTEGRATION_STATUS.md`** and turns it into a prioritized roadmap.)*

---

## 2. What is implemented (current state)

- **Client**

  - `assets/js/cart.js` — localStorage-backed cart API with optional sync (`window.CART_SYNC`) and UI eventing.
  - `cart.html` — cart UI with quantity controls, summary and **Proceed-to-Buy** wired to the checkout flow.
  - Product pages updated to include `data-cart-add` buttons.

- **Server (Express)**

  - `server/index.js` — endpoints:
    - `POST /api/checkout/create-order` — creates a Razorpay order when `RAZORPAY_KEY_*` exist; otherwise returns a mock order for dev.
    - `POST /api/checkout/verify` — verifies Razorpay signature (HMAC) from Checkout handler.
    - `POST /api/checkout/webhook` — webhook receiver; verifies webhook signature via `WEBHOOK_SECRET`.
  - `server/package.json`, `server/.env.example`, `server/.env.local` (local only), and `server/carts.json` (dev persistence).

- **Local dev tooling**

  - `dotenv` support.
  - ngrok used to expose local server for webhook testing.

- **Documentation**

  - `PAYMENT_INTEGRATION_STATUS.md` describes the current implementation and local test steps.

---

## 3. File map (quick reference)

- Front-end: `assets/js/cart.js`, `cart.html`, modified product pages.
- Server: `server/index.js`, `server/package.json`, `server/carts.json`, `.env.example`.
- Docs: `PAYMENT_INTEGRATION_STATUS.md` (source for this rewrite).

---

## 4. How to run locally (condensed)

1. `cd server && npm install && npm start` — starts Express on port 3001 (default).
2. Enable client sync:
   ```html
   <script>window.CART_SYNC=true; window.CART_API='http://localhost:3001/api/cart';</script>
   <script src="/assets/js/cart.js"></script>
   ```
3. Start ngrok for webhooks: `ngrok http 3001` and use the generated `https://...` URL in Razorpay Dashboard → Webhooks.
4. Set env vars locally: `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `WEBHOOK_SECRET` (or use `.env.local`).

---

## 5. Known issues & limitations (observed)

1. **Orders are not persisted** in a dedicated `orders.json` or DB — webhook events are only logged. This prevents reliable post-payment order handling and reconciliation.
2. **Webhook idempotency & retries** need hardening (currently logs only). Without idempotency, duplicate events can create inconsistent state.
3. **UX polishing missing**: receipt page, error handling, and protection against double-clicks on Proceed-to-Buy.
4. **Local dev convenience fragility**: ngrok agent version and port conflicts were encountered during setup and needed manual fixes.
5. **Secrets handling**: `.env.local` exists but secrets are not yet migrated to a secrets manager for production.

---

## 6. Prioritized roadmap (tasks, ordered)

### Phase A — Stabilize dev & implement persistence (Immediate)

- **A1 — Persist orders**
  - Create `server/orders.json` (dev) or add DB table `orders` with the schema in Section 7.
  - On `POST /api/checkout/create-order` save a local order record with status `CREATED` and `receipt: cp_<localOrderId>`.
- **A2 — Fill webhook processing**
  - On `payment.captured` find local order by `razorpay_order_id` or receipt and mark `PAID` (idempotent).
  - On `payment.failed` mark `FAILED`, and record payloads to `payment_audit`.
- **A3 — Immediate verification**
  - Keep `POST /api/checkout/verify` that verifies `razorpay_signature` and responds to the client; but treat webhook as source-of-truth for final transitions.

### Phase B — Testing, QA, and hardening (short-term)

- **B1 — Add automated integration tests** (mock Razorpay) for create/verify/webhook.
- **B2 — Idempotency & retries**: ensure webhook handler checks order status before updating and stores processed event IDs.
- **B3 — UX**: Add `/receipt` page and redirect flow after successful verify/webhook.
- **B4 — Logging & audit**: store raw webhook payloads and verification results for troubleshooting.

### Phase C — Production deploy on AWS (mid-term)

- **C1 — Frontend**: Build and host static site on **S3 + CloudFront** with ACM TLS cert and custom domain.
- **C2 — Backend**: Deploy Node backend to **Elastic Beanstalk** (simple) or **ECS Fargate** (container) or **Lambda + API Gateway** (serverless). Ensure public HTTPS endpoint for webhooks.
- **C3 — Database**: Provision **RDS Postgres** or use **DynamoDB** for serverless storage.
- **C4 — Secrets**: Move `RAZORPAY_KEY_*` and `WEBHOOK_SECRET` into **AWS Secrets Manager** or Parameter Store; remove `.env.local` from prod.

### Phase D — CI/CD, monitoring, reconciliation (longer-term)

- **D1 — CI**: GitHub Actions to build + `aws s3 sync` frontend and deploy backend (EB/ECS). Use secrets in GitHub for AWS creds.
- **D2 — Monitoring**: CloudWatch / ELK for logs; alert on webhook failures or signature mismatches.
- **D3 — Reconciliation job**: nightly job comparing local `PAID` orders vs Razorpay payouts/settlements and raising exceptions.

---

## 7. Suggested order schema (for persistence)

```json
{
  "id": "uuid",
  "razorpay_order_id": "rzp_order_...",
  "razorpay_payment_id": "rzp_pay_...",
  "customer": {"name":"","email":"","phone":""},
  "items": [],
  "amount_paise": 129900,
  "currency": "INR",
  "status": "CREATED|PAYMENT_PENDING|PAID|FAILED|REFUNDED",
  "receipt": "cp_<localId>",
  "created_at": "...",
  "updated_at": "..."
}
```

---

## 8. Quick implementation checklists

**Before you push to production:**

-

**Testing checklist:**

-

---

## 9. Immediate recommended next tasks (pick one to start now)

1. Implement `orders.json` + update `create-order` and webhook to persist and transition orders (fast, low friction).
2. Implement idempotent webhook processing and store raw webhook payloads in `server/webhook_audit.log` or DB.
3. Add a simple `/receipt` page and wire client flow to redirect to it after verification; show `PAID`/`PENDING` based on server status.
4. Prepare GitHub Actions workflow to push static site to S3 and a basic deploy for backend to Elastic Beanstalk.

Tell me which item (1–4) you want implemented now and I will update the repository files and the canvas document immediately.

---

*This rewrite was produced from the project's **`PAYMENT_INTEGRATION_STATUS.md`** and reorganized into a pragmatic roadmap that maps implemented items to immediate and production-level work.*

