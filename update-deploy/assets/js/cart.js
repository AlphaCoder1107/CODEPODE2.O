// Minimal cart script for the static site.
// Stores cart in localStorage under key 'codepod_cart'
(function () {
  const CART_KEY = 'codepod_cart';
  const cartListEl = document.getElementById('cartList');
  const totalEl = document.getElementById('cartTotal');
  const proceedBtn = document.getElementById('proceedBtn');
  const isCartPage = Boolean(cartListEl && totalEl);
  const DEV_HOSTS = ['localhost','127.0.0.1'];
  const IS_LOCALHOST = DEV_HOSTS.includes(window.location.hostname);

  function loadCart() {
    try {
      const raw = localStorage.getItem(CART_KEY) || '{}';
      const parsed = JSON.parse(raw);
      return parsed.items || [];
    } catch (e) {
      return [];
    }
  }

  function saveCart(items) {
    localStorage.setItem(CART_KEY, JSON.stringify({ items }));
  }

  function render() {
    const items = loadCart();
    if (!items || items.length === 0) {
      if (isCartPage) {
        cartListEl.innerHTML = '<p>Your cart is empty.</p>';
        totalEl.textContent = '0.00';
        if (proceedBtn) proceedBtn.disabled = !IS_LOCALHOST;
        // Clear breakdown if present
        const breakdown = document.getElementById('cartBreakdown');
        if (breakdown) breakdown.innerHTML = '';
      }
      updateHeaderBadge(items);
      return;
    }
    if (proceedBtn) proceedBtn.disabled = false;
    if (isCartPage) cartListEl.innerHTML = '';
    let subtotal = 0;
    let breakdownRows = '';
    items.forEach((it, idx) => {
      const row = document.createElement('div');
      row.className = 'cart-item';
      const img = document.createElement('img');
  img.src = it.img || '/pi_2W/img1_codepod.jpg';
      const meta = document.createElement('div');
      meta.className = 'meta';
      meta.innerHTML = `<div><strong>${escapeHtml(it.title || 'Item')}</strong></div>`;
      // Quantity dropdown
      const qtyDiv = document.createElement('div');
      qtyDiv.innerHTML = 'Qty: ';
      const qtySelect = document.createElement('select');
      qtySelect.className = 'cart-qty-select';
      for (let q = 1; q <= 10; q++) {
        const opt = document.createElement('option');
        opt.value = q;
        opt.textContent = q;
        if (q == (it.qty || 1)) opt.selected = true;
        qtySelect.appendChild(opt);
      }
      qtySelect.addEventListener('change', function() {
        it.qty = Number(this.value);
        saveCart(items);
        render();
      });
      qtyDiv.appendChild(qtySelect);
      meta.appendChild(qtyDiv);
      // Price
      const priceDiv = document.createElement('div');
      priceDiv.textContent = `Price: ₹${(it.price||0).toFixed(2)}`;
      meta.appendChild(priceDiv);
      // Delete button
      const delBtn = document.createElement('button');
      delBtn.textContent = 'Delete';
      delBtn.className = 'btn secondary cart-del-btn';
      delBtn.style.marginTop = '8px';
      delBtn.addEventListener('click', function() {
        items.splice(idx, 1);
        saveCart(items);
        render();
      });
      meta.appendChild(delBtn);
      row.appendChild(img);
      row.appendChild(meta);
      if (isCartPage) cartListEl.appendChild(row);
      const itemTotal = (Number(it.price) || 0) * (Number(it.qty) || 1);
      subtotal += itemTotal;
      breakdownRows += `<tr><td>${escapeHtml(it.title)}</td><td>${it.qty}</td><td>₹${(it.price||0).toFixed(2)}</td><td>₹${itemTotal.toFixed(2)}</td></tr>`;
    });
    // Receipt-like breakdown
    let breakdownHtml = `<table class="cart-breakdown-table"><thead><tr><th>Item</th><th>Qty</th><th>Unit Price</th><th>Total</th></tr></thead><tbody>${breakdownRows}</tbody></table>`;
    // Add subtotal, tax, grand total rows
    let tax = Math.round(subtotal * 0.18 * 100) / 100; // 18% GST
    let grandTotal = subtotal + tax;
    breakdownHtml += `<div class="cart-breakdown-summary"><div>Subtotal: <span>₹${subtotal.toFixed(2)}</span></div><div>GST (18%): <span>₹${tax.toFixed(2)}</span></div><div class="cart-breakdown-grand">Grand Total: <span>₹${grandTotal.toFixed(2)}</span></div></div>`;
    if (isCartPage) {
      let breakdown = document.getElementById('cartBreakdown');
      if (!breakdown) {
        breakdown = document.createElement('div');
        breakdown.id = 'cartBreakdown';
        cartListEl.parentNode.appendChild(breakdown);
      }
      breakdown.innerHTML = breakdownHtml;
    }
    if (isCartPage) totalEl.textContent = grandTotal.toFixed(2);
    updateHeaderBadge(items);
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>\"]/g, function (c) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]; });
  }

  // wire customer form inputs
  const inputName = document.getElementById('codepod_name');
  const inputEmail = document.getElementById('codepod_email');
  const inputPhone = document.getElementById('codepod_phone');
  const phoneError = document.getElementById('phoneError');

  // populate saved customer if present
  try {
    const saved = JSON.parse(localStorage.getItem('codepod_customer')||'{}');
  if (saved.name && inputName) inputName.value = saved.name;
  if (saved.email && inputEmail) inputEmail.value = saved.email;
  if (saved.phone && inputPhone) inputPhone.value = saved.phone;
  } catch (e) {}

  function validatePhoneField(val) {
    const raw = (val || '').toString();
    if (!raw.trim()) return { ok: false, message: 'Phone is required' };
    // Prefer libphonenumber-js if present
    try {
      if (window.libphonenumber && window.libphonenumber.parsePhoneNumberFromString) {
        const p = window.libphonenumber.parsePhoneNumberFromString(raw, 'IN');
        if (!p || !p.isValid()) return { ok: false, message: 'Enter a valid India mobile number' };
          // Accept any number that libphonenumber considers valid for the IN region.
          // Use nationalNumber when available to store the 10-digit form.
          return { ok: true, normalized: p.nationalNumber || String(p.number).replace(/[^0-9]/g, '') };
      }
    } catch (e) {
      // fallback to regex
    }
    const normalized = raw.replace(/[^0-9]/g, '');
    const repeats = /(\d)\1{4,}/.test(normalized);
    const indiaWith91 = /^(?:91)?([6-9]\d{9})$/;
  if (repeats) return { ok: false, message: 'Please enter a valid mobile number' };
  const distinct = new Set(String(normalized)).size;
  if (distinct < 4) return { ok: false, message: 'Please enter a valid mobile number' };
    if (!indiaWith91.test(normalized)) return { ok: false, message: 'Enter a valid 10-digit India mobile number' };
    return { ok: true, normalized: normalized.match(indiaWith91)[1] };
  }

  if (inputPhone) {
    inputPhone.addEventListener('input', function () {
      const v = inputPhone.value;
      const r = validatePhoneField(v);
      if (!r.ok) {
        if (phoneError) { phoneError.style.display = 'block'; phoneError.textContent = r.message; }
      } else {
        if (phoneError) phoneError.style.display = 'none';
      }
    });
  }

  if (proceedBtn) proceedBtn.addEventListener('click', async function () {
    const items = loadCart();
    // use top-level IS_LOCALHOST flag
    if (!items || items.length === 0) {
      if (!IS_LOCALHOST) return; // in production, keep original behavior
      // in dev, allow a default test item amount so tester can exercise checkout
      console.warn('Cart empty — using a default dev test amount');
    }
  console.log('Proceed clicked', { itemsCount: (items && items.length) || 0, isLocalHost: IS_LOCALHOST });
    // show a small loading state on the button while network request is in-flight
    function setProceedLoading(loading) {
      if (!proceedBtn) return;
      if (loading) {
        try { proceedBtn.dataset._origText = proceedBtn.textContent; } catch (e) {}
        proceedBtn.classList.add('loading');
        proceedBtn.textContent = 'Processing…';
        proceedBtn.disabled = true;
      } else {
        proceedBtn.classList.remove('loading');
        try { proceedBtn.textContent = proceedBtn.dataset._origText || 'Proceed to Buy'; } catch (e) { proceedBtn.textContent = 'Proceed to Buy'; }
        try { delete proceedBtn.dataset._origText; } catch (e) {}
        proceedBtn.disabled = false;
      }
    }
    setProceedLoading(true);
  // Compute total in rupees
  let total = items.reduce((acc, it) => acc + (Number(it.price)||0) * (Number(it.qty)||1), 0);
  // If cart is empty and running locally, use a small default total for testing
  if ((!items || items.length === 0) && IS_LOCALHOST) total = 100; // ₹100 dev default

    // Read customer details from the form (guard missing fields)
    const customer = {
      name: (inputName && inputName.value ? inputName.value : '').trim(),
      email: (inputEmail && inputEmail.value ? inputEmail.value : '').trim(),
      phone: (inputPhone && inputPhone.value ? inputPhone.value : '').trim()
    };
    // Gmail validation
    const emailError = document.getElementById('emailError');
    const gmailRegex = /^[a-zA-Z0-9._%+-]+@gmail\.com$/;
    if (!customer.email || !gmailRegex.test(customer.email)) {
      if (emailError) {
        emailError.style.display = 'block';
        emailError.textContent = 'Please enter a valid Gmail address (e.g. yourname@gmail.com)';
      } else if (inputEmail) {
        // fallback: show alert if error div missing
        alert('Please enter a valid Gmail address (e.g. yourname@gmail.com)');
      }
      setProceedLoading(false);
      return;
    } else if (emailError) {
      emailError.style.display = 'none';
    }
    // client-side validation (in production, phone is required)
  const isLocal = IS_LOCALHOST;
    const phoneCheck = validatePhoneField(customer.phone);
    if (!phoneCheck.ok && !isLocal) {
      phoneError.style.display = 'block';
      phoneError.textContent = phoneCheck.message;
      setProceedLoading(false);
      return;
    }
    if (phoneCheck.ok) {
      customer.phone = phoneCheck.normalized;
    } else {
      // either blank or invalid but running locally — set skip_contact for dev
      if (isLocal) customer.skip_contact = true;
      else customer.phone = '';
    }

    try {
      // Prefer Orders+Checkout.js embedded flow: ask backend to create a Razorpay Order
  const explicitBase = window.CodePodApiBase;
  const API_BASE = explicitBase || 'https://codepode2o-production.up.railway.app';
      // The /api/create-order endpoint expects amount in paise
      const paise = Math.round(total * 100);
      const resp = await fetch(API_BASE + '/api/create-order', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount: paise, customer, description: 'CodePod order' })
      });
      if (!resp.ok) {
        // Do NOT fallback to payment links. Orders API must be used.
        const body = await resp.text().catch(() => '');
        let parsed = null;
        try { parsed = JSON.parse(body); } catch (e) { parsed = null; }
        const serverMsg = parsed && parsed.message ? parsed.message : (parsed && parsed.error ? parsed.error : null);
        const msg = serverMsg || (`status_${resp.status}`);
        const e = new Error(msg || 'create-order-failed');
        e.serverMessage = serverMsg;
        throw e;
      }
      const data = await resp.json();
      // Load Checkout.js then open popup using returned order
      let rzpKey = data && data.key ? data.key : (window.RAZORPAY_KEY_ID || '');
      // If key not available, fetch public config from server
      if (!rzpKey) {
        try {
          const cfgResp = await fetch(API_BASE + '/api/config');
          if (cfgResp && cfgResp.ok) {
            const cfg = await cfgResp.json().catch(() => null);
            if (cfg && cfg.key) {
              rzpKey = cfg.key;
              window.RAZORPAY_KEY_ID = rzpKey; // cache for subsequent calls
            }
          }
        } catch (e) { /* ignore config fetch errors */ }
      }
      const order = data && data.order;
      if (!order || !order.id) throw new Error('order_missing');
      // ensure checkout script is loaded
      if (typeof window.Razorpay === 'undefined') {
        await new Promise((resolve, reject) => {
          const s = document.createElement('script'); s.src = 'https://checkout.razorpay.com/v1/checkout.js'; s.onload = resolve; s.onerror = reject; document.head.appendChild(s);
        });
      }

      const options = {
        key: rzpKey,
        amount: order.amount,
        currency: order.currency,
        name: 'CodePod',
        description: 'CodePod order',
        order_id: order.id,
        handler: async function (respHandler) {
          // on success, verify signature with backend to finalize order
          try {
            const verify = await fetch(API_BASE + '/api/verify-payment', {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(respHandler)
            });
            const v = await verify.json().catch(() => null);
            if (verify.ok && v && v.ok) {
              // success — clear cart, let Razorpay close the popup and then redirect to success page (or show message)
              localStorage.removeItem('codepod_cart');
              window.location.href = '/receipt.html?order=' + encodeURIComponent(order.id);
              return;
            }
            alert('Payment verification failed. Please contact support.');
            setProceedLoading(false);
          } catch (e) {
            console.error('verify-payment failed', e);
            alert('Payment verification error');
            setProceedLoading(false);
          }
        },
        prefill: { name: customer.name || '', email: customer.email || '', contact: customer.phone || '' },
        theme: { color: '#667eea' }
      };

      const rzp1 = new Razorpay(options);
      rzp1.open();
      // don't unset loading here — popup is open; any handler will unset or redirect
      return;
    } catch (err) {
      console.error('create order/payment flow failed', err);
      const serverMsg = err && err.serverMessage ? err.serverMessage : (err && err.message ? err.message : 'Could not start checkout. Please try again later.');
      alert(serverMsg);
      setProceedLoading(false);
    }
  });


  // Always update cart badge on page load (for all pages)
  try {
    const items = loadCart();
    updateHeaderBadge(items);
  } catch (e) {}

  // initial render (for cart page)
  render();

  // Listen for cart changes in other tabs/pages and update badge
  window.addEventListener('storage', function(e) {
    if (e.key === 'codepod_cart') {
      try {
        const items = loadCart();
        updateHeaderBadge(items);
      } catch (e) {}
    }
  });

  // expose a small API for other pages to add items
  window.CodePodCart = {
    addItem(item) {
      const items = loadCart();
      // normalize incoming item
      const normalized = { id: item.id || '', title: item.title || 'Item', price: Number(item.price)||0, img: item.img||'', qty: Number(item.qty)||1 };
      if (normalized.id) {
        const existing = items.find(i => i.id === normalized.id);
        if (existing) {
          existing.qty = (Number(existing.qty)||1) + (Number(normalized.qty)||1);
        } else {
          items.push(normalized);
        }
      } else {
        // no id provided — append as-is
        items.push(normalized);
      }
      saveCart(items);
      render();
      // show mini drawer feedback
      try { showMiniDrawer(normalized); } catch (e) { /* ignore */ }
      return items;
    },
    clear() { saveCart([]); render(); }
  };

  // update header badge with total quantity
  function updateHeaderBadge(items) {
    try {
      const totalQty = (items || []).reduce((s, it) => s + (Number(it.qty)||0), 0);
      const badges = document.querySelectorAll('.cart-badge');
      badges.forEach(b => {
        b.textContent = String(totalQty);
        b.setAttribute('aria-label', totalQty + ' items in cart');
        b.classList.remove('updated');
        // trigger pulse
        void b.offsetWidth;
        b.classList.add('updated');
      });
    } catch (e) { /* ignore */ }
  }

  // show a transient mini drawer at bottom-right when item added
  function showMiniDrawer(item) {
    const id = 'mini-cart-drawer';
    let el = document.getElementById(id);
    if (el) { // refresh content and restart animation
      el.classList.remove('show');
      void el.offsetWidth; // force reflow
    } else {
      el = document.createElement('div');
      el.id = id;
      el.className = 'mini-cart-drawer';
      document.body.appendChild(el);
    }
  el.innerHTML = `<div class="mini-inner"><img src="${escapeHtml(item.img||'/pi_2W/img1_codepod.jpg')}" alt=""/><div class="mini-meta"><div class="mini-title">${escapeHtml(item.title||'Item')}</div><div class="mini-qty">Qty: ${escapeHtml(String(item.qty||1))}</div></div><div class="mini-actions"><a href="/cart.html" class="btn small primary">View cart</a></div></div>`;
    // show
    requestAnimationFrame(()=> el.classList.add('show'));
    // auto hide after 3s
    setTimeout(()=>{ if (el) el.classList.remove('show'); }, 3200);
  }

})();

