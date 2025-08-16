// Client-side include for shared footer
// Fetches /footer.html and injects its <footer> into #site-footer
// If footer.html contains <style> or <link rel="stylesheet"> tags, they are preserved only if not duplicate.

(function() {
    const FOOTER_URL = '/footer.html';
    const PLACEHOLDER_ID = 'site-footer';

    // DEV OVERRIDE: When testing locally but loading the site under the production hostname
    // (for example via hosts file mapping), force the payments API to point at the local
    // payments server so client calls reach your dev server instead of the remote host.
    // This is safe for development only and will not override an explicit `window.CodePodApiBase`.
    try {
        const devHosts = ['codepode.in', 'www.codepode.in', 'codepod.in', 'www.codepod.in'];
        if (!window.CodePodApiBase && devHosts.includes(window.location.hostname)) {
            window.CodePodApiBase = 'http://localhost:3001';
            console.info('Dev: CodePodApiBase set to', window.CodePodApiBase);
        }
    } catch (e) { /* ignore in restrictive environments */ }

    async function loadFooter() {
        try {
            const res = await fetch(FOOTER_URL, {cache: 'no-cache'});
            if (!res.ok) throw new Error('Failed to fetch footer: ' + res.status);
            const text = await res.text();

            // Create a temporary container to parse the fetched HTML
            const tmp = document.createElement('div');
            tmp.innerHTML = text;

            // Move any <style> or <link rel="stylesheet"> into the document head if not already present
            const head = document.head || document.getElementsByTagName('head')[0];

            // Ensure the shared footer stylesheet exists on the page (some pages don't include it)
            const footerCssHref = '/assets/css/footer.css';
            const hasFooterCss = Array.from(document.querySelectorAll('link[rel="stylesheet"]')).some(l => l.getAttribute('href') === footerCssHref);
            if (!hasFooterCss) {
                const footerLink = document.createElement('link');
                footerLink.rel = 'stylesheet';
                footerLink.href = footerCssHref;
                head.appendChild(footerLink);
            }

            // Handle link[rel=stylesheet] tags that might be present inside the fetched snippet
            tmp.querySelectorAll('link[rel="stylesheet"]').forEach(link => {
                const href = link.getAttribute('href');
                // Avoid adding duplicate stylesheet links
                const exists = Array.from(document.querySelectorAll('link[rel="stylesheet"]')).some(l => l.getAttribute('href') === href);
                if (!exists) head.appendChild(link);
            });

            // Move any <style> tags to head
            tmp.querySelectorAll('style').forEach(style => {
                head.appendChild(style);
            });

            // Extract the footer element
            const footerEl = tmp.querySelector('footer');
            const placeholder = document.getElementById(PLACEHOLDER_ID);
            if (!placeholder) {
                console.warn('Footer placeholder not found: #' + PLACEHOLDER_ID);
                return;
            }

            if (footerEl) {
                placeholder.replaceWith(footerEl);
            } else {
                // If there's no footer element, insert raw HTML
                placeholder.innerHTML = text;
            }
        } catch (err) {
            console.error('Error loading footer:', err);
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', loadFooter);
    } else {
        loadFooter();
    }
    // Attach global Buy Now handlers after DOM is ready.
    async function attachBuyNowHandlers() {
        // Ensure libphonenumber-js is available for client validation; load dynamically if missing
        if (!window.libphonenumber) {
            const s = document.createElement('script');
            s.src = 'https://cdn.jsdelivr.net/npm/libphonenumber-js@1.10.22/bundle/libphonenumber-js.min.js';
            s.async = true;
            document.head.appendChild(s);
            // allow a small delay for the script to parse
            await new Promise(r => setTimeout(r, 250));
        }
    const buttons = document.querySelectorAll('.btn-buy');
        if (!buttons || buttons.length === 0) return;
        buttons.forEach(btn => {
            if (btn.dataset.cpHandlerAttached) return;
            btn.dataset.cpHandlerAttached = '1';
            btn.addEventListener('click', async function onBuy(e) {
                try {
                    btn.disabled = true;
                    // Find nearest price element
                    const box = btn.closest('.buyer-buybox') || document;
                    const priceEl = box.querySelector('.buyer-price') || document.querySelector('.buyer-price');
                    const priceText = (priceEl && priceEl.textContent) ? priceEl.textContent : '₹0';
                    const rupees = Number(priceText.replace(/[^0-9.]/g, '')) || 0;
                    const qtyEl = box.querySelector('#qty');
                    const qty = Number(qtyEl ? qtyEl.value : 1) || 1;
                    const total = Math.round(rupees * qty);

                    // Ensure cart API is available (load it dynamically if missing)
                    await ensureCartApi();
                    window.CodePodCart.addItem({ id: box.getAttribute('data-id') || '', title: box.getAttribute('data-title') || '', price: rupees, img: box.getAttribute('data-img') || '', qty: qty });
                    window.location.href = '/cart.html';
                    return;
                    } catch (err) {
                    console.error('BuyNow handler error', err && err.message);
                    const serverMsg = err && err.serverMessage ? err.serverMessage : (err && err.message ? err.message : 'Unable to start payment. Please try again.');
                    alert(serverMsg);
                    btn.disabled = false;
                }
            });
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', attachBuyNowHandlers);
    } else {
        attachBuyNowHandlers();
    }

    // Attach Add-to-Cart handlers for buttons with [data-cart-add]
    async function attachAddToCartHandlers() {
        const buttons = document.querySelectorAll('[data-cart-add]');
        if (!buttons || buttons.length === 0) return;
        buttons.forEach(btn => {
            if (btn.dataset.cpCartAttached) return;
            btn.dataset.cpCartAttached = '1';
            btn.addEventListener('click', async function (e) {
                try {
                    btn.disabled = true;
                    // Read item data attributes
                    const id = btn.getAttribute('data-id') || btn.dataset.id || '';
                    const title = btn.getAttribute('data-title') || btn.dataset.title || 'Item';
                    const price = Number(btn.getAttribute('data-price') || btn.dataset.price || 0) || 0;
                    const img = btn.getAttribute('data-img') || btn.dataset.img || '';
                    const qty = Number(btn.getAttribute('data-qty') || btn.dataset.qty || 1) || 1;

                    // Ensure CodePodCart is present, load cart.js if missing
                    await ensureCartApi();
                    window.CodePodCart.addItem({ id, title, price, img, qty });
                    // brief feedback
                    const orig = btn.innerHTML;
                    btn.innerHTML = '<i class="fas fa-check"></i> Added';
                    setTimeout(()=> { try { btn.innerHTML = orig; btn.disabled = false; } catch(e){} }, 1200);
                } catch (err) {
                    console.error('Add to cart failed', err);
                    btn.disabled = false;
                    alert('Could not add to cart. Please try again.');
                }
            });
        });
    }

    // Ensure the cart client script is loaded and window.CodePodCart is available.
    // Returns a promise that resolves when CodePodCart exists or rejects after timeout.
    function ensureCartApi(timeoutMs = 5000) {
        return new Promise((resolve, reject) => {
            if (window.CodePodCart) return resolve();
            // If cart script already present on the page, wait for it to initialize
            const existing = Array.from(document.querySelectorAll('script')).some(s => (s.src || '').indexOf('/assets/js/cart.js') !== -1 || (s.src || '').indexOf('assets/js/cart.js') !== -1);
            let triedAppend = false;
            if (!existing) {
                triedAppend = true;
                console.info('ensureCartApi: appending /assets/js/cart.js');
                const s = document.createElement('script');
                s.src = '/assets/js/cart.js';
                s.async = true;
                s.onload = () => { /* continue to wait for initialization below */ };
                s.onerror = () => console.warn('ensureCartApi: failed to load cart.js');
                document.head.appendChild(s);
            }

            // Wait loop with retries until timeoutMs
            const start = Date.now();
            (function waitFor() {
                if (window.CodePodCart) return resolve();
                if (Date.now() - start > timeoutMs) {
                    const msg = triedAppend ? 'Cart loaded but API not present' : 'Cart API not available';
                    console.warn('ensureCartApi timeout:', msg, ' — injecting fallback shim');
                    // Fallback shim: minimal implementation of window.CodePodCart
                    try {
                        if (!window.CodePodCart) {
                            window.CodePodCart = {
                                addItem(item) {
                                    try {
                                        const CART_KEY = 'codepod_cart';
                                        const raw = localStorage.getItem(CART_KEY) || '{}';
                                        const parsed = JSON.parse(raw || '{}');
                                        const items = parsed.items || [];
                                        const normalized = { id: item.id||'', title: item.title||'Item', price: Number(item.price)||0, img: item.img||'', qty: Number(item.qty)||1 };
                                        if (normalized.id) {
                                            const existing = items.find(i=>i.id===normalized.id);
                                            if (existing) existing.qty = (Number(existing.qty)||1) + (Number(normalized.qty)||1);
                                            else items.push(normalized);
                                        } else items.push(normalized);
                                        localStorage.setItem(CART_KEY, JSON.stringify({ items }));
                                        try { if (typeof window.updateHeaderBadge === 'function') window.updateHeaderBadge(items); } catch(e){}
                                        return items;
                                    } catch (e) { console.warn('fallback addItem failed', e); return []; }
                                },
                                clear() { try { localStorage.removeItem('codepod_cart'); if (typeof window.render === 'function') window.render(); } catch(e){} }
                            };
                        }
                    } catch (e) { console.warn('failed to inject fallback cart shim', e); }
                    return resolve();
                }
                setTimeout(waitFor, 150);
            })();
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', attachAddToCartHandlers);
    } else {
        attachAddToCartHandlers();
    }
})();
