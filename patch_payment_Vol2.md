# Deprecation Plan for `/api/create-payment-link`

## Context

- The CodePod payments server previously supported both **Payment Links** and **Orders API**.
- As of **August 2025**, the client and regression harness have fully migrated to the **Orders API + Checkout.js**.
- To prevent accidental fallback and make migration clear, `/api/create-payment-link` has been **deprecated**.

---

## Current Behavior

- The route still exists in `index.js`, but:
  - It logs a warning:
    ```
    ⚠️ /api/create-payment-link is deprecated; use /api/create-order instead
    ```
  - It returns HTTP **410 Gone** with JSON:
    ```json
    { "error": "Deprecated endpoint" }
    ```
- Explicit listen diagnostics confirm the server is binding properly.

---

## Code Comment

In `index.js`, the handler is wrapped with a TODO:

```js
// TODO: Remove this endpoint after v1.1 release (deprecated in Aug 2025)
app.post("/api/create-payment-link", (req, res) => {
  console.warn("⚠️ /api/create-payment-link is deprecated; use /api/create-order instead");
  return res.status(410).json({ error: "Deprecated endpoint" });
});
