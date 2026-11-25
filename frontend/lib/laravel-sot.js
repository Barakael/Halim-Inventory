/**
 * Laravel MySQL single-source-of-truth bridge.
 * Express keeps cookie sessions; core inventory/sales go to Laravel Sanctum API.
 */
const multer = require('multer');

const LARAVEL_URL = (process.env.LARAVEL_URL || 'http://127.0.0.1:8000').replace(/\/$/, '');
const uploadPurchaseReceipt = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 10 * 1024 * 1024 },
});

function enabled() {
    return process.env.LARAVEL_SOT !== '0' && Boolean(LARAVEL_URL);
}

/** Attach receipt_base64 from multer memory file (avoids broken Node FormData→PHP). */
function withReceiptBase64(body, file) {
    const out = { ...body };
    if (file && file.buffer && file.buffer.length) {
        out.receipt_base64 = file.buffer.toString('base64');
        out.receipt_filename = file.originalname || 'receipt.bin';
    }
    return out;
}

async function laravelFetch(path, { method = 'GET', token, body, headers = {}, formData } = {}) {
    const url = `${LARAVEL_URL}/api${path.startsWith('/') ? path : `/${path}`}`;
    const opts = {
        method,
        headers: {
            Accept: 'application/json',
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
            ...headers,
        },
    };
    if (formData) {
        opts.body = formData;
        // Let fetch set multipart boundary — do not set Content-Type
    } else if (body !== undefined) {
        opts.headers['Content-Type'] = 'application/json';
        opts.body = typeof body === 'string' ? body : JSON.stringify(body);
    }
    const res = await fetch(url, opts);
    const text = await res.text();
    let json = null;
    try {
        json = text ? JSON.parse(text) : null;
    } catch {
        json = { message: text || res.statusText };
    }
    return { status: res.status, json, ok: res.ok };
}

function unwrapData(json) {
    if (json == null) return null;
    if (Array.isArray(json)) return json;
    if (json.data !== undefined) return json.data;
    return json;
}

function mapLaravelUserToSession(user) {
    const role = user.role === 'owner' ? 'admin' : (user.role || 'cashier');
    return {
        id: String(user.id),
        username: user.username || user.email || String(user.id),
        fullName: user.name || user.username || 'User',
        role,
        branchId: user.branch_id != null ? String(user.branch_id) : 'main',
        email: user.email || null,
        laravelId: user.id,
        shopId: user.shop_id,
    };
}

function adaptProduct(p) {
    if (!p || typeof p !== 'object') return p;
    return {
        // String ids match web POS onclick handlers (addToCart('1') vs numeric 1)
        id: p.id != null ? String(p.id) : p.id,
        name: p.name,
        description: p.description || '',
        categoryId: p.category_id != null ? String(p.category_id) : p.category_id,
        categoryName: p.category || null,
        sku: p.sku || '',
        barcode: p.barcode || '',
        wholesalePrice: p.cost_price ?? 0,
        retailPrice: p.price ?? 0,
        price: p.price ?? 0,
        costPrice: p.cost_price ?? 0,
        unit: p.unit || 'pcs',
        minStock: p.low_stock_threshold ?? 10,
        currentStock: p.stock ?? 0,
        stock: p.stock ?? 0,
        status: p.status || 'active',
        image: p.image_url || p.image || null,
        shop_id: p.shop_id,
    };
}

function escapeReceiptHtml(text) {
    return String(text ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function formatReceiptDate(value) {
    const d = value ? new Date(value) : new Date();
    if (Number.isNaN(d.getTime())) return '—';
    const pad = (n) => String(n).padStart(2, '0');
    return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/**
 * Thermal receipt HTML — compact layout matching the mobile POS ticket
 * (ReceiptContent / ReceiptTicket), sized for short paper use.
 */
function renderSaleReceiptHtml(sale, settings = {}) {
    const paperMm = Number(settings.receiptPaperMm) === 80 ? 80 : 58;
    const autoPrint = !!settings.autoPrint;
    const printJobId = settings.printJobId != null ? String(settings.printJobId) : '';
    const saleIdAttr = sale.id != null ? String(sale.id) : '';
    const fmt = (n) => Number(n || 0).toLocaleString('en-US', {
        minimumFractionDigits: 0,
        maximumFractionDigits: 2,
    });
    const when = sale.createdAt || sale.completedAt || new Date();
    const whenDate = when instanceof Date ? when : new Date(when);
    const dateStr = Number.isNaN(whenDate.getTime())
        ? formatReceiptDate(when)
        : `${String(whenDate.getDate()).padStart(2, '0')}/${String(whenDate.getMonth() + 1).padStart(2, '0')}/${whenDate.getFullYear()}  ${String(whenDate.getHours()).padStart(2, '0')}:${String(whenDate.getMinutes()).padStart(2, '0')}:${String(whenDate.getSeconds()).padStart(2, '0')}`;

    const method = String(sale.paymentMethod || '').toLowerCase().trim();
    const isCredit = !!sale.isCredit || method === 'credit' || method.includes('deni');
    const payLabel = ({
        cash: 'Cash tendered',
        card: 'Card payment',
        mobile: 'Mobile payment',
        mobile_money: 'Mobile payment',
        mpesa: 'Mobile payment',
        credit: 'Credit / debt',
    })[method] || (method ? method : 'Amount paid');

    const shopTel = String(settings.mobile || settings.phone || settings.companyPhone || '').trim()
        || '+255717580918';
    const shopAddress = settings.address || settings.companyAddress || '';
    const shopLocation = settings.location || '';
    const receiptNo = sale.receiptNumber || sale.serial_number || sale.id;
    const customerName = sale.customerName && sale.customerName !== 'Walk-in Customer'
        ? sale.customerName
        : null;
    const customerPhone = sale.customerPhone && String(sale.customerPhone).trim()
        ? sale.customerPhone
        : null;

    const items = Array.isArray(sale.items) ? sale.items : [];
    const itemsHtml = items.length
        ? items.map((item) => {
            const qty = item.quantity || 0;
            const unit = item.price ?? item.unit_price ?? 0;
            const line = item.total ?? item.line_total ?? (Number(qty) * Number(unit));
            return `
  <div class="item">
    <div class="item-row">
      <span class="qty">${escapeReceiptHtml(String(qty))}x</span>
      <span class="name">${escapeReceiptHtml(item.productName || item.product_name || 'Item')}</span>
      <span class="amt">${fmt(line)}</span>
    </div>
    <div class="unit">@ ${fmt(unit)}</div>
  </div>`;
        }).join('')
        : '<div class="center muted">(No line items)</div>';

    const discountHtml = Number(sale.discount) > 0
        ? `<div class="kv"><span class="lbl">Discount</span><span class="val">-${fmt(sale.discount)}</span></div>`
        : '';
    const received = isCredit ? 0 : Number(sale.amountTendered ?? sale.amount_tendered ?? sale.totalAmount ?? 0);
    const change = Number(sale.change ?? sale.change_amount ?? 0);
    const creditRemainder = isCredit
        ? Number(sale.totalAmount || 0)
        : Math.max(0, Number(sale.totalAmount || 0) - received);

    let paymentHtml = '';
    if (isCredit) {
        paymentHtml = `<div class="kv"><span class="lbl">Credit / debt</span><span class="val">${fmt(sale.totalAmount)}</span></div>`;
    } else {
        paymentHtml = `<div class="kv"><span class="lbl">${escapeReceiptHtml(payLabel)}</span><span class="val">${fmt(received)}</span></div>`;
        if (creditRemainder > 0.009) {
            paymentHtml += `<div class="kv"><span class="lbl">Credit on account</span><span class="val">${fmt(creditRemainder)}</span></div>`;
        }
        if (change > 0.009) {
            paymentHtml += `<div class="kv"><span class="lbl">Change</span><span class="val">${fmt(change)}</span></div>`;
        }
    }

    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Receipt ${escapeReceiptHtml(receiptNo)}</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: Arial, Helvetica, sans-serif;
    font-size: 10px; font-weight: 400; color: #000; background: #fff;
    width: ${paperMm}mm; margin: 0 auto; padding: 2mm 2mm 4mm;
    line-height: 1.2;
  }
  .center { text-align: center; }
  .title { font-size: 9px; font-weight: 700; letter-spacing: 0.5px; }
  .shop { font-size: 13px; font-weight: 700; text-transform: uppercase; margin-top: 1px; }
  .sub { font-size: 9px; color: #222; margin-top: 1px; }
  .muted { color: #444; }
  .rule { border: none; border-top: 0.5px solid #000; margin: 3px 0; }
  .rule-heavy { border: none; border-top: 1.4px solid #000; margin: 3px 0; }
  .kv { display: flex; justify-content: space-between; gap: 4px; padding: 0.5px 0; font-size: 9.5px; }
  .kv .lbl { color: #333; }
  .kv .val { font-weight: 600; text-align: right; word-break: break-word; }
  .kv.strong .lbl, .kv.strong .val { font-weight: 700; font-size: 10.5px; }
  .cols { display: flex; font-size: 8.5px; font-weight: 700; gap: 2px; }
  .cols .q { width: 22px; }
  .cols .d { flex: 1; }
  .cols .a { text-align: right; }
  .item { margin: 2px 0 3px; }
  .item-row { display: flex; gap: 2px; align-items: flex-start; font-size: 9.5px; }
  .item-row .qty { width: 22px; }
  .item-row .name { flex: 1; word-break: break-word; }
  .item-row .amt { font-weight: 700; text-align: right; white-space: nowrap; }
  .unit { padding-left: 22px; font-size: 8px; color: #444; }
  .thanks { font-size: 9px; font-weight: 700; margin-top: 2px; }
  .welcome { font-size: 8.5px; color: #333; }
  @media print {
    body { width: ${paperMm}mm; margin: 0; padding: 1.5mm 2mm 3mm; }
    .no-print { display: none !important; }
    @page { size: ${paperMm}mm auto; margin: 0; }
  }
</style>
</head>
<body>
<div class="center title">RECEIPT</div>
<hr class="rule-heavy">
<div class="center shop">${escapeReceiptHtml(settings.companyName || 'HASLIM GROUP')}</div>
${shopAddress ? `<div class="center sub">${escapeReceiptHtml(shopAddress)}</div>` : ''}
${shopLocation ? `<div class="center sub">${escapeReceiptHtml(shopLocation)}</div>` : ''}
<div class="kv" style="margin-top:3px;"><span class="lbl">TEL</span><span class="val">${escapeReceiptHtml(shopTel)}</span></div>
<hr class="rule">
<div class="kv"><span class="lbl">RECEIPT</span><span class="val">${escapeReceiptHtml(receiptNo)}</span></div>
<div class="kv"><span class="lbl">DATE</span><span class="val">${escapeReceiptHtml(dateStr)}</span></div>
${customerName || customerPhone ? `
<hr class="rule">
<div class="center" style="font-size:9px;font-weight:700;">CUSTOMER</div>
${customerName ? `<div class="kv"><span class="lbl">Name</span><span class="val">${escapeReceiptHtml(customerName)}</span></div>` : ''}
${customerPhone ? `<div class="kv"><span class="lbl">Mobile</span><span class="val">${escapeReceiptHtml(customerPhone)}</span></div>` : ''}
` : ''}
<hr class="rule-heavy">
<div class="cols"><span class="q">QTY</span><span class="d">DESCRIPTION</span><span class="a">AMOUNT</span></div>
<hr class="rule">
${itemsHtml}
<hr class="rule">
<div class="kv"><span class="lbl">Subtotal</span><span class="val">${fmt(sale.subtotal ?? sale.totalAmount)}</span></div>
${discountHtml}
<hr class="rule-heavy">
<div class="kv strong"><span class="lbl">TOTAL</span><span class="val">${fmt(sale.totalAmount)}</span></div>
<hr class="rule">
${paymentHtml}
<hr class="rule">
<div class="center thanks">${escapeReceiptHtml(settings.receiptFooter || 'Thank you')}</div>
<div class="center welcome">Welcome again</div>
<div class="no-print" style="text-align:center;margin-top:10px;font-size:11px;color:#444;">
  Preview only. Office printing uses the Windows POS-80 printer.
</div>
<script>
(function () {
  var jobId = ${JSON.stringify(printJobId)};
  var saleId = ${JSON.stringify(saleIdAttr)};
  var shouldAutoPrint = ${autoPrint ? 'true' : 'false'};
  function notifyPrinted() {
    try {
      if (window.opener) {
        window.opener.postMessage({ type: 'haslim-receipt-printed', jobId: jobId, saleId: saleId }, window.location.origin);
      }
    } catch (e) {}
  }
  window.addEventListener('afterprint', function () {
    notifyPrinted();
    if (shouldAutoPrint) {
      setTimeout(function () { try { window.close(); } catch (e) {} }, 400);
    }
  });
  if (shouldAutoPrint) {
    window.addEventListener('load', function () {
      setTimeout(function () {
        try { window.focus(); window.print(); } catch (e) {}
        setTimeout(notifyPrinted, 2500);
      }, 400);
    });
  }
})();
</script>
</body>
</html>`;
}

function adaptSale(s) {
    if (!s || typeof s !== 'object') return s;
    return {
        id: s.id != null ? String(s.id) : s.id,
        receiptNumber: s.serial_number,
        serial_number: s.serial_number,
        paymentMethod: s.payment_method,
        payment_method: s.payment_method,
        isCredit: isCreditPaymentMethod(s.payment_method),
        subtotal: s.subtotal,
        tax: s.tax,
        discount: s.discount,
        totalAmount: s.total,
        total: s.total,
        amountTendered: s.amount_tendered,
        change: s.change,
        customerId: s.shop_customer_id,
        customerName: s.customer_name || 'Walk-in Customer',
        customerPhone: s.customer_phone,
        cashierId: s.cashier_id != null ? String(s.cashier_id) : null,
        cashierName: s.cashier_name || s.cashier?.name || 'Cashier',
        shop_id: s.shop_id,
        status: s.status || 'completed',
        createdAt: s.created_at,
        completedAt: s.created_at,
        items: (s.items || []).map((it) => ({
            productId: it.product_id,
            productName: it.product_name,
            quantity: it.quantity,
            price: it.unit_price ?? it.price,
            total: (it.unit_price ?? it.price ?? 0) * (it.quantity || 0),
        })),
    };
}

function adaptCustomer(c) {
    if (!c || typeof c !== 'object') return c;
    const openDebt = Number(c.open_debt_balance ?? c.openDebtBalance ?? 0) || 0;
    return {
        id: c.id != null ? String(c.id) : c.id,
        name: c.name,
        email: c.email,
        phone: c.phone,
        address: c.address,
        notes: c.notes,
        businessName: c.notes || c.businessName || '',
        status: c.is_active === false ? 'inactive' : 'active',
        openDebtBalance: openDebt,
        // Wateja table uses totalDebt
        totalDebt: openDebt,
        purchaseCount: c.purchase_count,
        totalSpent: c.total_spent,
        shop_id: c.shop_id,
    };
}

/** Laravel customer_debts → Express credit-sales UI shape */
function adaptCreditDebt(d) {
    if (!d || typeof d !== 'object') return d;
    const status = d.status === 'paid' || d.status === 'written_off' ? 'paid' : 'pending';
    const amount = Number(d.amount) || 0;
    const paid = Number(d.amount_paid ?? d.amountPaid) || 0;
    const balance = d.balance != null ? Number(d.balance) : Math.max(0, amount - paid);
    return {
        id: d.id,
        receiptNumber: d.note || (d.sale_id ? `Sale #${d.sale_id}` : `Debt #${d.id}`),
        saleId: d.sale_id,
        customerId: d.customer_id,
        customerName: d.customer?.name || 'Mteja',
        customerPhone: d.customer?.phone || null,
        totalAmount: amount,
        paidAmount: paid,
        balance,
        dueDate: d.due_date || d.dueDate || null,
        status,
        note: d.note,
        createdAt: d.created_at,
        shop_id: d.shop_id,
    };
}

function isCreditPaymentMethod(method) {
    const m = String(method || '').toLowerCase().trim();
    return m === 'credit' || m.includes('deni');
}

function isCashLikePaymentMethod(method) {
    const m = String(method || '').toLowerCase().trim();
    if (isCreditPaymentMethod(m)) return false;
    return m === 'cash' || m === 'card' || m.includes('mobile') || m === 'bank' || m === '';
}

function adaptCategory(c) {
    if (!c || typeof c !== 'object') return c;
    return {
        id: c.id != null ? String(c.id) : c.id,
        name: c.name,
        parentId: c.parent_id != null ? String(c.parent_id) : c.parent_id,
        status: 'active',
        shop_id: c.shop_id,
    };
}

function adaptSupplier(s) {
    if (!s || typeof s !== 'object') return s;
    return {
        id: s.id,
        name: s.name,
        phone: s.phone,
        email: s.email,
        address: s.address,
        notes: s.notes,
        maelezo: s.maelezo || s.address || s.notes || null,
        status: 'active',
        purchasesCount: s.purchases_count ?? s.purchasesCount ?? 0,
        purchasesTotal: s.purchases_total ?? s.purchasesTotal ?? 0,
        paymentsTotal: s.payments_total ?? s.paymentsTotal ?? 0,
        openDebt: s.open_debt ?? s.openDebt ?? 0,
        lastPurchasedAt: s.last_purchased_at ?? s.lastPurchasedAt ?? null,
        lastPaidAt: s.last_paid_at ?? s.lastPaidAt ?? null,
    };
}

function adaptDebtPayment(pay) {
    if (!pay || typeof pay !== 'object') return pay;
    return {
        id: pay.id,
        debtId: pay.customer_debt_id,
        amount: pay.amount,
        paymentMethod: pay.payment_method,
        reference: pay.reference,
        note: pay.note,
        notes: pay.note,
        receiptUrl: pay.receipt_url,
        receiptPath: pay.receipt_path,
        paidAt: pay.paid_at,
        createdAt: pay.paid_at || pay.created_at,
        creator: pay.creator,
    };
}

function adaptPurchasePayment(pay) {
    if (!pay || typeof pay !== 'object') return pay;
    return {
        id: pay.id,
        purchaseId: pay.purchase_id,
        supplierId: pay.supplier_id,
        amount: pay.amount,
        paidAt: pay.paid_at,
        createdAt: pay.paid_at || pay.created_at,
        paymentMethod: pay.payment_method,
        reference: pay.reference,
        notes: pay.notes,
        receiptUrl: pay.receipt_url,
        receiptPath: pay.receipt_path,
        creator: pay.creator,
    };
}

function adaptPurchase(p) {
    if (!p || typeof p !== 'object') return p;
    const amountPaid = Number(p.amount_paid ?? 0) || 0;
    const totalAmount = Number(p.subtotal ?? p.totalAmount ?? 0) || 0;
    const remaining = p.remaining != null
        ? Number(p.remaining)
        : Math.max(0, totalAmount - amountPaid);
    return {
        id: p.id,
        status: p.status,
        paymentType: p.payment_type || 'credit',
        paymentStatus: p.payment_status || 'unpaid',
        supplierId: p.supplier_id,
        supplierName: p.supplier_name || (p.supplier && p.supplier.name) || null,
        supplierDetails: p.supplier || null,
        reference: p.reference,
        invoiceNumber: p.reference,
        notes: p.notes,
        deliveredByName: p.delivered_by_name || null,
        deliveredByPhone: p.delivered_by_phone || null,
        totalAmount,
        subtotal: totalAmount,
        totalPaid: amountPaid,
        amountPaid,
        remainingBalance: remaining,
        remaining,
        productNames: p.product_names || [],
        totalQty: p.total_qty ?? 0,
        purchasedAt: p.purchased_at,
        receivedAt: p.received_at,
        createdAt: p.purchased_at || p.received_at,
        paymentHistory: (p.payments || []).map(adaptPurchasePayment),
        items: (p.items || []).map((it) => ({
            productId: it.product_id,
            productName: it.product_name,
            quantity: it.quantity,
            costPrice: it.unit_cost,
            total: it.line_total,
        })),
    };
}

function adaptStaff(u) {
    if (!u || typeof u !== 'object') return u;
    return {
        id: u.id != null ? String(u.id) : u.id,
        username: u.username || (u.email ? String(u.email).split('@')[0] : String(u.id)),
        fullName: u.name,
        email: u.email,
        phone: u.phone,
        role: u.role === 'owner' ? 'admin' : u.role,
        branchId: u.branch_id != null ? String(u.branch_id) : '',
        branchName: u.branch_name || (u.branch && u.branch.name) || null,
        status: u.status || 'active',
        createdAt: u.created_at,
    };
}

function adaptBranch(b) {
    if (!b || typeof b !== 'object') return b;
    return {
        id: b.id,
        name: b.name,
        address: b.address,
        phone: b.phone,
        status: b.status || 'active',
    };
}

function adaptSettings(shop) {
    if (!shop || typeof shop !== 'object') return shop;
    const phone = shop.mobile || shop.phone || shop.companyPhone || null;
    return {
        companyName: shop.name || shop.companyName,
        address: shop.address || shop.companyAddress,
        phone,
        companyPhone: phone,
        email: shop.email,
        taxRate: shop.tax_rate,
        currency: shop.currency,
        tin: shop.tin,
        vrn: shop.vrn,
        mobile: shop.mobile || phone,
        location: shop.location,
        taxOffice: shop.tax_office,
        receiptFooter: shop.receipt_footer || shop.receiptFooter || null,
        receiptPaperMm: Number(shop.receipt_paper_mm) === 80 ? 80 : 58,
        skipBuiltinPrinter: !!(shop.skip_builtin_printer || shop.skipBuiltinPrinter),
    };
}

function requireLaravelToken(req, res) {
    const token = req.session && req.session.laravelToken;
    if (!token) {
        // Drop stale session so /login does not bounce back to /dashboard
        if (req.session) {
            req.session.destroy(() => {});
        }
        res.clearCookie('haslim.sid', { path: '/', httpOnly: true, sameSite: 'lax' });
        res.status(401).json({ success: false, message: 'Unauthorized' });
        return null;
    }
    return token;
}

async function proxyJson(req, res, {
    path,
    method,
    body,
    adapt,
    successStatus,
}) {
    const token = requireLaravelToken(req, res);
    if (!token) return;

    try {
        const { status, json, ok } = await laravelFetch(path, { method, token, body });
        if (!ok) {
            const msg = json?.message
                || (json?.errors && Object.values(json.errors).flat().join(' '))
                || 'Request failed';
            return res.status(status).json({ success: false, message: msg, errors: json?.errors });
        }
        let data = unwrapData(json);
        if (adapt) {
            data = Array.isArray(data) ? data.map(adapt) : adapt(data);
        }
        const payload = { success: true, data };
        if (json && typeof json === 'object' && !Array.isArray(json) && json.data === undefined) {
            // bare object endpoints (settings, single sale)
            payload.data = adapt ? adapt(json) : json;
        }
        return res.status(successStatus || status || 200).json(payload);
    } catch (err) {
        console.error('Laravel proxy error:', err.message);
        return res.status(502).json({
            success: false,
            message: 'Cannot reach Laravel API. Is it running on ' + LARAVEL_URL + '?',
        });
    }
}

/**
 * @param {import('express').Express} app
 * @param {{ isAuthenticated: Function, hasRole: Function }} deps
 */
function mountLaravelSot(app, { isAuthenticated, hasRole }) {
    if (!enabled()) {
        console.log('[laravel-sot] disabled (set LARAVEL_URL / unset LARAVEL_SOT=0)');
        return;
    }
    console.log('[laravel-sot] enabled →', LARAVEL_URL);

    // ── Authenticated media stream (receipts / product images) ─────────
    // Explicit 3-segment path (Express 4); must run before Bearer JSON catch-all.
    app.get('/api/media/:folder/:shopId/:filename', async (req, res) => {
        const auth = req.headers.authorization || '';
        let token = null;
        if (auth.startsWith('Bearer ')) {
            token = auth.slice(7).trim();
        } else if (req.session && req.session.laravelToken) {
            token = req.session.laravelToken;
        }
        if (!token) {
            return res.status(401).json({ success: false, message: 'Unauthorized' });
        }
        try {
            const folder = encodeURIComponent(req.params.folder);
            const shopId = encodeURIComponent(req.params.shopId);
            const filename = encodeURIComponent(req.params.filename);
            const url = `${LARAVEL_URL}/api/media/${folder}/${shopId}/${filename}`;
            const upstream = await fetch(url, {
                method: 'GET',
                headers: {
                    Authorization: `Bearer ${token}`,
                    Accept: '*/*',
                },
            });
            const ct = upstream.headers.get('content-type') || 'application/octet-stream';
            const cd = upstream.headers.get('content-disposition');
            res.status(upstream.status);
            res.setHeader('Content-Type', ct);
            if (cd) res.setHeader('Content-Disposition', cd);
            const buf = Buffer.from(await upstream.arrayBuffer());
            return res.send(buf);
        } catch (err) {
            console.error('Laravel media proxy error:', err.message);
            return res.status(502).json({ success: false, message: 'Cannot reach media' });
        }
    });

    // products/{filename} under caller's shop (2-segment)
    app.get('/api/media/:folder/:filename', async (req, res) => {
        if (req.params.folder !== 'products') {
            return res.status(404).json({ success: false, message: 'API haipatikani' });
        }
        const auth = req.headers.authorization || '';
        let token = null;
        if (auth.startsWith('Bearer ')) {
            token = auth.slice(7).trim();
        } else if (req.session && req.session.laravelToken) {
            token = req.session.laravelToken;
        }
        if (!token) {
            return res.status(401).json({ success: false, message: 'Unauthorized' });
        }
        try {
            const url = `${LARAVEL_URL}/api/media/${encodeURIComponent(req.params.folder)}/${encodeURIComponent(req.params.filename)}`;
            const upstream = await fetch(url, {
                method: 'GET',
                headers: { Authorization: `Bearer ${token}`, Accept: '*/*' },
            });
            const ct = upstream.headers.get('content-type') || 'application/octet-stream';
            res.status(upstream.status);
            res.setHeader('Content-Type', ct);
            return res.send(Buffer.from(await upstream.arrayBuffer()));
        } catch (err) {
            return res.status(502).json({ success: false, message: 'Cannot reach media' });
        }
    });

    // ── Mobile Sanctum pass-through (Bearer /api/login) ───────────────
    // Flutter talks Laravel shape directly; web keeps cookie session below.
    app.post('/api/login', async (req, res) => {
        try {
            const { status, json } = await laravelFetch('/login', {
                method: 'POST',
                body: req.body,
            });
            return res.status(status).json(json);
        } catch (err) {
            console.error('Laravel /api/login proxy error:', err.message);
            return res.status(502).json({
                message: 'Cannot reach Laravel API at ' + LARAVEL_URL,
            });
        }
    });

    app.use('/api', async (req, res, next) => {
        const auth = req.headers.authorization || '';
        if (!auth.startsWith('Bearer ')) {
            return next();
        }
        // Binary media is handled by the dedicated GET /api/media route above
        if (req.method === 'GET' && (req.path || '').startsWith('/media')) {
            return next();
        }
        try {
            const rawPath = (req.originalUrl || req.url || '/').replace(/^\/api/, '') || '/';
            const { status, json } = await laravelFetch(rawPath, {
                method: req.method,
                token: auth.slice(7).trim(),
                body: ['GET', 'HEAD'].includes(req.method) ? undefined : req.body,
            });
            return res.status(status).json(json);
        } catch (err) {
            console.error('Laravel Bearer proxy error:', err.message);
            return res.status(502).json({
                message: 'Cannot reach Laravel API at ' + LARAVEL_URL,
            });
        }
    });

    // ── Auth ──────────────────────────────────────────────────────────
    app.post('/api/auth/login', async (req, res) => {
        const username = typeof req.body?.username === 'string' ? req.body.username.trim() : '';
        const password = typeof req.body?.password === 'string' ? req.body.password : '';
        if (!username || !password) {
            return res.status(400).json({ success: false, message: 'Taarifa za kuingia si sahihi' });
        }

        try {
            const { status, json, ok } = await laravelFetch('/login', {
                method: 'POST',
                body: { username, password },
            });
            if (!ok) {
                const msg = json?.message
                    || (json?.errors && Object.values(json.errors).flat()[0])
                    || 'Jina la mtumiaji au nenosiri si sahihi';
                return res.status(status === 422 ? 401 : status).json({ success: false, message: msg });
            }

            const token = json.token;
            const sessionUser = mapLaravelUserToSession(json.user || {});

            req.session.regenerate((regenerateError) => {
                if (regenerateError) {
                    return res.status(500).json({ success: false, message: 'Session error' });
                }
                const startedAt = new Date().toISOString();
                req.session.startedAt = startedAt;
                req.session.absoluteExpiresAt = new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString();
                req.session.laravelToken = token;
                req.session.user = sessionUser;
                req.session.save((err) => {
                    if (err) {
                        return res.status(500).json({ success: false, message: 'Session error' });
                    }
                    try {
                        const { onAdminLogin } = require('./receipt-auto-print');
                        onAdminLogin(sessionUser, token);
                    } catch (printErr) {
                        console.error('[receipt-print] login catch-up error:', printErr.message);
                    }
                    res.json({
                        success: true,
                        message: 'Umefanikiwa kuingia',
                        user: sessionUser,
                    });
                });
            });
        } catch (err) {
            console.error('Laravel login error:', err.message);
            return res.status(502).json({
                success: false,
                message: 'Cannot reach Laravel API at ' + LARAVEL_URL,
            });
        }
    });

    app.post('/api/auth/logout', isAuthenticated, async (req, res) => {
        const token = req.session.laravelToken;
        try {
            const { onAdminLogout } = require('./receipt-auto-print');
            onAdminLogout();
        } catch (_) { /* ignore */ }
        try {
            if (token) {
                await laravelFetch('/logout', { method: 'POST', token });
            }
        } catch (_) { /* ignore */ }
        req.session.destroy(() => {
            res.clearCookie('haslim.sid', { path: '/', httpOnly: true, sameSite: 'lax' });
            res.json({ success: true, message: 'Umetoka kwenye mfumo' });
        });
    });

    app.get('/api/auth/me', isAuthenticated, async (req, res) => {
        const token = req.session.laravelToken;
        if (!token) {
            return res.json({ success: true, user: req.session.user });
        }
        try {
            const { ok, json } = await laravelFetch('/me', { token });
            if (ok && json) {
                const sessionUser = mapLaravelUserToSession(json);
                req.session.user = sessionUser;
                return res.json({ success: true, user: sessionUser });
            }
        } catch (_) { /* fall through */ }
        return res.json({ success: true, user: req.session.user });
    });

    app.get('/api/realtime-config', isAuthenticated, async (req, res) => {
        const token = req.session.laravelToken;
        if (!token) {
            return res.status(503).json({ success: false, message: 'Realtime config needs Laravel login' });
        }
        try {
            const { ok, json, status } = await laravelFetch('/realtime-config', { token });
            if (!ok) {
                return res.status(status || 502).json({ success: false, message: json?.message || 'Config failed' });
            }
            return res.json({ success: true, ...(json || {}) });
        } catch (err) {
            console.error('realtime-config proxy error:', err.message);
            return res.status(502).json({ success: false, message: err.message });
        }
    });

    // Browser Echo/Pusher auth (cookie session → Laravel Sanctum token)
    app.post('/api/broadcasting/auth', isAuthenticated, async (req, res) => {
        const token = req.session.laravelToken;
        if (!token) {
            return res.status(401).json({ message: 'Not authenticated with API' });
        }
        try {
            const { status, json } = await laravelFetch('/broadcasting/auth', {
                method: 'POST',
                token,
                body: {
                    socket_id: req.body?.socket_id,
                    channel_name: req.body?.channel_name,
                },
            });
            return res.status(status).json(json);
        } catch (err) {
            console.error('broadcasting auth proxy error:', err.message);
            return res.status(502).json({ message: err.message });
        }
    });

    // ── Reads ─────────────────────────────────────────────────────────
    app.get('/api/products', isAuthenticated, (req, res) =>
        proxyJson(req, res, { path: '/products', adapt: adaptProduct }));

    app.get('/api/products/:id', isAuthenticated, (req, res) =>
        proxyJson(req, res, { path: `/products/${req.params.id}`, adapt: adaptProduct }));

    app.get('/api/categories', isAuthenticated, (req, res) =>
        proxyJson(req, res, { path: '/categories', adapt: adaptCategory }));

    app.get('/api/sales', isAuthenticated, async (req, res) => {
        const q = new URLSearchParams();
        if (req.query.startDate) q.set('from', req.query.startDate);
        if (req.query.endDate) q.set('to', req.query.endDate);
        if (req.query.date) q.set('date', req.query.date);
        if (req.query.per_page) q.set('per_page', req.query.per_page);
        const qs = q.toString() ? `?${q}` : '';
        return proxyJson(req, res, { path: `/sales${qs}`, adapt: adaptSale });
    });

    app.get('/api/sales/:id', isAuthenticated, (req, res) =>
        proxyJson(req, res, { path: `/sales/${req.params.id}`, adapt: adaptSale }));

    // Thermal receipt HTML — sales live in Laravel when SoT is on
    app.get('/api/sales/:id/receipt', isAuthenticated, hasRole('admin', 'super_admin'), async (req, res) => {
        const token = requireLaravelToken(req, res);
        if (!token) return;
        try {
            const [saleRes, settingsRes] = await Promise.all([
                laravelFetch(`/sales/${req.params.id}`, { token }),
                laravelFetch('/settings', { token }),
            ]);
            if (!saleRes.ok || !saleRes.json) {
                return res.status(saleRes.status || 404).send('<p>Sale not found</p>');
            }
            const raw = saleRes.json?.data && !saleRes.json.serial_number
                ? saleRes.json.data
                : saleRes.json;
            const sale = adaptSale(raw);
            if (!sale || !sale.id) {
                return res.status(404).send('<p>Sale not found</p>');
            }
            const settings = settingsRes.ok
                ? adaptSettings(unwrapData(settingsRes.json) || settingsRes.json || {})
                : {};
            const merged = {
                ...(settings || {}),
                receiptPaperMm: 80,
                autoPrint: String(req.query.autoprint || '') === '1',
                printJobId: req.query.job_id || '',
            };
            res.setHeader('Content-Type', 'text/html; charset=UTF-8');
            return res.send(renderSaleReceiptHtml(sale, merged));
        } catch (err) {
            console.error('Laravel receipt proxy error:', err.message);
            return res.status(502).send('<p>Cannot load receipt</p>');
        }
    });

    app.get('/api/customers', isAuthenticated, (req, res) => {
        const q = new URLSearchParams();
        if (req.query.search) q.set('search', req.query.search);
        const qs = q.toString() ? `?${q}` : '';
        return proxyJson(req, res, { path: `/customers${qs}`, adapt: adaptCustomer });
    });

    app.get('/api/customers/:id', isAuthenticated, (req, res) =>
        proxyJson(req, res, { path: `/customers/${req.params.id}`, adapt: adaptCustomer }));

    app.get('/api/settings', isAuthenticated, (req, res) =>
        proxyJson(req, res, { path: '/settings', adapt: adaptSettings }));

    app.get('/api/receipt-jobs', isAuthenticated, hasRole('admin', 'super_admin'), async (req, res) => {
        const token = requireLaravelToken(req, res);
        if (!token) return;
        const q = req.query.status ? `?status=${encodeURIComponent(req.query.status)}` : '';
        try {
            const { ok, json, status } = await laravelFetch(`/receipt-jobs${q}`, { token });
            if (!ok) {
                return res.status(status).json({ success: false, message: json?.message || 'Failed' });
            }
            return res.json({
                success: true,
                can_print: !!json?.can_print,
                data: json?.data || [],
            });
        } catch (err) {
            return res.status(502).json({ success: false, message: err.message });
        }
    });

    app.get('/api/receipt-jobs/:id', isAuthenticated, hasRole('admin', 'super_admin'), async (req, res) => {
        const token = requireLaravelToken(req, res);
        if (!token) return;
        try {
            const { ok, json, status } = await laravelFetch(`/receipt-jobs/${req.params.id}`, { token });
            if (!ok) {
                return res.status(status).json({ success: false, message: json?.message || 'Failed' });
            }
            return res.json({ success: true, data: json?.data || json });
        } catch (err) {
            return res.status(502).json({ success: false, message: err.message });
        }
    });

    app.post('/api/receipt-jobs/:id/printed', isAuthenticated, hasRole('admin'), async (req, res) => {
        const token = requireLaravelToken(req, res);
        if (!token) return;
        try {
            const { ok, json, status } = await laravelFetch(`/receipt-jobs/${req.params.id}/printed`, {
                method: 'POST',
                token,
                body: {},
            });
            if (!ok) {
                return res.status(status).json({ success: false, message: json?.message || 'Failed' });
            }
            return res.json({ success: true, data: json?.data || json });
        } catch (err) {
            return res.status(502).json({ success: false, message: err.message });
        }
    });

    app.get('/api/dashboard/super', isAuthenticated, hasRole('super_admin'), async (req, res) => {
        const token = requireLaravelToken(req, res);
        if (!token) return;
        try {
            const { ok, json, status } = await laravelFetch('/dashboard/super', { token });
            if (!ok) {
                return res.status(status).json({ success: false, message: json?.message || 'Failed' });
            }
            return res.json({ success: true, data: json?.data || json });
        } catch (err) {
            return res.status(502).json({ success: false, message: err.message });
        }
    });

    app.get('/api/dashboard/stats', isAuthenticated, async (req, res) => {
        const token = requireLaravelToken(req, res);
        if (!token) return;
        try {
            const [{ ok, json, status }, debtsRes, customersRes] = await Promise.all([
                laravelFetch('/dashboard', { token }),
                laravelFetch('/debts/summary', { token }),
                laravelFetch('/customers', { token }),
            ]);
            if (!ok) {
                return res.status(status).json({ success: false, message: json?.message || 'Failed' });
            }
            const debtSummary = debtsRes.ok ? debtsRes.json : {};
            const customersList = customersRes.ok
                ? (unwrapData(customersRes.json) || [])
                : [];
            // Shape for Express dashboard widgets
            return res.json({
                success: true,
                data: {
                    today: {
                        revenue: json.today_total || 0,
                        transactions: json.today_transactions || 0,
                    },
                    week: {
                        revenue: (json.weekly_sales || []).reduce((a, d) => a + (d.total || 0), 0),
                        transactions: (json.weekly_sales || []).reduce((a, d) => a + (d.transactions || 0), 0),
                    },
                    month: { revenue: 0, transactions: 0, expenses: 0, profit: 0 },
                    products: {
                        total: json.total_products || 0,
                        lowStock: json.low_stock_count || 0,
                        expiring: 0,
                    },
                    customers: { total: Array.isArray(customersList) ? customersList.length : 0 },
                    debts: {
                        total: Number(debtSummary.open_balance) || 0,
                        count: Number(debtSummary.open_count) || 0,
                        collected: Number(debtSummary.collected_total) || 0,
                    },
                    lowStockProducts: [],
                    expiringProducts: [],
                    topProducts: [],
                    salesByDay: (json.weekly_sales || []).map((d) => ({
                        date: d.date,
                        revenue: d.total,
                        transactions: d.transactions,
                    })),
                    salesByMonth: [],
                },
            });
        } catch (err) {
            return res.status(502).json({ success: false, message: err.message });
        }
    });

    // Madeni — Laravel customer_debts
    app.get('/api/credit-sales', isAuthenticated, hasRole('admin', 'cashier', 'storekeeper'), (req, res) => {
        const q = new URLSearchParams();
        if (req.query.status) q.set('status', req.query.status);
        if (req.query.customerId) q.set('customer_id', req.query.customerId);
        const qs = q.toString() ? `?${q}` : '';
        return proxyJson(req, res, { path: `/debts${qs}`, adapt: adaptCreditDebt });
    });

    app.get('/api/credit-sales/:id/payments', isAuthenticated, hasRole('admin', 'cashier', 'storekeeper'), async (req, res) => {
        const token = requireLaravelToken(req, res);
        if (!token) return;
        try {
            const { status, json, ok } = await laravelFetch(`/debts/${req.params.id}/payments`, { token });
            if (!ok) {
                return res.status(status).json({ success: false, message: json?.message || 'Failed' });
            }
            const list = (json?.data || []).map(adaptDebtPayment);
            const debt = json?.debt ? adaptCreditDebt(json.debt) : null;
            return res.json({ success: true, data: list, debt });
        } catch (err) {
            return res.status(502).json({ success: false, message: err.message });
        }
    });

    app.post(
        '/api/credit-sales/:id/pay',
        isAuthenticated,
        hasRole('admin', 'cashier', 'storekeeper'),
        (req, res, next) => {
            const ct = req.headers['content-type'] || '';
            if (ct.includes('multipart/form-data')) {
                return uploadPurchaseReceipt.single('receipt')(req, res, next);
            }
            return next();
        },
        async (req, res) => {
            const token = requireLaravelToken(req, res);
            if (!token) return;
            try {
                const b = req.body || {};
                const body = withReceiptBase64({
                    amount: b.amount,
                    note: b.note || b.notes || null,
                    payment_method: b.paymentMethod || b.payment_method || 'cash',
                    reference: b.reference || null,
                    paid_at: b.paidAt || b.paid_at || null,
                    receipt_base64: b.receipt_base64 || b.receiptBase64 || null,
                    receipt_filename: b.receipt_filename || b.receiptFilename || null,
                }, req.file);
                const { status, json, ok } = await laravelFetch(`/debts/${req.params.id}/payments`, {
                    method: 'POST',
                    token,
                    body,
                });
                if (!ok) {
                    return res.status(status).json({
                        success: false,
                        message: json?.message || 'Lipa imeshindikana',
                    });
                }
                return res.json({
                    success: true,
                    data: json?.debt ? adaptCreditDebt(json.debt) : adaptDebtPayment(json?.data || json),
                    payment: json?.data ? adaptDebtPayment(json.data) : null,
                    message: 'Malipo yamepokelewa',
                });
            } catch (err) {
                return res.status(502).json({ success: false, message: err.message });
            }
        }
    );

    app.put(
        '/api/credit-sales/:id/payments/:paymentId',
        isAuthenticated,
        hasRole('admin', 'cashier', 'storekeeper'),
        (req, res, next) => {
            const ct = req.headers['content-type'] || '';
            if (ct.includes('multipart/form-data')) {
                return uploadPurchaseReceipt.single('receipt')(req, res, next);
            }
            return next();
        },
        async (req, res) => {
            const token = requireLaravelToken(req, res);
            if (!token) return;
            try {
                const b = req.body || {};
                const body = withReceiptBase64({
                    amount: b.amount,
                    payment_method: b.paymentMethod || b.payment_method || 'cash',
                    reference: b.reference != null ? b.reference : null,
                    note: b.note != null || b.notes != null ? (b.note || b.notes || '') : null,
                    paid_at: b.paidAt || b.paid_at || null,
                }, req.file);
                const { status, json, ok } = await laravelFetch(
                    `/debts/${req.params.id}/payments/${req.params.paymentId}`,
                    { method: 'POST', token, body }
                );
                if (!ok) {
                    return res.status(status).json({
                        success: false,
                        message: json?.message || 'Hariri imeshindikana',
                    });
                }
                return res.json({
                    success: true,
                    data: json?.data ? adaptDebtPayment(json.data) : null,
                    debt: json?.debt ? adaptCreditDebt(json.debt) : null,
                    message: 'Malipo yamehaririwa',
                });
            } catch (err) {
                return res.status(502).json({ success: false, message: err.message });
            }
        }
    );

    // Ripoti — aggregate Laravel sales (cash vs credit)
    app.get('/api/reports/sales', isAuthenticated, async (req, res) => {
        const token = requireLaravelToken(req, res);
        if (!token) return;
        try {
            const q = new URLSearchParams();
            if (req.query.startDate) q.set('from', req.query.startDate);
            if (req.query.endDate) q.set('to', req.query.endDate);
            q.set('per_page', '500');
            const { ok, json, status } = await laravelFetch(`/sales?${q}`, { token });
            if (!ok) {
                return res.status(status).json({ success: false, message: json?.message || 'Failed' });
            }
            const raw = unwrapData(json) || [];
            const sales = (Array.isArray(raw) ? raw : []).map(adaptSale);

            let totalCash = 0;
            let totalDebts = 0;
            let totalRevenue = 0;
            let totalDiscount = 0;
            const groupedData = {};

            for (const s of sales) {
                const amount = Number(s.totalAmount) || 0;
                const discount = Number(s.discount) || 0;
                const tenderedRaw = Number(s.amountTendered);
                // null/NaN → legacy full pay; explicit 0 → zero received
                const tendered = Number.isFinite(tenderedRaw)
                    ? Math.max(0, tenderedRaw)
                    : amount;
                let cashPart = 0;
                let debtPart = 0;
                if (isCreditPaymentMethod(s.paymentMethod)) {
                    debtPart = amount;
                } else if (isCashLikePaymentMethod(s.paymentMethod)) {
                    cashPart = Math.min(tendered, amount);
                    debtPart = Math.max(0, amount - tendered);
                } else {
                    cashPart = amount;
                }
                totalRevenue += amount;
                totalDiscount += discount;
                totalCash += cashPart;
                totalDebts += debtPart;

                const key = (s.createdAt || '').slice(0, 10) || 'unknown';
                if (!groupedData[key]) {
                    groupedData[key] = { date: key, revenue: 0, cash: 0, debts: 0, transactions: 0, items: 0 };
                }
                groupedData[key].revenue += amount;
                groupedData[key].transactions += 1;
                groupedData[key].items += (s.items || []).reduce((sum, i) => sum + (i.quantity || 0), 0);
                groupedData[key].cash += cashPart;
                groupedData[key].debts += debtPart;
            }

            const totalTransactions = sales.length;
            return res.json({
                success: true,
                data: {
                    summary: {
                        totalRevenue,
                        totalCash,
                        totalDebts,
                        totalDiscount,
                        totalTransactions,
                        averageTransaction: totalTransactions > 0 ? totalRevenue / totalTransactions : 0,
                    },
                    groupedData: Object.values(groupedData).sort((a, b) =>
                        String(a.date).localeCompare(String(b.date))),
                    sales,
                },
            });
        } catch (err) {
            return res.status(502).json({ success: false, message: err.message });
        }
    });

    app.get('/api/suppliers', isAuthenticated, (req, res) =>
        proxyJson(req, res, { path: '/suppliers', adapt: adaptSupplier }));

    app.get('/api/suppliers/:id/statement', isAuthenticated, async (req, res) => {
        const q = new URLSearchParams();
        ['from', 'to', 'preset'].forEach((k) => {
            if (req.query[k]) q.set(k, req.query[k]);
        });
        const qs = q.toString() ? `?${q}` : '';
        return proxyJson(req, res, { path: `/suppliers/${req.params.id}/statement${qs}` });
    });

    app.get('/api/suppliers/:id/statement.pdf', isAuthenticated, async (req, res) => {
        const token = requireLaravelToken(req, res);
        if (!token) return;
        try {
            const q = new URLSearchParams();
            ['from', 'to', 'preset'].forEach((k) => {
                if (req.query[k]) q.set(k, req.query[k]);
            });
            const qs = q.toString() ? `?${q}` : '';
            const url = `${LARAVEL_URL}/api/suppliers/${req.params.id}/statement.pdf${qs}`;
            const upstream = await fetch(url, {
                headers: { Authorization: `Bearer ${token}`, Accept: 'text/html' },
            });
            const html = await upstream.text();
            res.status(upstream.status).set('Content-Type', 'text/html; charset=UTF-8').send(html);
        } catch (err) {
            res.status(502).json({ success: false, message: err.message });
        }
    });

    app.get('/api/cashflow/summary', isAuthenticated, async (req, res) => {
        const q = new URLSearchParams();
        if (req.query.from || req.query.startDate) q.set('from', req.query.from || req.query.startDate);
        if (req.query.to || req.query.endDate) q.set('to', req.query.to || req.query.endDate);
        const qs = q.toString() ? `?${q}` : '';
        return proxyJson(req, res, { path: `/cashflow/summary${qs}` });
    });

    app.get('/api/purchases', isAuthenticated, (req, res) => {
        const q = new URLSearchParams();
        if (req.query.startDate) q.set('from', req.query.startDate);
        if (req.query.endDate) q.set('to', req.query.endDate);
        if (req.query.from) q.set('from', req.query.from);
        if (req.query.to) q.set('to', req.query.to);
        if (req.query.supplierId) q.set('supplier_id', req.query.supplierId);
        if (req.query.supplier_id) q.set('supplier_id', req.query.supplier_id);
        if (req.query.search) q.set('search', req.query.search);
        if (req.query.payment_status) q.set('payment_status', req.query.payment_status);
        const qs = q.toString() ? `?${q}` : '';
        return proxyJson(req, res, { path: `/purchases${qs}`, adapt: adaptPurchase });
    });

    app.get('/api/purchases/:id', isAuthenticated, (req, res) =>
        proxyJson(req, res, { path: `/purchases/${req.params.id}`, adapt: adaptPurchase }));

    app.get('/api/purchases/:id/payments', isAuthenticated, async (req, res) => {
        const token = requireLaravelToken(req, res);
        if (!token) return;
        try {
            const { status, json, ok } = await laravelFetch(`/purchases/${req.params.id}/payments`, { token });
            if (!ok) {
                return res.status(status).json({ success: false, message: json?.message || 'Failed' });
            }
            const list = (json?.data || []).map(adaptPurchasePayment);
            const purchase = json?.purchase ? adaptPurchase(json.purchase) : null;
            return res.json({ success: true, data: list, purchase });
        } catch (err) {
            return res.status(502).json({ success: false, message: err.message });
        }
    });

    app.post(
        '/api/purchases/:id/payments',
        isAuthenticated,
        hasRole('admin', 'storekeeper'),
        uploadPurchaseReceipt.single('receipt'),
        async (req, res) => {
            const token = requireLaravelToken(req, res);
            if (!token) return;
            try {
                const b = req.body || {};
                const body = withReceiptBase64({
                    amount: b.amount,
                    paid_at: b.paid_at || b.paidAt || null,
                    payment_method: b.payment_method || b.paymentMethod || 'cash',
                    reference: b.reference || null,
                    notes: b.notes || null,
                }, req.file);

                const { status, json, ok } = await laravelFetch(`/purchases/${req.params.id}/payments`, {
                    method: 'POST',
                    token,
                    body,
                });
                if (!ok) {
                    return res.status(status).json({
                        success: false,
                        message: json?.message || 'Lipa imeshindikana',
                        remaining: json?.remaining,
                        errors: json?.errors,
                    });
                }
                return res.status(201).json({
                    success: true,
                    data: adaptPurchasePayment(json?.data || json),
                    purchase: json?.purchase ? adaptPurchase(json.purchase) : null,
                });
            } catch (err) {
                return res.status(502).json({ success: false, message: err.message });
            }
        }
    );

    app.get('/api/users', isAuthenticated, hasRole('admin'), (req, res) =>
        proxyJson(req, res, { path: '/staff', adapt: adaptStaff }));

    app.get('/api/branches', isAuthenticated, (req, res) =>
        proxyJson(req, res, { path: '/branches', adapt: adaptBranch }));

    // Stock list from product quantities
    app.get('/api/stock', isAuthenticated, async (req, res) => {
        const token = requireLaravelToken(req, res);
        if (!token) return;
        try {
            const { ok, json, status } = await laravelFetch('/stock', { token });
            if (ok) {
                const data = unwrapData(json);
                return res.json({ success: true, data: Array.isArray(data) ? data : [] });
            }
            // Fallback: derive from products if /stock not available
            if (status === 404) {
                const prod = await laravelFetch('/products', { token });
                const list = unwrapData(prod.json) || [];
                const stock = (Array.isArray(list) ? list : []).map((p) => ({
                    id: p.id,
                    productId: p.id,
                    productName: p.name,
                    quantity: p.stock ?? 0,
                    type: 'in',
                    unit: p.unit,
                    minStock: p.low_stock_threshold,
                }));
                return res.json({ success: true, data: stock });
            }
            return res.status(status).json({ success: false, message: json?.message || 'Failed' });
        } catch (err) {
            return res.status(502).json({ success: false, message: err.message });
        }
    });

    // ── Writes ────────────────────────────────────────────────────────
    app.post('/api/products', isAuthenticated, hasRole('admin', 'storekeeper'), async (req, res) => {
        const b = req.body || {};
        const body = {
            name: b.name,
            description: b.description,
            price: b.retailPrice ?? b.price,
            cost_price: b.wholesalePrice ?? b.costPrice ?? b.cost_price,
            barcode: b.barcode,
            sku: b.sku,
            unit: b.unit,
            stock: b.stock ?? b.currentStock ?? 0,
            low_stock_threshold: b.minStock ?? b.low_stock_threshold ?? 10,
            category_id: b.categoryId ?? b.category_id,
            category: b.categoryName ?? b.category,
            status: b.status || 'active',
        };
        return proxyJson(req, res, {
            path: '/products',
            method: 'POST',
            body,
            adapt: adaptProduct,
            successStatus: 201,
        });
    });

    app.put('/api/products/:id', isAuthenticated, hasRole('admin', 'storekeeper'), async (req, res) => {
        const b = req.body || {};
        const body = {
            name: b.name,
            description: b.description,
            price: b.retailPrice ?? b.price,
            cost_price: b.wholesalePrice ?? b.costPrice ?? b.cost_price,
            barcode: b.barcode,
            sku: b.sku,
            unit: b.unit,
            stock: b.stock ?? b.currentStock,
            low_stock_threshold: b.minStock ?? b.low_stock_threshold,
            category_id: b.categoryId ?? b.category_id,
            category: b.categoryName ?? b.category,
            status: b.status,
        };
        Object.keys(body).forEach((k) => body[k] === undefined && delete body[k]);
        return proxyJson(req, res, {
            path: `/products/${req.params.id}`,
            method: 'PUT',
            body,
            adapt: adaptProduct,
        });
    });

    app.delete('/api/products/:id', isAuthenticated, hasRole('admin'), (req, res) =>
        proxyJson(req, res, { path: `/products/${req.params.id}`, method: 'DELETE' }));

    app.post('/api/categories', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) =>
        proxyJson(req, res, {
            path: '/categories',
            method: 'POST',
            body: { name: req.body?.name, parent_id: req.body?.parentId ?? req.body?.parent_id },
            adapt: adaptCategory,
            successStatus: 201,
        }));

    app.delete('/api/categories/:id', isAuthenticated, hasRole('admin'), (req, res) =>
        proxyJson(req, res, { path: `/categories/${req.params.id}`, method: 'DELETE' }));

    app.post('/api/sales', isAuthenticated, hasRole('admin', 'cashier', 'reception'), async (req, res) => {
        const b = req.body || {};
        const items = (b.items || []).map((it) => ({
            product_id: it.productId ?? it.product_id,
            quantity: it.quantity,
            price: it.price,
        }));
        const isCredit = !!(b.isCredit || b.is_credit);
        const paymentMethod = isCredit
            ? 'credit'
            : (b.paymentMethod || b.payment_method || 'cash');
        const body = {
            items,
            payment_method: paymentMethod,
            discount: b.discount || 0,
            subtotal: b.subtotal,
            total: b.totalAmount ?? b.total,
            shop_customer_id: b.customerId ?? b.shop_customer_id,
            customer_name: b.customerName,
            customer_phone: b.customerPhone,
            amount_tendered: b.amountTendered ?? b.amount_tendered,
            client_sale_id: b.clientSaleId ?? b.client_sale_id,
        };
        const headers = {};
        if (b.idempotencyKey || req.headers['idempotency-key']) {
            headers['Idempotency-Key'] = b.idempotencyKey || req.headers['idempotency-key'];
        }
        const token = requireLaravelToken(req, res);
        if (!token) return;
        try {
            const { status, json, ok } = await laravelFetch('/sales', {
                method: 'POST',
                token,
                body,
                headers,
            });
            if (!ok) {
                const msg = json?.message
                    || (json?.errors && Object.values(json.errors).flat().join(' '))
                    || 'Sale failed';
                return res.status(status).json({ success: false, message: msg });
            }
            return res.status(201).json({ success: true, data: adaptSale(json) });
        } catch (err) {
            return res.status(502).json({ success: false, message: err.message });
        }
    });

    app.post('/api/customers', isAuthenticated, (req, res) => {
        const b = req.body || {};
        return proxyJson(req, res, {
            path: '/customers',
            method: 'POST',
            body: {
                name: b.name,
                phone: b.phone,
                email: b.email,
                address: b.address,
                notes: b.notes || b.businessName,
            },
            adapt: adaptCustomer,
            successStatus: 201,
        });
    });

    app.put('/api/customers/:id', isAuthenticated, (req, res) => {
        const b = req.body || {};
        return proxyJson(req, res, {
            path: `/customers/${req.params.id}`,
            method: 'PUT',
            body: {
                name: b.name,
                phone: b.phone,
                email: b.email,
                address: b.address,
                notes: b.notes,
                is_active: b.status !== 'inactive',
            },
            adapt: adaptCustomer,
        });
    });

    app.delete('/api/customers/:id', isAuthenticated, hasRole('admin'), (req, res) =>
        proxyJson(req, res, { path: `/customers/${req.params.id}`, method: 'DELETE' }));

    app.post('/api/suppliers', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
        const b = req.body || {};
        return proxyJson(req, res, {
            path: '/suppliers',
            method: 'POST',
            body: {
                name: b.name,
                phone: b.phone,
                email: b.email,
                address: b.address,
                notes: b.notes || b.contactPerson,
            },
            adapt: adaptSupplier,
            successStatus: 201,
        });
    });

    app.put('/api/suppliers/:id', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
        const b = req.body || {};
        return proxyJson(req, res, {
            path: `/suppliers/${req.params.id}`,
            method: 'PUT',
            body: {
                name: b.name,
                phone: b.phone,
                email: b.email,
                address: b.address,
                notes: b.notes || b.contactPerson,
            },
            adapt: adaptSupplier,
        });
    });

    app.delete('/api/suppliers/:id', isAuthenticated, hasRole('admin'), (req, res) =>
        proxyJson(req, res, { path: `/suppliers/${req.params.id}`, method: 'DELETE' }));

    app.post(
        '/api/purchases',
        isAuthenticated,
        hasRole('admin', 'storekeeper'),
        (req, res, next) => {
            const ct = req.headers['content-type'] || '';
            if (ct.includes('multipart/form-data')) {
                return uploadPurchaseReceipt.single('receipt')(req, res, next);
            }
            return next();
        },
        async (req, res) => {
            const token = requireLaravelToken(req, res);
            if (!token) return;
            try {
                const b = req.body || {};
                let rawItems = b.items;
                if (typeof rawItems === 'string') {
                    try {
                        rawItems = JSON.parse(rawItems);
                    } catch {
                        rawItems = [];
                    }
                }
                const items = (Array.isArray(rawItems) ? rawItems : []).map((it) => ({
                    product_id: it.productId ?? it.product_id,
                    quantity: it.quantity,
                    unit_cost: it.costPrice ?? it.unit_cost ?? it.unitCost,
                }));
                let amountPaid = b.amountPaid ?? b.amount_paid;
                const paymentType = b.paymentType || b.payment_type || 'credit';
                if (amountPaid == null && paymentType === 'cash') {
                    amountPaid = undefined;
                }
                const receiveNow = b.receive_now !== false && b.receiveNow !== false
                    && b.receive_now !== 'false' && b.receiveNow !== 'false';
                const body = withReceiptBase64({
                    supplier_id: b.supplierId ?? b.supplier_id,
                    reference: b.invoiceNumber ?? b.reference,
                    notes: b.notes,
                    purchased_at: b.purchasedAt || b.purchased_at || new Date().toISOString().slice(0, 10),
                    receive_now: receiveNow,
                    payment_type: paymentType,
                    payment_method: b.paymentMethod || b.payment_method || 'cash',
                    amount_paid: amountPaid,
                    delivered_by_name: b.deliveredByName || b.delivered_by_name,
                    delivered_by_phone: b.deliveredByPhone || b.delivered_by_phone,
                    receipt_base64: b.receipt_base64 || b.receiptBase64 || null,
                    receipt_filename: b.receipt_filename || b.receiptFilename || null,
                    items,
                }, req.file);

                const { status, json, ok } = await laravelFetch('/purchases', {
                    method: 'POST',
                    token,
                    body,
                });
                if (!ok) {
                    return res.status(status).json({
                        success: false,
                        message: json?.message || 'Imeshindikana kuhifadhi manunuzi',
                        errors: json?.errors,
                    });
                }
                return res.status(201).json({
                    success: true,
                    data: adaptPurchase(json?.data || json),
                    message: 'Manunuzi yamehifadhiwa',
                });
            } catch (err) {
                return res.status(502).json({ success: false, message: err.message });
            }
        }
    );

    app.put('/api/settings', isAuthenticated, hasRole('admin'), (req, res) => {
        const b = req.body || {};
        return proxyJson(req, res, {
            path: '/settings',
            method: 'PUT',
            body: {
                name: b.companyName ?? b.name,
                address: b.address,
                phone: b.phone,
                email: b.email,
                tax_rate: b.taxRate ?? b.tax_rate,
                currency: b.currency,
                tin: b.tin,
                vrn: b.vrn,
                mobile: b.mobile,
                location: b.location,
                tax_office: b.taxOffice ?? b.tax_office,
                receipt_paper_mm: b.receiptPaperMm ?? b.receipt_paper_mm,
                skip_builtin_printer: b.skipBuiltinPrinter ?? b.skip_builtin_printer,
            },
            adapt: adaptSettings,
        });
    });

    app.post('/api/users', isAuthenticated, hasRole('admin'), (req, res) => {
        const b = req.body || {};
        return proxyJson(req, res, {
            path: '/staff',
            method: 'POST',
            body: {
                name: b.fullName || b.name,
                username: b.username || undefined,
                email: b.email || (b.username ? `${b.username}@local.test` : undefined),
                password: b.password,
                branch_id: b.branchId || b.branch_id || null,
                phone: b.phone || null,
                role: b.role === 'admin' ? 'owner' : (b.role || 'cashier'),
            },
            adapt: adaptStaff,
            successStatus: 201,
        });
    });

    app.put('/api/users/:id', isAuthenticated, hasRole('admin'), (req, res) => {
        const b = req.body || {};
        const body = {
            name: b.fullName || b.name,
            username: b.username || undefined,
            email: b.email || undefined,
            phone: b.phone || null,
            branch_id: b.branchId || b.branch_id || null,
            role: b.role === 'admin' ? 'owner' : b.role,
            status: b.status || undefined,
            password: b.password || undefined,
        };
        Object.keys(body).forEach((k) => body[k] === undefined && delete body[k]);
        return proxyJson(req, res, {
            path: `/staff/${req.params.id}`,
            method: 'PUT',
            body,
            adapt: adaptStaff,
        });
    });

    app.delete('/api/users/:id', isAuthenticated, hasRole('admin'), (req, res) =>
        proxyJson(req, res, { path: `/staff/${req.params.id}`, method: 'DELETE' }));

    app.post('/api/branches', isAuthenticated, hasRole('admin'), (req, res) =>
        proxyJson(req, res, {
            path: '/branches',
            method: 'POST',
            body: {
                name: req.body?.name,
                address: req.body?.address,
                phone: req.body?.phone,
            },
            adapt: adaptBranch,
            successStatus: 201,
        }));

    app.put('/api/branches/:id', isAuthenticated, hasRole('admin'), (req, res) =>
        proxyJson(req, res, {
            path: `/branches/${req.params.id}`,
            method: 'PUT',
            body: {
                name: req.body?.name,
                address: req.body?.address,
                phone: req.body?.phone,
                status: req.body?.status,
            },
            adapt: adaptBranch,
        }));

    app.delete('/api/branches/:id', isAuthenticated, hasRole('admin'), (req, res) =>
        proxyJson(req, res, { path: `/branches/${req.params.id}`, method: 'DELETE' }));

    // Stock mutations
    app.post('/api/stock/in', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
        const b = req.body || {};
        return proxyJson(req, res, {
            path: '/stock/in',
            method: 'POST',
            body: {
                product_id: b.productId ?? b.product_id,
                quantity: b.quantity,
                cost_price: b.costPrice ?? b.cost_price,
                notes: b.notes,
                batch_number: b.batchNumber,
                expiry_date: b.expiryDate,
            },
        });
    });

    app.post('/api/stock/adjust', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
        const b = req.body || {};
        return proxyJson(req, res, {
            path: '/stock/adjust',
            method: 'POST',
            body: {
                product_id: b.productId ?? b.product_id,
                quantity: b.actualQuantity ?? b.quantity,
                notes: b.notes || b.reason,
            },
        });
    });
}

module.exports = {
    enabled,
    LARAVEL_URL,
    mountLaravelSot,
    mapLaravelUserToSession,
    laravelFetch,
    unwrapData,
    adaptSale,
    adaptSettings,
    renderSaleReceiptHtml,
};
