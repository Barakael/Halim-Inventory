/**
 * HASLIM GROUP LIMITED - Inventory Management System
 * Comprehensive system for wholesale food & beverage store
 * Port: 40000
 */

require('dotenv').config();
const express = require('express');
const session = require('express-session');
const FileStore = require('session-file-store')(session);
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const moment = require('moment');
const QRCode = require('qrcode');
const bwipjs = require('bwip-js');
const PDFDocument = require('pdfkit');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const os = require('os');

const app = express();
const PORT = 40000;

// Trust proxy for external access
app.set('trust proxy', 1);

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Favicon handler
app.get('/favicon.ico', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'favicon.svg'));
});

// Create sessions directory
const sessionsDir = path.join(__dirname, 'sessions');
if (!fs.existsSync(sessionsDir)) {
    fs.mkdirSync(sessionsDir, { recursive: true });
}

// Session configuration with file store (persists across restarts)
app.use(session({
    store: new FileStore({
        path: sessionsDir,
        ttl: 86400, // 24 hours
        reapInterval: 3600 // Clean up expired sessions every hour
    }),
    secret: process.env.SESSION_SECRET || 'haslim-dev-secret-change-in-production',
    resave: false,
    saveUninitialized: false,
    cookie: { 
        secure: process.env.NODE_ENV === 'production',
        httpOnly: true,
        maxAge: 24 * 60 * 60 * 1000, // 24 hours
        sameSite: 'lax'
    }
}));

// Create necessary directories
const directories = ['data', 'public', 'public/css', 'public/js', 'uploads', 'backups', 'receipts'];
directories.forEach(dir => {
    const fullPath = path.join(__dirname, dir);
    if (!fs.existsSync(fullPath)) {
        fs.mkdirSync(fullPath, { recursive: true });
    }
});

// Database file paths
const DB_PATH = path.join(__dirname, 'data');
const dbFiles = {
    users: path.join(DB_PATH, 'users.json'),
    products: path.join(DB_PATH, 'products.json'),
    categories: path.join(DB_PATH, 'categories.json'),
    stock: path.join(DB_PATH, 'stock.json'),
    sales: path.join(DB_PATH, 'sales.json'),
    purchases: path.join(DB_PATH, 'purchases.json'),
    suppliers: path.join(DB_PATH, 'suppliers.json'),
    customers: path.join(DB_PATH, 'customers.json'),
    expenses: path.join(DB_PATH, 'expenses.json'),
    payments: path.join(DB_PATH, 'payments.json'),
    branches: path.join(DB_PATH, 'branches.json'),
    activityLogs: path.join(DB_PATH, 'activity_logs.json'),
    settings: path.join(DB_PATH, 'settings.json'),
    notifications: path.join(DB_PATH, 'notifications.json'),
    stockTransfers: path.join(DB_PATH, 'stock_transfers.json'),
    creditSales: path.join(DB_PATH, 'credit_sales.json'),
    supplierPayments: path.join(DB_PATH, 'supplier_payments.json')
};

// Initialize database files with default data
function initializeDatabase() {
    // Default admin user
    const defaultUsers = [{
        id: uuidv4(),
        username: 'admin',
        password: bcrypt.hashSync('admin123', 10),
        fullName: 'System Administrator',
        email: 'admin@dukajumla.co.tz',
        phone: '+255712345678',
        role: 'admin',
        branchId: 'main',
        status: 'active',
        createdAt: new Date().toISOString(),
        lastLogin: null
    }];

    // Default categories
    const defaultCategories = [
        { id: uuidv4(), name: 'Vinywaji (Beverages)', description: 'Soda, juisi, maji', status: 'active' },
        { id: uuidv4(), name: 'Nafaka (Grains)', description: 'Mchele, unga, mahindi', status: 'active' },
        { id: uuidv4(), name: 'Mafuta (Oils)', description: 'Mafuta ya kupikia', status: 'active' },
        { id: uuidv4(), name: 'Sukari (Sugar)', description: 'Sukari na asali', status: 'active' },
        { id: uuidv4(), name: 'Chumvi na Viungo', description: 'Chumvi, pilipili, viungo', status: 'active' },
        { id: uuidv4(), name: 'Maziwa (Dairy)', description: 'Maziwa na bidhaa zake', status: 'active' },
        { id: uuidv4(), name: 'Vyakula vya Makopo', description: 'Samaki, nyama, mboga za makopo', status: 'active' },
        { id: uuidv4(), name: 'Biskuti na Snacks', description: 'Biskuti, chips, karanga', status: 'active' }
    ];

    // Default branch
    const defaultBranches = [{
        id: 'main',
        name: 'Tawi Kuu (Main Branch)',
        address: 'Dar es Salaam, Tanzania',
        phone: '+255712345678',
        email: 'main@dukajumla.co.tz',
        status: 'active',
        createdAt: new Date().toISOString()
    }];

    // Default settings
    const defaultSettings = {
        companyName: 'HASLIM GROUP LIMITED',
        companyAddress: 'Dar es Salaam, Tanzania',
        companyPhone: '+255712345678',
        companyEmail: 'info@haslimgroup.co.tz',
        currency: 'TZS',
        lowStockThreshold: 10,
        expiryAlertDays: 30,
        loanLimitAlertDays: 7,
        taxRate: 18,
        receiptFooter: 'Asante kwa kununua! Karibu tena.',
        autoBackup: true,
        backupTime: '23:00',
        paymentMethods: ['cash', 'bank', 'mpesa', 'airtel', 'tigo', 'halopesa']
    };

    // Initialize files if they don't exist
    const defaults = {
        users: defaultUsers,
        categories: defaultCategories,
        branches: defaultBranches,
        settings: defaultSettings,
        products: [],
        stock: [],
        sales: [],
        purchases: [],
        suppliers: [],
        customers: [],
        expenses: [],
        payments: [],
        activityLogs: [],
        notifications: [],
        stockTransfers: [],
        creditSales: [],
        supplierPayments: []
    };

    Object.keys(dbFiles).forEach(key => {
        if (!fs.existsSync(dbFiles[key])) {
            fs.writeFileSync(dbFiles[key], JSON.stringify(defaults[key] || [], null, 2));
        }
    });
}

// ==================== IN-MEMORY CACHE ====================
const dbCache = new Map();

function preloadCache() {
    Object.values(dbFiles).forEach(file => {
        if (fs.existsSync(file)) {
            try {
                dbCache.set(file, JSON.parse(fs.readFileSync(file, 'utf8')));
            } catch (e) {
                dbCache.set(file, []);
            }
        }
    });
    console.log('✅ Database loaded into memory cache.');
}

// Database helper functions
function readDB(file) {
    if (dbCache.has(file)) return dbCache.get(file);
    try {
        const data = JSON.parse(fs.readFileSync(file, 'utf8'));
        dbCache.set(file, data);
        return data;
    } catch (error) {
        console.error(`Error reading ${file}:`, error);
        return [];
    }
}

function writeDB(file, data) {
    dbCache.set(file, data); // Update in-memory cache immediately
    try {
        const tempFile = file + '.tmp';
        fs.writeFileSync(tempFile, JSON.stringify(data), 'utf8'); // No pretty-print for speed
        fs.renameSync(tempFile, file);
        return true;
    } catch (error) {
        const tempFile = file + '.tmp';
        if (fs.existsSync(tempFile)) {
            try { fs.unlinkSync(tempFile); } catch (e) {}
        }
        if (error.code === 'ENOSPC') {
            console.error(`❌ DISK FULL: Cannot write to ${file}. Please free up disk space!`);
        } else {
            console.error(`Error writing ${file}:`, error);
        }
        return false;
    }
}

// Activity logging
function logActivity(userId, action, details, ipAddress) {
    const logs = readDB(dbFiles.activityLogs);
    const entry = {
        id: uuidv4(),
        userId,
        action,
        details,
        ipAddress,
        timestamp: new Date().toISOString()
    };
    logs.push(entry);
    // Trim log to last 2000 entries to prevent unbounded growth
    if (logs.length > 2000) logs.splice(0, logs.length - 2000);
    writeDB(dbFiles.activityLogs, logs);
    
    // Also print to terminal for live monitoring
    console.log(
        `[ACTIVITY] ${entry.timestamp} | user=${entry.userId || 'SYSTEM'} | ` +
        `${entry.action} | ${entry.details} | ip=${entry.ipAddress || 'N/A'}`
    );
}

// Notification helper
function createNotification(type, title, message, targetRole = 'all', branchId = 'all') {
    const notifications = readDB(dbFiles.notifications);
    notifications.push({
        id: uuidv4(),
        type,
        title,
        message,
        targetRole,
        branchId,
        read: false,
        createdAt: new Date().toISOString()
    });
    writeDB(dbFiles.notifications, notifications);
}

// Check for low stock and expiry alerts
function checkAlerts() {
    const products = readDB(dbFiles.products);
    const stock = readDB(dbFiles.stock);
    const settings = readDB(dbFiles.settings);
    
    products.forEach(product => {
        const productStock = stock.filter(s => s.productId === product.id);
        const totalQty = productStock.reduce((sum, s) => sum + s.quantity, 0);
        
        // Low stock alert
        if (totalQty <= (product.minStock || settings.lowStockThreshold)) {
            createNotification('low_stock', 'Low Stock Alert', 
                `${product.name} ina stock chini (${totalQty} ${product.unit}). Tafadhali agiza zaidi.`,
                'storekeeper');
        }
        
        // Expiry alert
        productStock.forEach(s => {
            if (s.expiryDate) {
                const daysToExpiry = moment(s.expiryDate).diff(moment(), 'days');
                if (daysToExpiry <= settings.expiryAlertDays && daysToExpiry > 0) {
                    createNotification('expiry', 'Expiry Alert',
                        `${product.name} (Batch: ${s.batchNumber}) itaisha muda tarehe ${moment(s.expiryDate).format('DD/MM/YYYY')}`,
                        'storekeeper');
                }
            }
        });
    });
}

// Authentication middleware
function isAuthenticated(req, res, next) {
    console.log(`Auth check - Session ID: ${req.sessionID}, Has user: ${!!req.session?.user}`);
    
    if (req.session && req.session.user) {
        return next();
    }
    
    console.log('User not authenticated');
    
    if (req.xhr || req.headers.accept?.includes('application/json')) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
    }
    res.redirect('/login');
}

function hasRole(...roles) {
    return (req, res, next) => {
        if (req.session && req.session.user && roles.includes(req.session.user.role)) {
            return next();
        }
        if (req.xhr || req.headers.accept?.includes('application/json')) {
            return res.status(403).json({ success: false, message: 'Access denied' });
        }
        res.redirect('/dashboard');
    };
}

// Initialize database
initializeDatabase();
preloadCache(); // Load all data into memory for fast reads

// ==================== ROUTES ====================

// Serve Bootstrap and Bootstrap Icons locally (no CDN dependency)
app.use('/vendor/bootstrap', express.static(path.join(__dirname, 'node_modules/bootstrap/dist')));
app.use('/vendor/bootstrap-icons', express.static(path.join(__dirname, 'node_modules/bootstrap-icons/font')));

// Serve main pages
app.get('/', (req, res) => {
    if (req.session.user) {
        return res.redirect('/dashboard');
    }
    res.redirect('/login');
});

app.get('/login', (req, res) => {
    if (req.session.user) {
        return res.redirect('/dashboard');
    }
    res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

// All authenticated routes serve the same dashboard but JS will handle the page
const dashboardRoutes = [
    '/dashboard',
    '/pos',
    '/products',
    '/categories',
    '/stock',
    '/sales',
    '/purchases',
    '/suppliers',
    '/customers',
    '/credits',
    '/expenses',
    '/reports',
    '/branches',
    '/users',
    '/logs',
    '/settings',
    '/docs'
];

dashboardRoutes.forEach(route => {
    app.get(route, isAuthenticated, (req, res) => {
        res.sendFile(path.join(__dirname, 'public', 'dashboard.html'));
    });
});

// API: Authentication
app.post('/api/auth/login', (req, res) => {
    const { username, password } = req.body;
    console.log(`Login attempt for user: ${username}`);
    
    const users = readDB(dbFiles.users);
    
    const user = users.find(u => u.username === username && u.status === 'active');
    
    if (!user || !bcrypt.compareSync(password, user.password)) {
        console.log(`Login failed for: ${username}`);
        logActivity(null, 'LOGIN_FAILED', `Failed login attempt for: ${username}`, req.ip);
        return res.json({ success: false, message: 'Jina la mtumiaji au nenosiri si sahihi' });
    }
    
    // Update last login
    user.lastLogin = new Date().toISOString();
    writeDB(dbFiles.users, users);
    
    // Set session
    req.session.user = {
        id: user.id,
        username: user.username,
        fullName: user.fullName,
        role: user.role,
        branchId: user.branchId
    };
    
    // Save session explicitly
    req.session.save((err) => {
        if (err) {
            console.error('Session save error:', err);
            return res.json({ success: false, message: 'Session error' });
        }
        
        console.log(`Login successful for: ${username}, Session ID: ${req.sessionID}`);
        logActivity(user.id, 'LOGIN', 'User logged in successfully', req.ip);
        
        res.json({ 
            success: true, 
            message: 'Umefanikiwa kuingia',
            user: req.session.user
        });
    });
});

app.post('/api/auth/logout', isAuthenticated, (req, res) => {
    logActivity(req.session.user.id, 'LOGOUT', 'User logged out', req.ip);
    req.session.destroy();
    res.json({ success: true, message: 'Umetoka kwenye mfumo' });
});

app.get('/api/auth/me', isAuthenticated, (req, res) => {
    res.json({ success: true, user: req.session.user });
});

// API: Users
app.get('/api/users', isAuthenticated, hasRole('admin'), (req, res) => {
    const users = readDB(dbFiles.users).map(u => ({
        ...u,
        password: undefined
    }));
    res.json({ success: true, data: users });
});

app.post('/api/users', isAuthenticated, hasRole('admin'), async (req, res) => {
    const { username, password, fullName, email, phone, role, branchId } = req.body;
    const users = readDB(dbFiles.users);
    
    if (users.find(u => u.username === username)) {
        return res.json({ success: false, message: 'Jina la mtumiaji tayari lipo' });
    }
    
    const newUser = {
        id: uuidv4(),
        username,
        password: bcrypt.hashSync(password, 10),
        fullName,
        email,
        phone,
        role,
        branchId,
        status: 'active',
        createdAt: new Date().toISOString(),
        lastLogin: null
    };
    
    users.push(newUser);
    writeDB(dbFiles.users, users);
    
    logActivity(req.session.user.id, 'CREATE_USER', `Created user: ${username}`, req.ip);
    
    res.json({ success: true, message: 'Mtumiaji ameongezwa', data: { ...newUser, password: undefined } });
});

app.put('/api/users/:id', isAuthenticated, hasRole('admin'), (req, res) => {
    const { id } = req.params;
    const { fullName, email, phone, role, branchId, status, password } = req.body;
    const users = readDB(dbFiles.users);
    
    const userIndex = users.findIndex(u => u.id === id);
    if (userIndex === -1) {
        return res.json({ success: false, message: 'Mtumiaji hapatikani' });
    }
    
    users[userIndex] = {
        ...users[userIndex],
        fullName: fullName || users[userIndex].fullName,
        email: email || users[userIndex].email,
        phone: phone || users[userIndex].phone,
        role: role || users[userIndex].role,
        branchId: branchId || users[userIndex].branchId,
        status: status || users[userIndex].status,
        updatedAt: new Date().toISOString()
    };
    
    if (password) {
        users[userIndex].password = bcrypt.hashSync(password, 10);
    }
    
    writeDB(dbFiles.users, users);
    logActivity(req.session.user.id, 'UPDATE_USER', `Updated user: ${users[userIndex].username}`, req.ip);
    
    res.json({ success: true, message: 'Mtumiaji ameboreshwa' });
});

app.delete('/api/users/:id', isAuthenticated, hasRole('admin'), (req, res) => {
    const { id } = req.params;
    const { adminPassword } = req.body; // Get password from request body
    
    if (!adminPassword) {
        return res.json({ success: false, message: 'Nenosiri la admin linahitajika' });
    }
    
    let users = readDB(dbFiles.users);
    
    // Verify admin password
    const adminUser = users.find(u => u.id === req.session.user.id && u.role === 'admin');
    if (!adminUser || !bcrypt.compareSync(adminPassword, adminUser.password)) {
        logActivity(req.session.user.id, 'DELETE_USER_FAILED', 'Failed to delete user - invalid password', req.ip);
        return res.json({ success: false, message: 'Nenosiri la admin si sahihi' });
    }
    
    const user = users.find(u => u.id === id);
    if (!user) {
        return res.json({ success: false, message: 'Mtumiaji hapatikani' });
    }
    
    if (user.username === 'admin') {
        return res.json({ success: false, message: 'Huwezi kufuta admin mkuu' });
    }
    
    users = users.filter(u => u.id !== id);
    writeDB(dbFiles.users, users);
    
    logActivity(req.session.user.id, 'DELETE_USER', `Deleted user: ${user.username}`, req.ip);
    
    res.json({ success: true, message: 'Mtumiaji amefutwa' });
});

// API: Categories
app.get('/api/categories', isAuthenticated, (req, res) => {
    const categories = readDB(dbFiles.categories);
    res.json({ success: true, data: categories });
});

app.post('/api/categories', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
    const { name, description } = req.body;
    const categories = readDB(dbFiles.categories);
    
    if (categories.find(c => c.name.toLowerCase() === name.toLowerCase())) {
        return res.json({ success: false, message: 'Kategoria tayari ipo' });
    }
    
    const newCategory = {
        id: uuidv4(),
        name,
        description,
        status: 'active',
        createdAt: new Date().toISOString()
    };
    
    categories.push(newCategory);
    writeDB(dbFiles.categories, categories);
    
    logActivity(req.session.user.id, 'CREATE_CATEGORY', `Created category: ${name}`, req.ip);
    
    res.json({ success: true, message: 'Kategoria imeongezwa', data: newCategory });
});

app.put('/api/categories/:id', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
    const { id } = req.params;
    const { name, description, status } = req.body;
    const categories = readDB(dbFiles.categories);
    
    const catIndex = categories.findIndex(c => c.id === id);
    if (catIndex === -1) {
        return res.json({ success: false, message: 'Kategoria haipo' });
    }
    
    categories[catIndex] = {
        ...categories[catIndex],
        name: name || categories[catIndex].name,
        description: description || categories[catIndex].description,
        status: status || categories[catIndex].status,
        updatedAt: new Date().toISOString()
    };
    
    writeDB(dbFiles.categories, categories);
    res.json({ success: true, message: 'Kategoria imeboreshwa' });
});

app.delete('/api/categories/:id', isAuthenticated, hasRole('admin'), (req, res) => {
    const { id } = req.params;
    let categories = readDB(dbFiles.categories);
    const products = readDB(dbFiles.products);
    
    // Check if category has products
    if (products.some(p => p.categoryId === id)) {
        return res.json({ success: false, message: 'Kategoria ina bidhaa, ondoa bidhaa kwanza' });
    }
    
    categories = categories.filter(c => c.id !== id);
    writeDB(dbFiles.categories, categories);
    
    res.json({ success: true, message: 'Kategoria imefutwa' });
});

// API: Products
app.get('/api/products', isAuthenticated, (req, res) => {
    const products = readDB(dbFiles.products);
    const categories = readDB(dbFiles.categories);
    const stock = readDB(dbFiles.stock);
    
    const enrichedProducts = products.map(p => {
        const category = categories.find(c => c.id === p.categoryId);
        const productStock = stock.filter(s => s.productId === p.id);
        const totalQty = productStock.reduce((sum, s) => sum + s.quantity, 0);
        
        return {
            ...p,
            categoryName: category ? category.name : 'N/A',
            currentStock: totalQty,
            stockDetails: productStock
        };
    });
    
    res.json({ success: true, data: enrichedProducts });
});

app.post('/api/products', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
    const { name, categoryId, sku, barcode, wholesalePrice, retailPrice, unit, minStock, supplierId, description } = req.body;
    const products = readDB(dbFiles.products);
    
    if (products.find(p => p.sku === sku)) {
        return res.json({ success: false, message: 'SKU tayari ipo' });
    }
    
    const newProduct = {
        id: uuidv4(),
        name,
        categoryId,
        sku: sku || `SKU-${Date.now()}`,
        barcode: barcode || `BAR-${Date.now()}`,
        wholesalePrice: parseFloat(wholesalePrice) || 0,
        retailPrice: parseFloat(retailPrice) || 0,
        unit: unit || 'pcs',
        minStock: parseInt(minStock) || 10,
        supplierId,
        description,
        status: 'active',
        createdAt: new Date().toISOString()
    };
    
    products.push(newProduct);
    writeDB(dbFiles.products, products);
    
    logActivity(req.session.user.id, 'CREATE_PRODUCT', `Created product: ${name}`, req.ip);
    
    res.json({ success: true, message: 'Bidhaa imeongezwa', data: newProduct });
});

app.put('/api/products/:id', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
    const { id } = req.params;
    const updates = req.body;
    const products = readDB(dbFiles.products);
    
    const prodIndex = products.findIndex(p => p.id === id);
    if (prodIndex === -1) {
        return res.json({ success: false, message: 'Bidhaa haipo' });
    }
    
    products[prodIndex] = {
        ...products[prodIndex],
        ...updates,
        wholesalePrice: parseFloat(updates.wholesalePrice) || products[prodIndex].wholesalePrice,
        retailPrice: parseFloat(updates.retailPrice) || products[prodIndex].retailPrice,
        minStock: parseInt(updates.minStock) || products[prodIndex].minStock,
        updatedAt: new Date().toISOString()
    };
    
    writeDB(dbFiles.products, products);
    logActivity(req.session.user.id, 'UPDATE_PRODUCT', `Updated product: ${products[prodIndex].name}`, req.ip);
    
    res.json({ success: true, message: 'Bidhaa imeboreshwa' });
});

app.delete('/api/products/:id', isAuthenticated, hasRole('admin'), (req, res) => {
    const { id } = req.params;
    let products = readDB(dbFiles.products);
    
    const product = products.find(p => p.id === id);
    if (!product) {
        return res.json({ success: false, message: 'Bidhaa haipo' });
    }
    
    products = products.filter(p => p.id !== id);
    writeDB(dbFiles.products, products);
    
    // Also remove stock entries
    let stock = readDB(dbFiles.stock);
    stock = stock.filter(s => s.productId !== id);
    writeDB(dbFiles.stock, stock);
    
    logActivity(req.session.user.id, 'DELETE_PRODUCT', `Deleted product: ${product.name}`, req.ip);
    
    res.json({ success: true, message: 'Bidhaa imefutwa' });
});

// API: Stock Management
app.get('/api/stock', isAuthenticated, (req, res) => {
    const stock = readDB(dbFiles.stock);
    const products = readDB(dbFiles.products);
    
    const enrichedStock = stock.map(s => {
        const product = products.find(p => p.id === s.productId);
        return {
            ...s,
            productName: product ? product.name : 'N/A',
            unit: product ? product.unit : 'N/A'
        };
    });
    
    res.json({ success: true, data: enrichedStock });
});

app.post('/api/stock/in', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
    const { productId, quantity, batchNumber, expiryDate, costPrice, branchId, purchaseId, notes } = req.body;
    const stock = readDB(dbFiles.stock);
    const products = readDB(dbFiles.products);
    
    const product = products.find(p => p.id === productId);
    if (!product) {
        return res.json({ success: false, message: 'Bidhaa haipo' });
    }
    
    const newStock = {
        id: uuidv4(),
        productId,
        quantity: parseInt(quantity),
        batchNumber: batchNumber || `BATCH-${Date.now()}`,
        expiryDate: expiryDate || null,
        costPrice: parseFloat(costPrice) || 0,
        branchId: branchId || req.session.user.branchId,
        purchaseId: purchaseId || null,
        notes,
        type: 'in',
        createdBy: req.session.user.id,
        createdAt: new Date().toISOString()
    };
    
    stock.push(newStock);
    writeDB(dbFiles.stock, stock);
    
    logActivity(req.session.user.id, 'STOCK_IN', `Added stock: ${quantity} ${product.unit} of ${product.name}`, req.ip);
    
    res.json({ success: true, message: 'Stock imeongezwa', data: newStock });
});

app.post('/api/stock/out', isAuthenticated, hasRole('admin', 'storekeeper', 'cashier'), (req, res) => {
    const { productId, quantity, branchId, reason, notes } = req.body;
    const stock = readDB(dbFiles.stock);
    const products = readDB(dbFiles.products);
    
    const product = products.find(p => p.id === productId);
    if (!product) {
        return res.json({ success: false, message: 'Bidhaa haipo' });
    }
    
    // Calculate available stock
    const productStock = stock.filter(s => s.productId === productId && s.branchId === (branchId || req.session.user.branchId));
    const totalQty = productStock.reduce((sum, s) => sum + s.quantity, 0);
    
    if (totalQty < quantity) {
        return res.json({ success: false, message: `Stock haitoshi. Ipo: ${totalQty} ${product.unit}` });
    }
    
    // Deduct from stock using FIFO (First In First Out)
    let remaining = parseInt(quantity);
    productStock.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
    
    for (let s of productStock) {
        if (remaining <= 0) break;
        
        const stockIndex = stock.findIndex(st => st.id === s.id);
        if (s.quantity <= remaining) {
            remaining -= s.quantity;
            stock.splice(stockIndex, 1);
        } else {
            stock[stockIndex].quantity -= remaining;
            remaining = 0;
        }
    }
    
    // Record the stock out
    stock.push({
        id: uuidv4(),
        productId,
        quantity: -parseInt(quantity),
        branchId: branchId || req.session.user.branchId,
        reason,
        notes,
        type: 'out',
        createdBy: req.session.user.id,
        createdAt: new Date().toISOString()
    });
    
    writeDB(dbFiles.stock, stock);
    
    logActivity(req.session.user.id, 'STOCK_OUT', `Removed stock: ${quantity} ${product.unit} of ${product.name}`, req.ip);
    
    res.json({ success: true, message: 'Stock imetolewa' });
});

app.post('/api/stock/adjust', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
    const { productId, actualQuantity, branchId, reason } = req.body;
    const stock = readDB(dbFiles.stock);
    const products = readDB(dbFiles.products);
    
    const product = products.find(p => p.id === productId);
    if (!product) {
        return res.json({ success: false, message: 'Bidhaa haipo' });
    }
    
    const targetBranch = branchId || req.session.user.branchId;
    const productStock = stock.filter(s => s.productId === productId && s.branchId === targetBranch && s.type === 'in');
    const currentQty = productStock.reduce((sum, s) => sum + s.quantity, 0);
    const difference = parseInt(actualQuantity) - currentQty;
    
    if (difference !== 0) {
        stock.push({
            id: uuidv4(),
            productId,
            quantity: difference,
            branchId: targetBranch,
            reason: reason || 'Stock adjustment',
            type: 'adjustment',
            previousQty: currentQty,
            newQty: parseInt(actualQuantity),
            createdBy: req.session.user.id,
            createdAt: new Date().toISOString()
        });
        
        writeDB(dbFiles.stock, stock);
        logActivity(req.session.user.id, 'STOCK_ADJUST', `Adjusted stock for ${product.name}: ${currentQty} -> ${actualQuantity}`, req.ip);
    }
    
    res.json({ success: true, message: 'Stock imesahihishwa', difference });
});

// API: Suppliers
app.get('/api/suppliers', isAuthenticated, (req, res) => {
    const suppliers = readDB(dbFiles.suppliers);
    res.json({ success: true, data: suppliers });
});

app.post('/api/suppliers', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
    const { name, contactPerson, phone, email, address, taxId } = req.body;
    const suppliers = readDB(dbFiles.suppliers);
    
    const newSupplier = {
        id: uuidv4(),
        name,
        contactPerson,
        phone,
        email,
        address,
        taxId,
        status: 'active',
        createdAt: new Date().toISOString()
    };
    
    suppliers.push(newSupplier);
    writeDB(dbFiles.suppliers, suppliers);
    
    logActivity(req.session.user.id, 'CREATE_SUPPLIER', `Created supplier: ${name}`, req.ip);
    
    res.json({ success: true, message: 'Msambazaji ameongezwa', data: newSupplier });
});

app.put('/api/suppliers/:id', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
    const { id } = req.params;
    const updates = req.body;
    const suppliers = readDB(dbFiles.suppliers);
    
    const supIndex = suppliers.findIndex(s => s.id === id);
    if (supIndex === -1) {
        return res.json({ success: false, message: 'Msambazaji hapo' });
    }
    
    suppliers[supIndex] = {
        ...suppliers[supIndex],
        ...updates,
        updatedAt: new Date().toISOString()
    };
    
    writeDB(dbFiles.suppliers, suppliers);
    res.json({ success: true, message: 'Msambazaji ameboreshwa' });
});

app.delete('/api/suppliers/:id', isAuthenticated, hasRole('admin'), (req, res) => {
    const { id } = req.params;
    const { adminPassword } = req.body; // Get password from request body
    
    if (!adminPassword) {
        return res.json({ success: false, message: 'Nenosiri la admin linahitajika' });
    }
    
    const users = readDB(dbFiles.users);
    let suppliers = readDB(dbFiles.suppliers);
    
    // Verify admin password
    const adminUser = users.find(u => u.id === req.session.user.id && u.role === 'admin');
    if (!adminUser || !bcrypt.compareSync(adminPassword, adminUser.password)) {
        logActivity(req.session.user.id, 'DELETE_SUPPLIER_FAILED', 'Failed to delete supplier - invalid password', req.ip);
        return res.json({ success: false, message: 'Nenosiri la admin si sahihi' });
    }
    
    const supplier = suppliers.find(s => s.id === id);
    if (!supplier) {
        return res.json({ success: false, message: 'Msambazaji hapatikani' });
    }
    
    suppliers = suppliers.filter(s => s.id !== id);
    writeDB(dbFiles.suppliers, suppliers);
    
    logActivity(req.session.user.id, 'DELETE_SUPPLIER', `Deleted supplier: ${supplier.name}`, req.ip);
    
    res.json({ success: true, message: 'Msambazaji amefutwa' });
});

// API: Purchases
app.get('/api/purchases', isAuthenticated, (req, res) => {
    const { supplierId, startDate, endDate, page, limit } = req.query;
    let purchases = readDB(dbFiles.purchases);
    const suppliers = readDB(dbFiles.suppliers);
    const products = readDB(dbFiles.products);
    
    // Filter by supplier if provided
    if (supplierId) {
        purchases = purchases.filter(p => p.supplierId === supplierId);
    }
    
    // Filter by date range if provided
    if (startDate && endDate) {
        const start = moment(startDate).startOf('day');
        const end = moment(endDate).endOf('day');
        purchases = purchases.filter(p => moment(p.createdAt).isBetween(start, end, null, '[]'));
    }
    
    const enrichedPurchases = purchases.map(p => {
        const supplier = suppliers.find(s => s.id === p.supplierId);
        // Enrich items with product names
        const enrichedItems = p.items.map(item => {
            const product = products.find(pr => pr.id === item.productId);
            return {
                ...item,
                productName: product ? product.name : 'N/A',
                productUnit: product ? product.unit : 'pcs'
            };
        });
        
        return {
            ...p,
            supplierName: supplier ? supplier.name : 'N/A',
            items: enrichedItems
        };
    });

    // Sort newest first
    enrichedPurchases.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    // Pagination
    const pageNum = parseInt(page) || 0;
    if (pageNum > 0) {
        const limitNum = Math.min(parseInt(limit) || 50, 200);
        const total = enrichedPurchases.length;
        const paginated = enrichedPurchases.slice((pageNum - 1) * limitNum, pageNum * limitNum);
        return res.json({ success: true, data: paginated, total, page: pageNum, limit: limitNum, pages: Math.ceil(total / limitNum) });
    }

    res.json({ success: true, data: enrichedPurchases });
});

// API: Get single purchase details
app.get('/api/purchases/:id', isAuthenticated, (req, res) => {
    const { id } = req.params;
    const purchases = readDB(dbFiles.purchases);
    const suppliers = readDB(dbFiles.suppliers);
    const products = readDB(dbFiles.products);
    const supplierPayments = readDB(dbFiles.supplierPayments);
    
    const purchase = purchases.find(p => p.id === id);
    if (!purchase) {
        return res.json({ success: false, message: 'Purchase hapatikani' });
    }
    
    const supplier = suppliers.find(s => s.id === purchase.supplierId);
    
    // Enrich items with product names
    const enrichedItems = purchase.items.map(item => {
        const product = products.find(pr => pr.id === item.productId);
        return {
            ...item,
            productName: product ? product.name : 'N/A',
            productUnit: product ? product.unit : 'pcs'
        };
    });
    
    // Get payment history if it's a credit purchase
    let paymentHistory = [];
    let totalPaid = 0;
    let remainingBalance = 0;
    
    if (purchase.paymentType === 'credit') {
        paymentHistory = supplierPayments
            .filter(sp => sp.supplierId === purchase.supplierId && sp.type === 'payment')
            .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
        
        // Get all credit purchases for this supplier, sorted by date (FIFO)
        const allPurchases = readDB(dbFiles.purchases);
        const supplierCreditPurchases = allPurchases
            .filter(p => p.supplierId === purchase.supplierId && p.paymentType === 'credit')
            .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
        
        // Get all payments sorted by date
        const allPayments = supplierPayments
            .filter(sp => sp.supplierId === purchase.supplierId && sp.type === 'payment')
            .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
        
        // Apply FIFO to calculate how much was paid for this specific purchase
        let cumulativeDebt = 0;
        
        for (const p of supplierCreditPurchases) {
            if (p.id === purchase.id) {
                // This is the purchase we're calculating for
                const debtBeforeThis = cumulativeDebt;
                const totalPayments = allPayments.reduce((sum, pay) => sum + pay.amount, 0);
                
                // Calculate how much has been paid towards debts before this purchase
                let paidBeforeThis = 0;
                for (const pay of allPayments) {
                    if (paidBeforeThis + pay.amount <= debtBeforeThis) {
                        paidBeforeThis += pay.amount;
                    } else {
                        break;
                    }
                }
                
                // Calculate how much can be allocated to this purchase
                const availableForThis = Math.max(0, totalPayments - paidBeforeThis);
                totalPaid = Math.min(availableForThis, purchase.totalAmount);
                remainingBalance = Math.max(0, purchase.totalAmount - totalPaid);
                break;
            }
            cumulativeDebt += p.totalAmount;
        }
    }
    
    res.json({
        success: true,
        data: {
            ...purchase,
            supplierName: supplier ? supplier.name : 'N/A',
            supplierDetails: supplier || null,
            items: enrichedItems,
            paymentHistory: paymentHistory,
            totalPaid: totalPaid,
            remainingBalance: remainingBalance
        }
    });
});

app.post('/api/purchases', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
    const { supplierId, items, invoiceNumber, notes, branchId, paymentType, paymentMethod, paymentMethodCustom } = req.body;
    const purchases = readDB(dbFiles.purchases);
    const stock = readDB(dbFiles.stock);
    const products = readDB(dbFiles.products);
    const supplierPayments = readDB(dbFiles.supplierPayments);
    const settings = readDB(dbFiles.settings);
    
    const purchaseId = uuidv4();
    const totalAmount = items.reduce((sum, item) => sum + (item.quantity * item.costPrice), 0);
    
    // Handle custom payment method - save it if it's new
    let finalPaymentMethod = paymentMethod || 'cash';
    if (paymentMethodCustom) {
        // Normalize custom method name
        const normalizedMethod = paymentMethodCustom.toLowerCase().trim().replace(/\s+/g, '_');
        finalPaymentMethod = normalizedMethod;
        
        // Add to settings if not already exists
        if (!settings.paymentMethods) {
            settings.paymentMethods = ['cash', 'bank', 'mpesa', 'airtel', 'tigo', 'halopesa'];
        }
        
        // Check if this is a new payment method
        if (!settings.paymentMethods.includes(normalizedMethod)) {
            settings.paymentMethods.push(normalizedMethod);
            writeDB(dbFiles.settings, settings);
            logActivity(req.session.user.id, 'CREATE_PAYMENT_METHOD', `New payment method added: ${paymentMethodCustom}`, req.ip);
        }
    }
    
    const newPurchase = {
        id: purchaseId,
        supplierId,
        items: items.map(item => ({
            productId: item.productId,
            quantity: parseInt(item.quantity),
            costPrice: parseFloat(item.costPrice),
            batchNumber: item.batchNumber,
            expiryDate: item.expiryDate
        })),
        invoiceNumber: invoiceNumber || `PO-${Date.now()}`,
        totalAmount,
        paymentType: paymentType || 'cash', // 'cash' or 'credit'
        paymentMethod: finalPaymentMethod, // Normalized payment method
        branchId: branchId || req.session.user.branchId,
        status: 'completed',
        notes,
        createdBy: req.session.user.id,
        createdAt: new Date().toISOString()
    };
    
    purchases.push(newPurchase);
    
    // If purchase is on credit, create a debt record
    if (paymentType === 'credit') {
        supplierPayments.push({
            id: uuidv4(),
            purchaseId: purchaseId,
            supplierId: supplierId,
            type: 'debt', // 'debt' for purchases on credit, 'payment' for payments made
            amount: totalAmount,
            balance: totalAmount, // Initial balance equals the debt
            paymentMethod: null,
            reference: invoiceNumber || newPurchase.invoiceNumber,
            notes: `Deni kutoka purchase order: ${newPurchase.invoiceNumber}`,
            createdBy: req.session.user.id,
            createdAt: new Date().toISOString()
        });
        writeDB(dbFiles.supplierPayments, supplierPayments);
    }
    
    // Add stock entries for each item
    items.forEach(item => {
        const product = products.find(p => p.id === item.productId);
        stock.push({
            id: uuidv4(),
            productId: item.productId,
            quantity: parseInt(item.quantity),
            batchNumber: item.batchNumber || `BATCH-${Date.now()}`,
            expiryDate: item.expiryDate || null,
            costPrice: parseFloat(item.costPrice),
            branchId: branchId || req.session.user.branchId,
            purchaseId,
            type: 'in',
            createdBy: req.session.user.id,
            createdAt: new Date().toISOString()
        });
    });
    
    writeDB(dbFiles.purchases, purchases);
    writeDB(dbFiles.stock, stock);
    
    logActivity(req.session.user.id, 'CREATE_PURCHASE', `Created purchase order: ${newPurchase.invoiceNumber}`, req.ip);
    
    res.json({ success: true, message: 'Purchase imeongezwa', data: newPurchase });
});

// API: Customers
app.get('/api/customers', isAuthenticated, (req, res) => {
    const customers = readDB(dbFiles.customers);
    const creditSales = readDB(dbFiles.creditSales);
    
    const enrichedCustomers = customers.map(c => {
        const credits = creditSales.filter(cs => cs.customerId === c.id);
        const totalDebt = credits.reduce((sum, cs) => sum + (cs.totalAmount - cs.paidAmount), 0);
        return {
            ...c,
            totalDebt
        };
    });
    
    res.json({ success: true, data: enrichedCustomers });
});

app.post('/api/customers', isAuthenticated, (req, res) => {
    const { name, businessName, type, phone, email, address, taxId, creditLimit } = req.body;
    const customers = readDB(dbFiles.customers);
    
    const newCustomer = {
        id: uuidv4(),
        name,
        businessName,
        type: type || 'retail', // wholesale, retail, supermarket
        phone,
        email,
        address,
        taxId,
        creditLimit: parseFloat(creditLimit) || 0,
        status: 'active',
        createdAt: new Date().toISOString()
    };
    
    customers.push(newCustomer);
    writeDB(dbFiles.customers, customers);
    
    logActivity(req.session.user.id, 'CREATE_CUSTOMER', `Created customer: ${name}`, req.ip);
    
    res.json({ success: true, message: 'Mteja ameongezwa', data: newCustomer });
});

app.put('/api/customers/:id', isAuthenticated, (req, res) => {
    const { id } = req.params;
    const updates = req.body;
    const customers = readDB(dbFiles.customers);
    
    const custIndex = customers.findIndex(c => c.id === id);
    if (custIndex === -1) {
        return res.json({ success: false, message: 'Mteja hapo' });
    }
    
    customers[custIndex] = {
        ...customers[custIndex],
        ...updates,
        updatedAt: new Date().toISOString()
    };
    
    writeDB(dbFiles.customers, customers);
    res.json({ success: true, message: 'Mteja ameboreshwa' });
});

app.delete('/api/customers/:id', isAuthenticated, hasRole('admin'), (req, res) => {
    const { id } = req.params;
    let customers = readDB(dbFiles.customers);
    
    customers = customers.filter(c => c.id !== id);
    writeDB(dbFiles.customers, customers);
    
    res.json({ success: true, message: 'Mteja amefutwa' });
});

// API: Customer Statement
app.get('/api/customers/:id/statement', isAuthenticated, (req, res) => {
    const { id } = req.params;
    const { startDate, endDate } = req.query;
    
    const customers = readDB(dbFiles.customers);
    const sales = readDB(dbFiles.sales);
    const creditSales = readDB(dbFiles.creditSales);
    const payments = readDB(dbFiles.payments);
    
    const customer = customers.find(c => c.id === id);
    if (!customer) {
        return res.json({ success: false, message: 'Mteja hapo' });
    }
    
    // Filter by date if provided
    let customerSales = sales.filter(s => s.customerId === id);
    let customerCredits = creditSales.filter(cs => cs.customerId === id);
    let customerPayments = payments.filter(p => p.customerId === id);
    
    if (startDate && endDate) {
        const start = moment(startDate).startOf('day');
        const end = moment(endDate).endOf('day');
        
        customerSales = customerSales.filter(s => moment(s.createdAt).isBetween(start, end));
        customerCredits = customerCredits.filter(cs => moment(cs.createdAt).isBetween(start, end));
        customerPayments = customerPayments.filter(p => moment(p.createdAt).isBetween(start, end));
    }
    
    const totalSales = customerSales.reduce((sum, s) => sum + s.totalAmount, 0);
    const totalCredits = customerCredits.reduce((sum, cs) => sum + cs.totalAmount, 0);
    const totalPaid = customerCredits.reduce((sum, cs) => sum + cs.paidAmount, 0);
    const balance = totalCredits - totalPaid;
    
    res.json({
        success: true,
        data: {
            customer,
            sales: customerSales,
            credits: customerCredits,
            payments: customerPayments,
            summary: {
                totalSales,
                totalCredits,
                totalPaid,
                balance
            }
        }
    });
});

// API: Sales
app.get('/api/sales', isAuthenticated, (req, res) => {
    const { startDate, endDate, cashierId, branchId, page, limit } = req.query;
    let sales = readDB(dbFiles.sales);
    const users = readDB(dbFiles.users);
    const customers = readDB(dbFiles.customers);
    
    // Apply filters
    if (startDate && endDate) {
        const start = moment(startDate).startOf('day');
        const end = moment(endDate).endOf('day');
        sales = sales.filter(s => {
            // Check if any relevant date (createdAt, verifiedAt, completedAt) falls within the range
            const createdDate = moment(s.createdAt);
            const verifiedDate = s.verifiedAt ? moment(s.verifiedAt) : null;
            const completedDate = s.completedAt ? moment(s.completedAt) : null;
            
            // Include if created, verified, or completed date is within range
            return createdDate.isBetween(start, end, null, '[]') ||
                   (verifiedDate && verifiedDate.isBetween(start, end, null, '[]')) ||
                   (completedDate && completedDate.isBetween(start, end, null, '[]'));
        });
    }
    
    if (cashierId) {
        sales = sales.filter(s => s.createdBy === cashierId);
    }
    
    if (branchId) {
        sales = sales.filter(s => s.branchId === branchId);
    }
    
    // Role-based filtering
    if (req.session.user.role === 'cashier') {
        // Cashier should see all sales in their branch (not just ones they created)
        // This includes orders created by reception that they verified, and all completed orders
        sales = sales.filter(s => s.branchId === req.session.user.branchId);
    }
    
    const enrichedSales = sales.map(s => {
        const cashier = users.find(u => u.id === s.createdBy);
        const customer = customers.find(c => c.id === s.customerId);
        return {
            ...s,
            cashierName: cashier ? cashier.fullName : 'N/A',
            customerName: customer ? customer.name : 'Walk-in Customer'
        };
    });
    
    // Sort by most recent first (use completedAt, verifiedAt, or createdAt)
    enrichedSales.sort((a, b) => {
        const dateA = new Date(a.completedAt || a.verifiedAt || a.createdAt);
        const dateB = new Date(b.completedAt || b.verifiedAt || b.createdAt);
        return dateB - dateA;
    });

    // Pagination (only applied when ?page is provided; omit for full export/filter use)
    const pageNum = parseInt(page) || 0;
    if (pageNum > 0) {
        const limitNum = Math.min(parseInt(limit) || 50, 200);
        const total = enrichedSales.length;
        const paginated = enrichedSales.slice((pageNum - 1) * limitNum, pageNum * limitNum);
        return res.json({ success: true, data: paginated, total, page: pageNum, limit: limitNum, pages: Math.ceil(total / limitNum) });
    }
    
    res.json({ success: true, data: enrichedSales });
});

app.post('/api/sales', isAuthenticated, hasRole('admin', 'cashier', 'reception'), (req, res) => {
    const { items, customerId, saleType, paymentMethod, discount, notes, branchId, isCredit, dueDate, creditRequest } = req.body;
    const sales = readDB(dbFiles.sales);
    const stock = readDB(dbFiles.stock);
    const products = readDB(dbFiles.products);
    const creditSales = readDB(dbFiles.creditSales);
    const userRole = req.session.user.role;
    
    // Validate stock availability
    for (let item of items) {
        const product = products.find(p => p.id === item.productId);
        if (!product) {
            return res.json({ success: false, message: `Bidhaa haipo: ${item.productId}` });
        }
        
        const productStock = stock.filter(s => s.productId === item.productId && s.type === 'in');
        const totalQty = productStock.reduce((sum, s) => sum + s.quantity, 0);
        
        if (totalQty < item.quantity) {
            return res.json({ success: false, message: `Stock haitoshi kwa ${product.name}. Ipo: ${totalQty}` });
        }
    }
    
    const saleId = uuidv4();
    const receiptNumber = `RCP-${Date.now()}`;
    
    // Calculate totals
    let subtotal = 0;
    const saleItems = items.map(item => {
        const product = products.find(p => p.id === item.productId);
        const price = saleType === 'wholesale' ? product.wholesalePrice : product.retailPrice;
        const itemTotal = price * item.quantity;
        subtotal += itemTotal;
        
        return {
            productId: item.productId,
            productName: product.name,
            quantity: parseInt(item.quantity),
            price,
            total: itemTotal
        };
    });
    
    const discountAmount = parseFloat(discount) || 0;
    const totalAmount = subtotal - discountAmount;
    
    // Determine status based on role
    let saleStatus = 'completed';
    if (userRole === 'reception') {
        saleStatus = 'pending_verification'; // Reception submits orders for cashier verification
    }
    
    const newSale = {
        id: saleId,
        receiptNumber,
        items: saleItems,
        customerId: customerId || null,
        saleType: saleType || 'retail',
        paymentMethod: paymentMethod || 'cash',
        subtotal,
        discount: discountAmount,
        totalAmount,
        branchId: branchId || req.session.user.branchId,
        notes,
        isCredit: isCredit || false,
        creditRequest: creditRequest || false, // Reception can request credit
        status: saleStatus,
        createdBy: req.session.user.id,
        createdAt: new Date().toISOString(),
        verifiedBy: null,
        verifiedAt: null,
        completedBy: null,
        completedAt: null
    };
    
    sales.push(newSale);
    
    // Only deduct stock if order is completed (cashier/admin) or if admin/cashier creates order
    // Reception orders don't deduct stock until verified by cashier
    if (saleStatus === 'completed') {
        // Deduct stock for each item (FIFO)
        items.forEach(item => {
            let remaining = parseInt(item.quantity);
            const productStock = stock.filter(s => s.productId === item.productId && s.type === 'in' && s.quantity > 0);
            productStock.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
            
            for (let s of productStock) {
                if (remaining <= 0) break;
                
                const stockIndex = stock.findIndex(st => st.id === s.id);
                if (s.quantity <= remaining) {
                    remaining -= s.quantity;
                    stock[stockIndex].quantity = 0;
                } else {
                    stock[stockIndex].quantity -= remaining;
                    remaining = 0;
                }
            }
        });
        
        writeDB(dbFiles.stock, stock);
    }
    
    writeDB(dbFiles.sales, sales);
    
    // Handle credit sale (only for completed sales)
    if (saleStatus === 'completed' && isCredit && customerId) {
        const creditSale = {
            id: uuidv4(),
            saleId,
            customerId,
            totalAmount,
            paidAmount: 0,
            dueDate: dueDate || moment().add(30, 'days').toISOString(),
            status: 'pending',
            createdAt: new Date().toISOString()
        };
        creditSales.push(creditSale);
        writeDB(dbFiles.creditSales, creditSales);
    }
    
    const logMessage = userRole === 'reception' ? 
        `Submitted order for verification: ${receiptNumber}, Amount: ${totalAmount}` :
        `Created sale: ${receiptNumber}, Amount: ${totalAmount}`;
    logActivity(req.session.user.id, 'CREATE_SALE', logMessage, req.ip);
    
    const successMessage = userRole === 'reception' ?
        'Agizo limewasilishwa kwa cashier kwa uthibitisho' :
        'Mauzo yamefanikiwa';
    
    res.json({ success: true, message: successMessage, data: newSale });
});

// API: Generate Receipt PDF
app.get('/api/sales/:id/receipt', isAuthenticated, (req, res) => {
    const { id } = req.params;
    const sales = readDB(dbFiles.sales);
    const settings = readDB(dbFiles.settings);
    const customers = readDB(dbFiles.customers);
    
    const sale = sales.find(s => s.id === id);
    if (!sale) {
        return res.json({ success: false, message: 'Sale not found' });
    }
    
    const customer = customers.find(c => c.id === sale.customerId);
    
    // Create PDF
    const doc = new PDFDocument({ size: [226, 500], margin: 10 }); // 80mm receipt
    
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename=receipt-${sale.receiptNumber}.pdf`);
    
    doc.pipe(res);
    
    // Header
    doc.fontSize(14).font('Helvetica-Bold').text(settings.companyName || 'DUKA JUMLA', { align: 'center' });
    doc.fontSize(8).font('Helvetica').text(settings.companyAddress || '', { align: 'center' });
    doc.text(settings.companyPhone || '', { align: 'center' });
    doc.moveDown(0.5);
    
    doc.text('─'.repeat(30), { align: 'center' });
    doc.fontSize(10).font('Helvetica-Bold').text('RISITI / RECEIPT', { align: 'center' });
    doc.text('─'.repeat(30), { align: 'center' });
    doc.moveDown(0.3);
    
    // Receipt info
    doc.fontSize(8).font('Helvetica');
    doc.text(`No: ${sale.receiptNumber}`);
    doc.text(`Tarehe: ${moment(sale.createdAt).format('DD/MM/YYYY HH:mm')}`);
    if (customer) {
        doc.text(`Mteja: ${customer.name}`);
    }
    doc.text(`Aina: ${sale.saleType === 'wholesale' ? 'Jumla' : 'Rejareja'}`);
    doc.moveDown(0.3);
    
    doc.text('─'.repeat(30), { align: 'center' });
    
    // Items
    sale.items.forEach(item => {
        doc.text(`${item.productName}`);
        doc.text(`  ${item.quantity} x ${item.price.toLocaleString()} = ${item.total.toLocaleString()} TZS`);
    });
    
    doc.text('─'.repeat(30), { align: 'center' });
    
    // Totals
    doc.text(`Jumla: ${sale.subtotal.toLocaleString()} TZS`, { align: 'right' });
    if (sale.discount > 0) {
        doc.text(`Punguzo: -${sale.discount.toLocaleString()} TZS`, { align: 'right' });
    }
    doc.fontSize(10).font('Helvetica-Bold');
    doc.text(`JUMLA KUU: ${sale.totalAmount.toLocaleString()} TZS`, { align: 'right' });
    
    doc.moveDown(0.5);
    doc.fontSize(8).font('Helvetica');
    doc.text(`Malipo: ${sale.paymentMethod.toUpperCase()}`, { align: 'center' });
    
    doc.moveDown(0.5);
    doc.text('─'.repeat(30), { align: 'center' });
    doc.text(settings.receiptFooter || 'Asante kwa kununua!', { align: 'center' });
    
    doc.end();
});

// API: Credit Sales & Payments
app.get('/api/credit-sales', isAuthenticated, hasRole('admin', 'cashier', 'storekeeper'), (req, res) => {
    const creditSales = readDB(dbFiles.creditSales);
    const customers = readDB(dbFiles.customers);
    const sales = readDB(dbFiles.sales);
    
    const enriched = creditSales.map(cs => {
        const customer = customers.find(c => c.id === cs.customerId);
        const sale = sales.find(s => s.id === cs.saleId);
        return {
            ...cs,
            customerName: customer ? customer.name : 'N/A',
            receiptNumber: sale ? sale.receiptNumber : 'N/A',
            balance: cs.totalAmount - cs.paidAmount
        };
    });
    
    res.json({ success: true, data: enriched });
});

app.post('/api/credit-sales/:id/pay', isAuthenticated, hasRole('admin', 'cashier', 'storekeeper'), (req, res) => {
    const { id } = req.params;
    const { amount, paymentMethod, reference } = req.body;
    
    const creditSales = readDB(dbFiles.creditSales);
    const payments = readDB(dbFiles.payments);
    
    const creditIndex = creditSales.findIndex(cs => cs.id === id);
    if (creditIndex === -1) {
        return res.json({ success: false, message: 'Credit sale not found' });
    }
    
    const paymentAmount = parseFloat(amount);
    const balance = creditSales[creditIndex].totalAmount - creditSales[creditIndex].paidAmount;
    
    if (paymentAmount > balance) {
        return res.json({ success: false, message: `Kiasi kinazidi deni. Deni ni: ${balance} TZS` });
    }
    
    creditSales[creditIndex].paidAmount += paymentAmount;
    if (creditSales[creditIndex].paidAmount >= creditSales[creditIndex].totalAmount) {
        creditSales[creditIndex].status = 'paid';
    }
    
    const payment = {
        id: uuidv4(),
        creditSaleId: id,
        customerId: creditSales[creditIndex].customerId,
        amount: paymentAmount,
        paymentMethod: paymentMethod || 'cash',
        reference,
        createdBy: req.session.user.id,
        createdAt: new Date().toISOString()
    };
    
    payments.push(payment);
    
    writeDB(dbFiles.creditSales, creditSales);
    writeDB(dbFiles.payments, payments);
    
    logActivity(req.session.user.id, 'CREDIT_PAYMENT', `Received payment: ${paymentAmount} TZS`, req.ip);
    
    res.json({ success: true, message: 'Malipo yamepokelewa' });
});

// API: Verify order (Cashier verifies reception orders)
app.post('/api/sales/:id/verify', isAuthenticated, hasRole('admin', 'cashier'), (req, res) => {
    const { id } = req.params;
    const { paymentMethod, isCredit, dueDate } = req.body;
    const sales = readDB(dbFiles.sales);
    const stock = readDB(dbFiles.stock);
    const creditSales = readDB(dbFiles.creditSales);
    
    const saleIndex = sales.findIndex(s => s.id === id);
    if (saleIndex === -1) {
        return res.json({ success: false, message: 'Agizo halipatikani' });
    }
    
    const sale = sales[saleIndex];
    if (sale.status !== 'pending_verification') {
        return res.json({ success: false, message: 'Agizo hili tayari limethibitishwa au limekamilika' });
    }
    
    // Update sale with payment method and status
    sales[saleIndex].paymentMethod = paymentMethod || sale.paymentMethod || 'cash';
    sales[saleIndex].isCredit = isCredit || false;
    sales[saleIndex].status = 'verified';
    sales[saleIndex].verifiedBy = req.session.user.id;
    sales[saleIndex].verifiedAt = new Date().toISOString();
    
    // Deduct stock for each item (FIFO)
    sale.items.forEach(item => {
        let remaining = parseInt(item.quantity);
        const productStock = stock.filter(s => s.productId === item.productId && s.type === 'in' && s.quantity > 0);
        productStock.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
        
        for (let s of productStock) {
            if (remaining <= 0) break;
            
            const stockIndex = stock.findIndex(st => st.id === s.id);
            if (s.quantity <= remaining) {
                remaining -= s.quantity;
                stock[stockIndex].quantity = 0;
            } else {
                stock[stockIndex].quantity -= remaining;
                remaining = 0;
            }
        }
    });
    
    writeDB(dbFiles.sales, sales);
    writeDB(dbFiles.stock, stock);
    
    // Handle credit sale
    if (isCredit && sale.customerId) {
        const creditSale = {
            id: uuidv4(),
            saleId: id,
            customerId: sale.customerId,
            totalAmount: sale.totalAmount,
            paidAmount: 0,
            dueDate: dueDate || moment().add(30, 'days').toISOString(),
            status: 'pending',
            createdAt: new Date().toISOString()
        };
        creditSales.push(creditSale);
        writeDB(dbFiles.creditSales, creditSales);
    }
    
    logActivity(req.session.user.id, 'VERIFY_ORDER', `Verified order: ${sale.receiptNumber}`, req.ip);
    
    res.json({ success: true, message: 'Agizo limethibitishwa na kuthibitishwa', data: sales[saleIndex] });
});

// API: Complete order (Store viewer marks order as complete after giving to customer)
app.post('/api/sales/:id/complete', isAuthenticated, hasRole('admin', 'store_viewer'), (req, res) => {
    const { id } = req.params;
    const sales = readDB(dbFiles.sales);
    
    const saleIndex = sales.findIndex(s => s.id === id);
    if (saleIndex === -1) {
        return res.json({ success: false, message: 'Agizo halipatikani' });
    }
    
    const sale = sales[saleIndex];
    if (sale.status !== 'verified') {
        return res.json({ success: false, message: 'Agizo lazima liwe verified kabla ya ku-complete' });
    }
    
    // Update sale status to completed
    sales[saleIndex].status = 'completed';
    sales[saleIndex].completedBy = req.session.user.id;
    sales[saleIndex].completedAt = new Date().toISOString();
    
    writeDB(dbFiles.sales, sales);
    
    logActivity(req.session.user.id, 'COMPLETE_ORDER', `Completed order: ${sale.receiptNumber}`, req.ip);
    
    res.json({ success: true, message: 'Agizo limekamilika na mteja amepokea bidhaa', data: sales[saleIndex] });
});

// API: Get pending orders (for cashier)
app.get('/api/sales/pending', isAuthenticated, hasRole('admin', 'cashier'), (req, res) => {
    let sales = readDB(dbFiles.sales);
    const users = readDB(dbFiles.users);
    const customers = readDB(dbFiles.customers);
    
    // Get only pending verification orders
    sales = sales.filter(s => s.status === 'pending_verification');
    
    // Filter by branch if cashier
    if (req.session.user.role === 'cashier') {
        sales = sales.filter(s => s.branchId === req.session.user.branchId);
    }
    
    const enrichedSales = sales.map(s => {
        const receptionist = users.find(u => u.id === s.createdBy);
        const customer = customers.find(c => c.id === s.customerId);
        return {
            ...s,
            receptionistName: receptionist ? receptionist.fullName : 'N/A',
            customerName: customer ? customer.name : 'Walk-in Customer'
        };
    });
    
    res.json({ success: true, data: enrichedSales.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt)) });
});

// API: Get verified orders (for store viewer)
app.get('/api/sales/verified', isAuthenticated, hasRole('admin', 'store_viewer'), (req, res) => {
    let sales = readDB(dbFiles.sales);
    const users = readDB(dbFiles.users);
    const customers = readDB(dbFiles.customers);
    
    // Get only verified orders (not yet completed)
    sales = sales.filter(s => s.status === 'verified');
    
    // Filter by branch if store_viewer
    if (req.session.user.role === 'store_viewer') {
        sales = sales.filter(s => s.branchId === req.session.user.branchId);
    }
    
    const enrichedSales = sales.map(s => {
        const receptionist = users.find(u => u.id === s.createdBy);
        const cashier = users.find(u => u.id === s.verifiedBy);
        const customer = customers.find(c => c.id === s.customerId);
        return {
            ...s,
            receptionistName: receptionist ? receptionist.fullName : 'N/A',
            cashierName: cashier ? cashier.fullName : 'N/A',
            customerName: customer ? customer.name : 'Walk-in Customer'
        };
    });
    
    res.json({ success: true, data: enrichedSales.sort((a, b) => new Date(b.verifiedAt || b.createdAt) - new Date(a.verifiedAt || a.createdAt)) });
});

// API: Get ongoing orders (all orders with status for all roles except store_viewer)
app.get('/api/sales/ongoing', isAuthenticated, (req, res) => {
    // Store viewer should not access this endpoint
    if (req.session.user.role === 'store_viewer') {
        return res.json({ success: false, message: 'Unauthorized' });
    }
    
    let sales = readDB(dbFiles.sales);
    const users = readDB(dbFiles.users);
    const customers = readDB(dbFiles.customers);
    const role = req.session.user.role;
    
    // Filter by role
    if (role === 'reception') {
        // Reception sees only their own orders
        sales = sales.filter(s => s.createdBy === req.session.user.id);
    } else if (role === 'cashier') {
        // Cashier sees pending and verified orders (their branch)
        sales = sales.filter(s => 
            (s.status === 'pending_verification' || s.status === 'verified') &&
            s.branchId === req.session.user.branchId
        );
    } else if (role === 'storekeeper') {
        // Storekeeper sees all orders (their branch)
        sales = sales.filter(s => s.branchId === req.session.user.branchId);
    }
    // Admin sees all orders (no filtering)
    
    // Enrich with user and customer names
    const enrichedSales = sales.map(s => {
        const receptionist = users.find(u => u.id === s.createdBy);
        const cashier = users.find(u => u.id === s.verifiedBy);
        const customer = customers.find(c => c.id === s.customerId);
        return {
            ...s,
            receptionistName: receptionist ? receptionist.fullName : 'N/A',
            cashierName: cashier ? cashier.fullName : 'N/A',
            customerName: customer ? customer.name : 'Walk-in Customer'
        };
    });
    
    // Sort by most recent first
    const sorted = enrichedSales.sort((a, b) => {
        const dateA = new Date(a.verifiedAt || a.createdAt);
        const dateB = new Date(b.verifiedAt || b.createdAt);
        return dateB - dateA;
    });
    
    res.json({ success: true, data: sorted });
});

// API: Expenses
app.get('/api/expenses', isAuthenticated, (req, res) => {
    const { startDate, endDate, category } = req.query;
    let expenses = readDB(dbFiles.expenses);
    
    if (startDate && endDate) {
        const start = moment(startDate).startOf('day');
        const end = moment(endDate).endOf('day');
        expenses = expenses.filter(e => moment(e.date).isBetween(start, end, null, '[]'));
    }
    
    if (category) {
        expenses = expenses.filter(e => e.category === category);
    }
    
    res.json({ success: true, data: expenses });
});

app.post('/api/expenses', isAuthenticated, hasRole('admin'), (req, res) => {
    const { category, description, amount, date, paymentMethod, reference, branchId } = req.body;
    const expenses = readDB(dbFiles.expenses);
    
    const newExpense = {
        id: uuidv4(),
        category, // rent, utilities, salaries, transport, supplies, other
        description,
        amount: parseFloat(amount),
        date: date || new Date().toISOString(),
        paymentMethod: paymentMethod || 'cash',
        reference,
        branchId: branchId || req.session.user.branchId,
        createdBy: req.session.user.id,
        createdAt: new Date().toISOString()
    };
    
    expenses.push(newExpense);
    writeDB(dbFiles.expenses, expenses);
    
    logActivity(req.session.user.id, 'CREATE_EXPENSE', `Created expense: ${description} - ${amount}`, req.ip);
    
    res.json({ success: true, message: 'Matumizi yameongezwa', data: newExpense });
});

app.put('/api/expenses/:id', isAuthenticated, hasRole('admin'), (req, res) => {
    const { id } = req.params;
    const updates = req.body;
    const expenses = readDB(dbFiles.expenses);
    
    const expIndex = expenses.findIndex(e => e.id === id);
    if (expIndex === -1) {
        return res.json({ success: false, message: 'Expense not found' });
    }
    
    expenses[expIndex] = {
        ...expenses[expIndex],
        ...updates,
        amount: parseFloat(updates.amount) || expenses[expIndex].amount,
        updatedAt: new Date().toISOString()
    };
    
    writeDB(dbFiles.expenses, expenses);
    res.json({ success: true, message: 'Matumizi yameboreshwa' });
});

app.delete('/api/expenses/:id', isAuthenticated, hasRole('admin'), (req, res) => {
    const { id } = req.params;
    let expenses = readDB(dbFiles.expenses);
    
    expenses = expenses.filter(e => e.id !== id);
    writeDB(dbFiles.expenses, expenses);
    
    res.json({ success: true, message: 'Matumizi yamefutwa' });
});

// API: Branches
app.get('/api/branches', isAuthenticated, (req, res) => {
    const branches = readDB(dbFiles.branches);
    res.json({ success: true, data: branches });
});

app.post('/api/branches', isAuthenticated, hasRole('admin'), (req, res) => {
    const { name, address, phone, email } = req.body;
    const branches = readDB(dbFiles.branches);
    
    const newBranch = {
        id: uuidv4(),
        name,
        address,
        phone,
        email,
        status: 'active',
        createdAt: new Date().toISOString()
    };
    
    branches.push(newBranch);
    writeDB(dbFiles.branches, branches);
    
    logActivity(req.session.user.id, 'CREATE_BRANCH', `Created branch: ${name}`, req.ip);
    
    res.json({ success: true, message: 'Tawi limeongezwa', data: newBranch });
});

app.put('/api/branches/:id', isAuthenticated, hasRole('admin'), (req, res) => {
    const { id } = req.params;
    const updates = req.body;
    const branches = readDB(dbFiles.branches);
    
    const branchIndex = branches.findIndex(b => b.id === id);
    if (branchIndex === -1) {
        return res.json({ success: false, message: 'Branch not found' });
    }
    
    branches[branchIndex] = {
        ...branches[branchIndex],
        ...updates,
        updatedAt: new Date().toISOString()
    };
    
    writeDB(dbFiles.branches, branches);
    res.json({ success: true, message: 'Tawi limeboreshwa' });
});

// API: Stock Transfer between branches
app.post('/api/stock/transfer', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
    const { productId, quantity, fromBranchId, toBranchId, notes } = req.body;
    const stock = readDB(dbFiles.stock);
    const stockTransfers = readDB(dbFiles.stockTransfers);
    const products = readDB(dbFiles.products);
    
    const product = products.find(p => p.id === productId);
    if (!product) {
        return res.json({ success: false, message: 'Bidhaa haipo' });
    }
    
    // Check stock in source branch
    const sourceStock = stock.filter(s => s.productId === productId && s.branchId === fromBranchId && s.type === 'in');
    const availableQty = sourceStock.reduce((sum, s) => sum + s.quantity, 0);
    
    if (availableQty < quantity) {
        return res.json({ success: false, message: `Stock haitoshi. Ipo: ${availableQty}` });
    }
    
    // Create transfer record
    const transfer = {
        id: uuidv4(),
        productId,
        quantity: parseInt(quantity),
        fromBranchId,
        toBranchId,
        status: 'completed',
        notes,
        createdBy: req.session.user.id,
        createdAt: new Date().toISOString()
    };
    
    // Deduct from source (FIFO)
    let remaining = parseInt(quantity);
    sourceStock.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
    
    for (let s of sourceStock) {
        if (remaining <= 0) break;
        
        const stockIndex = stock.findIndex(st => st.id === s.id);
        if (s.quantity <= remaining) {
            // Add to destination with same batch info
            stock.push({
                id: uuidv4(),
                productId,
                quantity: s.quantity,
                batchNumber: s.batchNumber,
                expiryDate: s.expiryDate,
                costPrice: s.costPrice,
                branchId: toBranchId,
                transferId: transfer.id,
                type: 'in',
                createdBy: req.session.user.id,
                createdAt: new Date().toISOString()
            });
            remaining -= s.quantity;
            stock[stockIndex].quantity = 0;
        } else {
            stock.push({
                id: uuidv4(),
                productId,
                quantity: remaining,
                batchNumber: s.batchNumber,
                expiryDate: s.expiryDate,
                costPrice: s.costPrice,
                branchId: toBranchId,
                transferId: transfer.id,
                type: 'in',
                createdBy: req.session.user.id,
                createdAt: new Date().toISOString()
            });
            stock[stockIndex].quantity -= remaining;
            remaining = 0;
        }
    }
    
    stockTransfers.push(transfer);
    
    writeDB(dbFiles.stock, stock);
    writeDB(dbFiles.stockTransfers, stockTransfers);
    
    logActivity(req.session.user.id, 'STOCK_TRANSFER', `Transferred ${quantity} ${product.unit} of ${product.name}`, req.ip);
    
    res.json({ success: true, message: 'Stock imehamishwa', data: transfer });
});

app.get('/api/stock/transfers', isAuthenticated, (req, res) => {
    const transfers = readDB(dbFiles.stockTransfers);
    const products = readDB(dbFiles.products);
    const branches = readDB(dbFiles.branches);
    
    const enriched = transfers.map(t => {
        const product = products.find(p => p.id === t.productId);
        const fromBranch = branches.find(b => b.id === t.fromBranchId);
        const toBranch = branches.find(b => b.id === t.toBranchId);
        
        return {
            ...t,
            productName: product ? product.name : 'N/A',
            fromBranchName: fromBranch ? fromBranch.name : 'N/A',
            toBranchName: toBranch ? toBranch.name : 'N/A'
        };
    });
    
    res.json({ success: true, data: enriched });
});

// API: Notifications
app.get('/api/notifications', isAuthenticated, (req, res) => {
    let notifications = readDB(dbFiles.notifications);
    
    // Filter by role and branch
    notifications = notifications.filter(n => {
        return (n.targetRole === 'all' || n.targetRole === req.session.user.role) &&
               (n.branchId === 'all' || n.branchId === req.session.user.branchId);
    });
    
    // Sort by date, newest first
    notifications.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    
    res.json({ success: true, data: notifications.slice(0, 50) });
});

app.put('/api/notifications/:id/read', isAuthenticated, (req, res) => {
    const { id } = req.params;
    const notifications = readDB(dbFiles.notifications);
    
    const notifIndex = notifications.findIndex(n => n.id === id);
    if (notifIndex !== -1) {
        notifications[notifIndex].read = true;
        writeDB(dbFiles.notifications, notifications);
    }
    
    res.json({ success: true });
});

app.delete('/api/notifications/:id', isAuthenticated, (req, res) => {
    const { id } = req.params;
    let notifications = readDB(dbFiles.notifications);
    
    notifications = notifications.filter(n => n.id !== id);
    writeDB(dbFiles.notifications, notifications);
    
    res.json({ success: true });
});

// API: Activity Logs
app.get('/api/activity-logs', isAuthenticated, hasRole('admin'), (req, res) => {
    const { startDate, endDate, userId, action } = req.query;
    let logs = readDB(dbFiles.activityLogs);
    const users = readDB(dbFiles.users);
    
    if (startDate && endDate) {
        const start = moment(startDate).startOf('day');
        const end = moment(endDate).endOf('day');
        logs = logs.filter(l => moment(l.timestamp).isBetween(start, end));
    }
    
    if (userId) {
        logs = logs.filter(l => l.userId === userId);
    }
    
    if (action) {
        logs = logs.filter(l => l.action === action);
    }
    
    const enriched = logs.map(l => {
        const user = users.find(u => u.id === l.userId);
        return {
            ...l,
            userName: user ? user.fullName : 'System'
        };
    });
    
    // Sort by date, newest first
    enriched.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    
    // Pagination for activity logs (default page 1, limit 100)
    const pageNum = parseInt(req.query.page) || 1;
    const limitNum = Math.min(parseInt(req.query.limit) || 100, 500);
    const total = enriched.length;
    const paginated = enriched.slice((pageNum - 1) * limitNum, pageNum * limitNum);
    res.json({ success: true, data: paginated, total, page: pageNum, limit: limitNum, pages: Math.ceil(total / limitNum) });
});

// API: Settings
app.get('/api/settings', isAuthenticated, (req, res) => {
    const settings = readDB(dbFiles.settings);
    res.json({ success: true, data: settings });
});

app.put('/api/settings', isAuthenticated, hasRole('admin'), (req, res) => {
    const updates = req.body;
    const settings = readDB(dbFiles.settings);
    
    const newSettings = {
        ...settings,
        ...updates,
        updatedAt: new Date().toISOString()
    };
    
    writeDB(dbFiles.settings, newSettings);
    
    logActivity(req.session.user.id, 'UPDATE_SETTINGS', 'Updated system settings', req.ip);
    
    res.json({ success: true, message: 'Settings zimeboreshwa' });
});

// API: Dashboard Statistics
app.get('/api/dashboard/stats', isAuthenticated, (req, res) => {
    const sales = readDB(dbFiles.sales);
    const products = readDB(dbFiles.products);
    const stock = readDB(dbFiles.stock);
    const customers = readDB(dbFiles.customers);
    const expenses = readDB(dbFiles.expenses);
    const creditSales = readDB(dbFiles.creditSales);
    const settings = readDB(dbFiles.settings);
    
    const today = moment().startOf('day');
    const thisWeek = moment().startOf('week');
    const thisMonth = moment().startOf('month');
    const thisYear = moment().startOf('year');
    
    // Filter sales based on role
    let filteredSales = sales;
    if (req.session.user.role === 'cashier') {
        filteredSales = sales.filter(s => s.createdBy === req.session.user.id);
    }
    
    // Today's stats
    const todaySales = filteredSales.filter(s => moment(s.createdAt).isSameOrAfter(today));
    const todayRevenue = todaySales.reduce((sum, s) => sum + s.totalAmount, 0);
    const todayTransactions = todaySales.length;
    
    // Weekly stats
    const weekSales = filteredSales.filter(s => moment(s.createdAt).isSameOrAfter(thisWeek));
    const weekRevenue = weekSales.reduce((sum, s) => sum + s.totalAmount, 0);
    
    // Monthly stats
    const monthSales = filteredSales.filter(s => moment(s.createdAt).isSameOrAfter(thisMonth));
    const monthRevenue = monthSales.reduce((sum, s) => sum + s.totalAmount, 0);
    
    // Monthly expenses
    const monthExpenses = expenses.filter(e => moment(e.date).isSameOrAfter(thisMonth));
    const totalMonthExpenses = monthExpenses.reduce((sum, e) => sum + e.amount, 0);
    
    // Product stats
    const totalProducts = products.filter(p => p.status === 'active').length;
    
    // Stock stats
    const lowStockProducts = [];
    const expiringProducts = [];
    
    products.forEach(p => {
        const productStock = stock.filter(s => s.productId === p.id && s.type === 'in');
        const totalQty = productStock.reduce((sum, s) => sum + s.quantity, 0);
        
        if (totalQty <= (p.minStock || settings.lowStockThreshold)) {
            lowStockProducts.push({
                ...p,
                currentStock: totalQty
            });
        }
        
        productStock.forEach(s => {
            if (s.expiryDate) {
                const daysToExpiry = moment(s.expiryDate).diff(moment(), 'days');
                if (daysToExpiry <= settings.expiryAlertDays && daysToExpiry > 0) {
                    expiringProducts.push({
                        productName: p.name,
                        batchNumber: s.batchNumber,
                        expiryDate: s.expiryDate,
                        daysToExpiry,
                        quantity: s.quantity
                    });
                }
            }
        });
    });
    
    // Credit/Debt stats
    const pendingCredits = creditSales.filter(cs => cs.status === 'pending');
    const totalDebts = pendingCredits.reduce((sum, cs) => sum + (cs.totalAmount - cs.paidAmount), 0);
    const collectedCredits = creditSales.reduce((sum, cs) => sum + (cs.paidAmount || 0), 0);
    
    // Top selling products (this month)
    const productSales = {};
    monthSales.forEach(sale => {
        sale.items.forEach(item => {
            if (!productSales[item.productId]) {
                productSales[item.productId] = {
                    productId: item.productId,
                    productName: item.productName,
                    totalQuantity: 0,
                    totalRevenue: 0
                };
            }
            productSales[item.productId].totalQuantity += item.quantity;
            productSales[item.productId].totalRevenue += item.total;
        });
    });
    
    const topProducts = Object.values(productSales)
        .sort((a, b) => b.totalRevenue - a.totalRevenue)
        .slice(0, 10);
    
    // Sales by day (last 7 days)
    const salesByDay = [];
    for (let i = 6; i >= 0; i--) {
        const day = moment().subtract(i, 'days');
        const daySales = filteredSales.filter(s => moment(s.createdAt).isSame(day, 'day'));
        salesByDay.push({
            date: day.format('DD/MM'),
            dayName: day.format('ddd'),
            revenue: daySales.reduce((sum, s) => sum + s.totalAmount, 0),
            transactions: daySales.length
        });
    }
    
    // Sales by month (last 12 months)
    const salesByMonth = [];
    for (let i = 11; i >= 0; i--) {
        const month = moment().subtract(i, 'months');
        const monthStart = month.clone().startOf('month');
        const monthEnd = month.clone().endOf('month');
        const monthlySales = filteredSales.filter(s => 
            moment(s.createdAt).isBetween(monthStart, monthEnd, null, '[]')
        );
        salesByMonth.push({
            month: month.format('MMM'),
            year: month.format('YYYY'),
            revenue: monthlySales.reduce((sum, s) => sum + s.totalAmount, 0),
            transactions: monthlySales.length
        });
    }
    
    res.json({
        success: true,
        data: {
            today: {
                revenue: todayRevenue,
                transactions: todayTransactions
            },
            week: {
                revenue: weekRevenue,
                transactions: weekSales.length
            },
            month: {
                revenue: monthRevenue,
                transactions: monthSales.length,
                expenses: totalMonthExpenses,
                profit: monthRevenue - totalMonthExpenses
            },
            products: {
                total: totalProducts,
                lowStock: lowStockProducts.length,
                expiring: expiringProducts.length
            },
            customers: {
                total: customers.length
            },
            debts: {
                total: totalDebts,
                count: pendingCredits.length,
                collected: collectedCredits
            },
            lowStockProducts: lowStockProducts.slice(0, 10),
            expiringProducts: expiringProducts.slice(0, 10),
            topProducts,
            salesByDay,
            salesByMonth
        }
    });
});

// API: Reports
app.get('/api/reports/sales', isAuthenticated, (req, res) => {
    const { startDate, endDate, groupBy } = req.query;
    let sales = readDB(dbFiles.sales);
    const products = readDB(dbFiles.products);
    
    // Filter by date
    if (startDate && endDate) {
        const start = moment(startDate).startOf('day');
        const end = moment(endDate).endOf('day');
        sales = sales.filter(s => moment(s.createdAt).isBetween(start, end, null, '[]'));
    }
    
    // Group sales
    let groupedData = {};
    
    if (groupBy === 'day') {
        sales.forEach(s => {
            const key = moment(s.createdAt).format('YYYY-MM-DD');
            if (!groupedData[key]) {
                groupedData[key] = { date: key, revenue: 0, transactions: 0, items: 0 };
            }
            groupedData[key].revenue += s.totalAmount;
            groupedData[key].transactions++;
            groupedData[key].items += s.items.reduce((sum, i) => sum + i.quantity, 0);
        });
    } else if (groupBy === 'product') {
        sales.forEach(s => {
            s.items.forEach(item => {
                if (!groupedData[item.productId]) {
                    groupedData[item.productId] = { 
                        productId: item.productId,
                        productName: item.productName,
                        quantity: 0, 
                        revenue: 0 
                    };
                }
                groupedData[item.productId].quantity += item.quantity;
                groupedData[item.productId].revenue += item.total;
            });
        });
    } else if (groupBy === 'category') {
        sales.forEach(s => {
            s.items.forEach(item => {
                const product = products.find(p => p.id === item.productId);
                const categoryId = product ? product.categoryId : 'unknown';
                if (!groupedData[categoryId]) {
                    groupedData[categoryId] = { categoryId, quantity: 0, revenue: 0 };
                }
                groupedData[categoryId].quantity += item.quantity;
                groupedData[categoryId].revenue += item.total;
            });
        });
    }
    
    const totalRevenue = sales.reduce((sum, s) => sum + s.totalAmount, 0);
    const totalDiscount = sales.reduce((sum, s) => sum + (s.discount || 0), 0);
    const totalTransactions = sales.length;
    
    res.json({
        success: true,
        data: {
            summary: {
                totalRevenue,
                totalDiscount,
                totalTransactions,
                averageTransaction: totalTransactions > 0 ? totalRevenue / totalTransactions : 0
            },
            groupedData: Object.values(groupedData),
            sales
        }
    });
});

app.get('/api/reports/stock', isAuthenticated, (req, res) => {
    const { branchId } = req.query;
    const stock = readDB(dbFiles.stock);
    const products = readDB(dbFiles.products);
    const categories = readDB(dbFiles.categories);
    
    let filteredStock = stock;
    if (branchId) {
        filteredStock = stock.filter(s => s.branchId === branchId);
    }
    
    // Stock by product
    const stockByProduct = {};
    products.forEach(p => {
        const productStock = filteredStock.filter(s => s.productId === p.id && s.type === 'in');
        const totalQty = productStock.reduce((sum, s) => sum + s.quantity, 0);
        const totalValue = productStock.reduce((sum, s) => sum + (s.quantity * s.costPrice), 0);
        
        const category = categories.find(c => c.id === p.categoryId);
        
        stockByProduct[p.id] = {
            productId: p.id,
            productName: p.name,
            categoryName: category ? category.name : 'N/A',
            unit: p.unit,
            quantity: totalQty,
            costValue: totalValue,
            retailValue: totalQty * p.retailPrice,
            wholesaleValue: totalQty * p.wholesalePrice,
            status: totalQty <= (p.minStock || 10) ? 'low' : 'normal'
        };
    });
    
    const totalItems = Object.values(stockByProduct).reduce((sum, p) => sum + p.quantity, 0);
    const totalCostValue = Object.values(stockByProduct).reduce((sum, p) => sum + p.costValue, 0);
    const totalRetailValue = Object.values(stockByProduct).reduce((sum, p) => sum + p.retailValue, 0);
    
    res.json({
        success: true,
        data: {
            summary: {
                totalProducts: Object.keys(stockByProduct).length,
                totalItems,
                totalCostValue,
                totalRetailValue,
                potentialProfit: totalRetailValue - totalCostValue
            },
            products: Object.values(stockByProduct)
        }
    });
});

app.get('/api/reports/purchases', isAuthenticated, (req, res) => {
    const { startDate, endDate, supplierId } = req.query;
    const allPurchases = readDB(dbFiles.purchases); // Read ALL purchases first
    const suppliers = readDB(dbFiles.suppliers);
    const supplierPayments = readDB(dbFiles.supplierPayments);
    
    // Filter purchases for display (by supplier and date)
    let purchases = [...allPurchases];
    if (supplierId) {
        purchases = purchases.filter(p => p.supplierId === supplierId);
    }
    if (startDate && endDate) {
        const start = moment(startDate).startOf('day');
        const end = moment(endDate).endOf('day');
        purchases = purchases.filter(p => moment(p.createdAt).isBetween(start, end, null, '[]'));
    }
    
    // Enrich with supplier names and payment information using FIFO
    const enrichedPurchases = purchases.map(p => {
        const supplier = suppliers.find(s => s.id === p.supplierId);
        
        // Calculate payment info for credit purchases using FIFO method
        let totalPaid = 0;
        let remainingBalance = 0;
        if (p.paymentType === 'credit') {
            // Get ALL credit purchases for this supplier (not filtered by date), sorted by date
            const allSupplierCreditPurchases = allPurchases
                .filter(pur => pur.supplierId === p.supplierId && pur.paymentType === 'credit')
                .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
            
            // Get ALL payments for this supplier (not filtered by date), sorted by date
            const allPayments = supplierPayments
                .filter(sp => sp.supplierId === p.supplierId && sp.type === 'payment')
                .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
            
            // Apply FIFO: allocate payments to purchases in chronological order
            let cumulativeDebt = 0;
            let cumulativePaid = 0;
            
            for (const purchase of allSupplierCreditPurchases) {
                if (purchase.id === p.id) {
                    // This is the purchase we're calculating for
                    const debtBeforeThis = cumulativeDebt;
                    const debtIncludingThis = cumulativeDebt + purchase.totalAmount;
                    
                    // Calculate total payments made
                    const totalPayments = allPayments.reduce((sum, pay) => sum + pay.amount, 0);
                    
                    // Calculate how much has been paid towards debts before this purchase
                    let paidBeforeThis = 0;
                    for (const pay of allPayments) {
                        if (paidBeforeThis + pay.amount <= debtBeforeThis) {
                            paidBeforeThis += pay.amount;
                        } else {
                            break;
                        }
                    }
                    
                    // Calculate how much can be allocated to this purchase
                    const availableForThis = Math.max(0, totalPayments - paidBeforeThis);
                    totalPaid = Math.min(availableForThis, purchase.totalAmount);
                    remainingBalance = Math.max(0, purchase.totalAmount - totalPaid);
                    break;
                }
                cumulativeDebt += purchase.totalAmount;
            }
        }
        
        return {
            ...p,
            supplierName: supplier ? supplier.name : 'N/A',
            totalPaid: totalPaid,
            remainingBalance: remainingBalance
        };
    });
    
    // Calculate statistics
    const totalPurchases = enrichedPurchases.reduce((sum, p) => sum + p.totalAmount, 0);
    const cashPurchases = enrichedPurchases
        .filter(p => p.paymentType === 'cash')
        .reduce((sum, p) => sum + p.totalAmount, 0);
    const creditPurchases = enrichedPurchases
        .filter(p => p.paymentType === 'credit')
        .reduce((sum, p) => sum + p.totalAmount, 0);
    const totalPaidForCredits = enrichedPurchases
        .filter(p => p.paymentType === 'credit')
        .reduce((sum, p) => sum + (p.totalPaid || 0), 0);
    const totalRemainingDebt = enrichedPurchases
        .filter(p => p.paymentType === 'credit')
        .reduce((sum, p) => sum + (p.remainingBalance || 0), 0);
    
    const uniqueSuppliers = new Set(enrichedPurchases.map(p => p.supplierId));
    const totalItems = enrichedPurchases.reduce((sum, p) => 
        sum + p.items.reduce((itemSum, item) => itemSum + item.quantity, 0), 0);
    
    res.json({
        success: true,
        data: {
            summary: {
                totalPurchases,
                totalOrders: enrichedPurchases.length,
                averageOrder: enrichedPurchases.length > 0 ? totalPurchases / enrichedPurchases.length : 0,
                cashPurchases,
                creditPurchases,
                totalPaidForCredits,
                totalRemainingDebt,
                totalSuppliers: uniqueSuppliers.size,
                totalItems
            },
            purchases: enrichedPurchases.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
        }
    });
});

app.get('/api/reports/profit-loss', isAuthenticated, hasRole('admin'), (req, res) => {
    const { startDate, endDate } = req.query;
    const sales = readDB(dbFiles.sales);
    const expenses = readDB(dbFiles.expenses);
    const stock = readDB(dbFiles.stock);
    
    let filteredSales = sales;
    let filteredExpenses = expenses;
    
    if (startDate && endDate) {
        const start = moment(startDate).startOf('day');
        const end = moment(endDate).endOf('day');
        filteredSales = sales.filter(s => moment(s.createdAt).isBetween(start, end, null, '[]'));
        filteredExpenses = expenses.filter(e => moment(e.date).isBetween(start, end, null, '[]'));
    }
    
    // Calculate revenue
    const totalRevenue = filteredSales.reduce((sum, s) => sum + s.totalAmount, 0);
    
    // Calculate cost of goods sold (approximation)
    let costOfGoodsSold = 0;
    filteredSales.forEach(sale => {
        sale.items.forEach(item => {
            // Get average cost from stock
            const productStock = stock.filter(s => s.productId === item.productId && s.costPrice);
            if (productStock.length > 0) {
                const avgCost = productStock.reduce((sum, s) => sum + s.costPrice, 0) / productStock.length;
                costOfGoodsSold += avgCost * item.quantity;
            }
        });
    });
    
    // Calculate expenses by category
    const expensesByCategory = {};
    filteredExpenses.forEach(e => {
        if (!expensesByCategory[e.category]) {
            expensesByCategory[e.category] = 0;
        }
        expensesByCategory[e.category] += e.amount;
    });
    
    const totalExpenses = filteredExpenses.reduce((sum, e) => sum + e.amount, 0);
    const grossProfit = totalRevenue - costOfGoodsSold;
    const netProfit = grossProfit - totalExpenses;
    
    res.json({
        success: true,
        data: {
            revenue: totalRevenue,
            costOfGoodsSold,
            grossProfit,
            grossProfitMargin: totalRevenue > 0 ? (grossProfit / totalRevenue * 100).toFixed(2) : 0,
            expensesByCategory,
            totalExpenses,
            netProfit,
            netProfitMargin: totalRevenue > 0 ? (netProfit / totalRevenue * 100).toFixed(2) : 0
        }
    });
});

app.get('/api/reports/creditors-debtors', isAuthenticated, (req, res) => {
    const creditSales = readDB(dbFiles.creditSales);
    const customers = readDB(dbFiles.customers);
    const sales = readDB(dbFiles.sales);
    
    const debtors = [];
    
    creditSales.filter(cs => cs.status === 'pending').forEach(cs => {
        const customer = customers.find(c => c.id === cs.customerId);
        const sale = sales.find(s => s.id === cs.saleId);
        const balance = cs.totalAmount - cs.paidAmount;
        const isOverdue = moment(cs.dueDate).isBefore(moment());
        
        debtors.push({
            customerId: cs.customerId,
            customerName: customer ? customer.name : 'N/A',
            businessName: customer ? customer.businessName : '',
            phone: customer ? customer.phone : '',
            saleId: cs.saleId,
            receiptNumber: sale ? sale.receiptNumber : 'N/A',
            totalAmount: cs.totalAmount,
            paidAmount: cs.paidAmount,
            balance,
            dueDate: cs.dueDate,
            isOverdue,
            daysOverdue: isOverdue ? moment().diff(moment(cs.dueDate), 'days') : 0,
            createdAt: cs.createdAt
        });
    });
    
    // Sort by balance descending
    debtors.sort((a, b) => b.balance - a.balance);
    
    const totalDebt = debtors.reduce((sum, d) => sum + d.balance, 0);
    const overdueDebt = debtors.filter(d => d.isOverdue).reduce((sum, d) => sum + d.balance, 0);
    
    res.json({
        success: true,
        data: {
            summary: {
                totalDebtors: debtors.length,
                totalDebt,
                overdueCount: debtors.filter(d => d.isOverdue).length,
                overdueDebt
            },
            debtors
        }
    });
});

// API: Supplier Debts and Payments
app.get('/api/supplier-debts', isAuthenticated, (req, res) => {
    const { supplierId } = req.query;
    const supplierPayments = readDB(dbFiles.supplierPayments);
    const suppliers = readDB(dbFiles.suppliers);
    const purchases = readDB(dbFiles.purchases);
    
    let debts = supplierPayments.filter(sp => sp.type === 'debt');
    
    // Filter by supplier if provided
    if (supplierId) {
        debts = debts.filter(d => d.supplierId === supplierId);
    }
    
    // Calculate balances by tracking payments against debts
    const supplierBalances = {};
    
    debts.forEach(debt => {
        if (!supplierBalances[debt.supplierId]) {
            supplierBalances[debt.supplierId] = {
                supplierId: debt.supplierId,
                totalDebt: 0,
                totalPaid: 0,
                balance: 0,
                debts: []
            };
        }
        supplierBalances[debt.supplierId].totalDebt += debt.amount;
        supplierBalances[debt.supplierId].debts.push(debt);
    });
    
    // Calculate payments
    supplierPayments.filter(sp => sp.type === 'payment').forEach(payment => {
        if (supplierBalances[payment.supplierId]) {
            supplierBalances[payment.supplierId].totalPaid += payment.amount;
        }
    });
    
    // Calculate final balances
    Object.keys(supplierBalances).forEach(supplierId => {
        supplierBalances[supplierId].balance = supplierBalances[supplierId].totalDebt - supplierBalances[supplierId].totalPaid;
        const supplier = suppliers.find(s => s.id === supplierId);
        supplierBalances[supplierId].supplierName = supplier ? supplier.name : 'N/A';
    });
    
    const supplierDebts = Object.values(supplierBalances);
    const totalDebt = supplierDebts.reduce((sum, s) => sum + s.totalDebt, 0);
    const totalPaid = supplierDebts.reduce((sum, s) => sum + s.totalPaid, 0);
    const totalBalance = supplierDebts.reduce((sum, s) => sum + s.balance, 0);
    
    res.json({
        success: true,
        data: {
            summary: {
                totalSuppliers: supplierDebts.length,
                totalDebt,
                totalPaid,
                totalBalance
            },
            suppliers: supplierDebts
        }
    });
});

app.post('/api/supplier-payments', isAuthenticated, hasRole('admin', 'storekeeper'), (req, res) => {
    const { supplierId, amount, paymentMethod, reference, notes } = req.body;
    const supplierPayments = readDB(dbFiles.supplierPayments);
    const suppliers = readDB(dbFiles.suppliers);
    const settings = readDB(dbFiles.settings);
    
    if (!supplierId || !amount) {
        return res.json({ success: false, message: 'Jaza taarifa zote' });
    }
    
    const supplier = suppliers.find(s => s.id === supplierId);
    if (!supplier) {
        return res.json({ success: false, message: 'Msambazaji hapatikani' });
    }
    
    // Calculate current debt
    const debts = supplierPayments.filter(sp => sp.type === 'debt' && sp.supplierId === supplierId);
    const payments = supplierPayments.filter(sp => sp.type === 'payment' && sp.supplierId === supplierId);
    const totalDebt = debts.reduce((sum, d) => sum + d.amount, 0);
    const totalPaid = payments.reduce((sum, p) => sum + p.amount, 0);
    const currentBalance = totalDebt - totalPaid;
    
    const paymentAmount = parseFloat(amount);
    
    // Validate payment amount
    if (paymentAmount > currentBalance) {
        return res.json({ success: false, message: `Kiasi kinazidi deni. Deni la sasa ni: ${currentBalance.toLocaleString()} TZS` });
    }
    
    // Handle custom payment method - save it if it's new
    let finalPaymentMethod = paymentMethod || 'cash';
    if (paymentMethod && !['cash', 'bank', 'mpesa', 'airtel', 'tigo', 'halopesa'].includes(paymentMethod)) {
        const normalizedMethod = paymentMethod.toLowerCase().trim().replace(/\s+/g, '_');
        finalPaymentMethod = normalizedMethod;
        
        // Add to settings if not already exists
        if (!settings.paymentMethods) {
            settings.paymentMethods = ['cash', 'bank', 'mpesa', 'airtel', 'tigo', 'halopesa'];
        }
        
        if (!settings.paymentMethods.includes(normalizedMethod)) {
            settings.paymentMethods.push(normalizedMethod);
            writeDB(dbFiles.settings, settings);
        }
    }
    
    const payment = {
        id: uuidv4(),
        supplierId,
        type: 'payment',
        amount: paymentAmount,
        paymentMethod: finalPaymentMethod,
        reference: reference || `PAY-${Date.now()}`,
        notes: notes || '',
        createdBy: req.session.user.id,
        createdAt: new Date().toISOString()
    };
    
    supplierPayments.push(payment);
    writeDB(dbFiles.supplierPayments, supplierPayments);
    
    // Calculate new balance
    const newBalance = currentBalance - paymentAmount;
    
    logActivity(req.session.user.id, 'CREATE_SUPPLIER_PAYMENT', `Payment to ${supplier.name}: ${paymentAmount} TZS. Deni jipya: ${newBalance} TZS`, req.ip);
    
    res.json({ 
        success: true, 
        message: `Malipo yameingizwa. Deni jipya: ${newBalance.toLocaleString()} TZS`, 
        data: {
            ...payment,
            previousBalance: currentBalance,
            newBalance: newBalance
        }
    });
});

app.get('/api/supplier-payments/:supplierId', isAuthenticated, (req, res) => {
    const { supplierId } = req.params;
    const supplierPayments = readDB(dbFiles.supplierPayments);
    const purchases = readDB(dbFiles.purchases);
    
    const supplierTransactions = supplierPayments.filter(sp => sp.supplierId === supplierId);
    
    // Enrich with purchase information
    const enrichedTransactions = supplierTransactions.map(trans => {
        const purchase = purchases.find(p => p.id === trans.purchaseId);
        return {
            ...trans,
            purchaseInvoice: purchase ? purchase.invoiceNumber : null
        };
    });
    
    // Sort by date descending
    enrichedTransactions.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    
    res.json({ success: true, data: enrichedTransactions });
});

// API: Barcode/QR Code generation
app.get('/api/barcode/:code', async (req, res) => {
    const { code } = req.params;
    const { type } = req.query; // 'barcode' or 'qr'
    
    try {
        if (type === 'qr') {
            const qr = await QRCode.toDataURL(code);
            res.json({ success: true, data: qr });
        } else {
            bwipjs.toBuffer({
                bcid: 'code128',
                text: code,
                scale: 3,
                height: 10,
                includetext: true,
                textxalign: 'center'
            }, (err, png) => {
                if (err) {
                    return res.json({ success: false, message: err.message });
                }
                res.set('Content-Type', 'image/png');
                res.send(png);
            });
        }
    } catch (error) {
        res.json({ success: false, message: error.message });
    }
});

// API: Backup
app.post('/api/backup', isAuthenticated, hasRole('admin'), (req, res) => {
    const timestamp = moment().format('YYYY-MM-DD_HH-mm-ss');
    const backupDir = path.join(__dirname, 'backups', timestamp);
    
    try {
        fs.mkdirSync(backupDir, { recursive: true });
        
        Object.keys(dbFiles).forEach(key => {
            if (fs.existsSync(dbFiles[key])) {
                fs.copyFileSync(dbFiles[key], path.join(backupDir, `${key}.json`));
            }
        });
        
        logActivity(req.session.user.id, 'BACKUP', `Created backup: ${timestamp}`, req.ip);
        
        res.json({ success: true, message: `Backup imefanikiwa: ${timestamp}` });
    } catch (error) {
        res.json({ success: false, message: `Backup imeshindikana: ${error.message}` });
    }
});

app.get('/api/backups', isAuthenticated, hasRole('admin'), (req, res) => {
    const backupDir = path.join(__dirname, 'backups');
    
    try {
        if (!fs.existsSync(backupDir)) {
            return res.json({ success: true, data: [] });
        }
        
        const backups = fs.readdirSync(backupDir)
            .filter(f => fs.statSync(path.join(backupDir, f)).isDirectory())
            .map(f => ({
                name: f,
                createdAt: fs.statSync(path.join(backupDir, f)).mtime
            }))
            .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
        
        res.json({ success: true, data: backups });
    } catch (error) {
        res.json({ success: false, message: error.message });
    }
});

app.post('/api/backup/restore/:name', isAuthenticated, hasRole('admin'), (req, res) => {
    const { name } = req.params;
    const backupDir = path.join(__dirname, 'backups', name);
    
    try {
        if (!fs.existsSync(backupDir)) {
            return res.json({ success: false, message: 'Backup haipo' });
        }
        
        Object.keys(dbFiles).forEach(key => {
            const backupFile = path.join(backupDir, `${key}.json`);
            if (fs.existsSync(backupFile)) {
                fs.copyFileSync(backupFile, dbFiles[key]);
            }
        });
        
        logActivity(req.session.user.id, 'RESTORE', `Restored backup: ${name}`, req.ip);
        
        res.json({ success: true, message: 'Backup imerejesha data' });
    } catch (error) {
        res.json({ success: false, message: `Restore imeshindikana: ${error.message}` });
    }
});

// Catch-all for SPA routing
app.get('*', isAuthenticated, (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'dashboard.html'));
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    const nets = os.networkInterfaces();
    const addresses = [];
    for (const name of Object.keys(nets)) {
        for (const net of nets[name] || []) {
            if (net.family === 'IPv4' && !net.internal) {
                addresses.push(net.address);
            }
        }
    }

    const lanLines = addresses.length
        ? addresses.map(ip => `║     LAN:     http://${ip}:${PORT}/login`.padEnd(63) + '║').join('\n')
        : '║     LAN:     Hakuna IP ya LAN iliyopatikana                 ║';

    console.log(`
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     🏪 HASLIM GROUP LIMITED                                  ║
║        Inventory Management System                            ║
║                                                               ║
║     Server running on port ${PORT}                            ║
║     Local:   http://localhost:${PORT}/login${' '.repeat(Math.max(0, 25 - String(PORT).length))}║
${lanLines}
║                                                               ║
║     Default Login:                                            ║
║     Username: admin                                           ║
║     Password: admin123                                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
    `);
    
    // Run periodic checks
    setInterval(checkAlerts, 60 * 60 * 1000); // Every hour
});

