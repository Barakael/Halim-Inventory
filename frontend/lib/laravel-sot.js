/**
 * Laravel MySQL single-source-of-truth bridge.
 * Express keeps cookie sessions; core inventory/sales go to Laravel Sanctum API.
 */
const LARAVEL_URL = (process.env.LARAVEL_URL || 'http://127.0.0.1:8000').replace(/\/$/, '');

function enabled() {
    return process.env.LARAVEL_SOT !== '0' && Boolean(LARAVEL_URL);
}

async function laravelFetch(path, { method = 'GET', token, body, headers = {} } = {}) {
    const url = `${LARAVEL_URL}/api${path.startsWith('/') ? path : `/${path}`}`;
    const opts = {
        method,
        headers: {
            Accept: 'application/json',
            ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
            ...headers,
        },
    };
    if (body !== undefined) {
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
        id: p.id,
        name: p.name,
        description: p.description || '',
        categoryId: p.category_id,
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

function adaptSale(s) {
    if (!s || typeof s !== 'object') return s;
    return {
        id: s.id,
        receiptNumber: s.serial_number,
        serial_number: s.serial_number,
        paymentMethod: s.payment_method,
        payment_method: s.payment_method,
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
    return {
        id: c.id,
        name: c.name,
        email: c.email,
        phone: c.phone,
        address: c.address,
        notes: c.notes,
        status: c.is_active === false ? 'inactive' : 'active',
        openDebtBalance: c.open_debt_balance,
        purchaseCount: c.purchase_count,
        totalSpent: c.total_spent,
        shop_id: c.shop_id,
    };
}

function adaptCategory(c) {
    if (!c || typeof c !== 'object') return c;
    return {
        id: c.id,
        name: c.name,
        parentId: c.parent_id,
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
        status: 'active',
    };
}

function adaptPurchase(p) {
    if (!p || typeof p !== 'object') return p;
    return {
        id: p.id,
        status: p.status,
        supplierId: p.supplier_id,
        supplierName: p.supplier_name || (p.supplier && p.supplier.name) || null,
        reference: p.reference,
        invoiceNumber: p.reference,
        notes: p.notes,
        totalAmount: p.subtotal,
        subtotal: p.subtotal,
        purchasedAt: p.purchased_at,
        receivedAt: p.received_at,
        createdAt: p.purchased_at || p.received_at,
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
        id: u.id,
        username: u.email ? String(u.email).split('@')[0] : String(u.id),
        fullName: u.name,
        email: u.email,
        phone: u.phone,
        role: u.role === 'owner' ? 'admin' : u.role,
        branchId: u.branch_id,
        branchName: u.branch_name || (u.branch && u.branch.name) || null,
        status: 'active',
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
    return {
        companyName: shop.name,
        address: shop.address,
        phone: shop.phone,
        email: shop.email,
        taxRate: shop.tax_rate,
        currency: shop.currency,
        tin: shop.tin,
        vrn: shop.vrn,
        mobile: shop.mobile,
        location: shop.location,
        taxOffice: shop.tax_office,
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

    app.get('/api/dashboard/stats', isAuthenticated, async (req, res) => {
        const token = requireLaravelToken(req, res);
        if (!token) return;
        try {
            const { ok, json, status } = await laravelFetch('/dashboard', { token });
            if (!ok) {
                return res.status(status).json({ success: false, message: json?.message || 'Failed' });
            }
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
                    customers: { total: 0 },
                    debts: { total: 0, count: 0, collected: 0 },
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

    app.get('/api/suppliers', isAuthenticated, (req, res) =>
        proxyJson(req, res, { path: '/suppliers', adapt: adaptSupplier }));

    app.get('/api/purchases', isAuthenticated, (req, res) => {
        const q = new URLSearchParams();
        if (req.query.startDate) q.set('from', req.query.startDate);
        if (req.query.endDate) q.set('to', req.query.endDate);
        if (req.query.supplierId) q.set('supplier_id', req.query.supplierId);
        const qs = q.toString() ? `?${q}` : '';
        return proxyJson(req, res, { path: `/purchases${qs}`, adapt: adaptPurchase });
    });

    app.get('/api/purchases/:id', isAuthenticated, (req, res) =>
        proxyJson(req, res, { path: `/purchases/${req.params.id}`, adapt: adaptPurchase }));

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
        const body = {
            items,
            payment_method: b.paymentMethod || b.payment_method || 'cash',
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

    app.post('/api/purchases', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
        const b = req.body || {};
        const items = (b.items || []).map((it) => ({
            product_id: it.productId ?? it.product_id,
            quantity: it.quantity,
            unit_cost: it.costPrice ?? it.unit_cost ?? it.unitCost,
        }));
        return proxyJson(req, res, {
            path: '/purchases',
            method: 'POST',
            body: {
                supplier_id: b.supplierId ?? b.supplier_id,
                reference: b.invoiceNumber ?? b.reference,
                notes: b.notes,
                purchased_at: b.purchasedAt || new Date().toISOString().slice(0, 10),
                receive_now: true,
                items,
            },
            adapt: adaptPurchase,
            successStatus: 201,
        });
    });

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
                email: b.email || `${b.username}@local.test`,
                password: b.password,
                branch_id: b.branchId ?? b.branch_id,
                phone: b.phone,
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
            email: b.email,
            phone: b.phone,
            branch_id: b.branchId ?? b.branch_id,
            role: b.role === 'admin' ? 'owner' : b.role,
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
};
