Here’s a proper `.md` guide you can include in your project for handling **Add to Cart + Cart Page rendering**.

---

````markdown
# Cart System Setup (CodePod Shop)

This guide explains how to implement the **Add to Cart** functionality and display it properly on `cart.html`.

---

## 1. Saving Items to Cart (Product Page)

On each product page, add the following JavaScript.  
It ensures products are stored in **localStorage** under the `cart` key.

```html
<script>
function addToCart(item) {
    // Load cart or start empty
    let cart = JSON.parse(localStorage.getItem("cart")) || [];

    // Check if item already exists
    let existing = cart.find(p => p.id === item.id);
    if (existing) {
        existing.qty += item.qty; // increase quantity
    } else {
        cart.push(item);
    }

    // Save cart back
    localStorage.setItem("cart", JSON.stringify(cart));
    alert("Item added to cart!");
}

// Example usage (button event)
document.getElementById("addToCartBtn").addEventListener("click", () => {
    addToCart({
        id: "pi2w-kit",
        title: "Raspberry Pi Zero 2 W DIY Kit",
        price: 2099,
        qty: 1,
        img: "./pi_2W/img1_codepod.jpg"
    });
});
</script>
````

---

## 2. Rendering Cart Items (cart.js)

Your `cart.js` should fetch the stored cart and display items in `cart.html`.

```js
function renderCart() {
    let cart = JSON.parse(localStorage.getItem("cart")) || [];
    let container = document.getElementById("cart-items");
    let totalElement = document.getElementById("cart-total");
    container.innerHTML = "";

    if (cart.length === 0) {
        container.innerHTML = "<p>Your cart is empty.</p>";
        totalElement.textContent = "₹0.00";
        return;
    }

    let total = 0;
    cart.forEach(item => {
        let row = document.createElement("div");
        row.className = "cart-row";
        row.innerHTML = `
            <img src="${item.img}" width="60" />
            <span>${item.title}</span>
            <span>₹${item.price} × ${item.qty}</span>
            <span>₹${item.price * item.qty}</span>
        `;
        container.appendChild(row);
        total += item.price * item.qty;
    });

    totalElement.textContent = "₹" + total.toFixed(2);
}

// Clear cart
function clearCart() {
    localStorage.removeItem("cart");
    renderCart();
}

// Run on load
document.addEventListener("DOMContentLoaded", renderCart);
```

---

## 3. Cart HTML Example (cart.html)

Update `cart.html` with IDs that `cart.js` needs.

```html
<div id="cart-items">(loading cart...)</div>

<div class="order-summary">
  <h3>Total: <span id="cart-total">₹0.00</span></h3>
  <button onclick="clearCart()">Clear Cart</button>
</div>
```

---

## 4. Debugging

* Open browser console and type:

  ```js
  localStorage.getItem("cart")
  ```

  → You should see a JSON string of your items.

* If it shows `null`, the product page didn’t save correctly.

* If items exist but don’t display, check `cart.js` render function.

---

✅ With this, your **Add to Cart** → **Cart Page** → **Checkout** flow will work using `localStorage`.

```

---

Do you want me to also add **Quantity Update (+/– buttons)** in the cart page so buyers can change amounts without going back to the product page?
```
