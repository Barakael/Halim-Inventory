/**
 * DUKA JUMLA - Main Application JavaScript
 * Handles all frontend functionality
 */

// Global state
let currentUser = null;
let currentPage = 'dashboard';
let cart = [];
let products = [];
let categories = [];
let customers = [];
let suppliers = [];
let branches = [];

// Store original unfiltered data for search
let allProducts = [];
let allSuppliers = [];
let allCustomers = [];
let allUsers = [];
let allPurchases = [];
let allSales = [];
let allCategories = [];
let allStock = [];
let allExpenses = [];

// Pagination state
let salesCurrentPage = 1;
let salesTotalPages = 1;
let purchasesCurrentPage = 1;
let purchasesTotalPages = 1;
let productsCurrentPage = 1;
let stockCurrentPage = 1;
let categoriesCurrentPage = 1;
let customersCurrentPage = 1;
const PAGE_LIMIT = 10;
const PRODUCTS_PAGE_LIMIT = 10;
const STOCK_PAGE_LIMIT = 10;
const CATEGORIES_PAGE_LIMIT = 10;
const CUSTOMERS_PAGE_LIMIT = 10;

// Pagination callback registry — avoids embedding function source in onclick attributes
const _paginationCallbacks = {};

function renderPagination(containerId, currentPg, totalPgs, onPageChange) {
    const container = document.getElementById(containerId);
    if (!container) return;
    if (totalPgs <= 1) { container.innerHTML = ''; return; }
    // Store callback by container id so onclick can retrieve it cleanly
    _paginationCallbacks[containerId] = onPageChange;
    const prevDisabled = currentPg <= 1 ? 'disabled' : '';
    const nextDisabled = currentPg >= totalPgs ? 'disabled' : '';
    container.innerHTML = `
        <nav aria-label="Pagination">
            <ul class="pagination pagination-sm mb-0">
                <li class="page-item ${prevDisabled}">
                    <button class="page-link" onclick="_paginationCallbacks['${containerId}'](${currentPg - 1})" ${prevDisabled}>
                        <i class="bi bi-chevron-left"></i> Nyuma
                    </button>
                </li>
                <li class="page-item disabled">
                    <span class="page-link">Ukurasa ${currentPg} / ${totalPgs}</span>
                </li>
                <li class="page-item ${nextDisabled}">
                    <button class="page-link" onclick="_paginationCallbacks['${containerId}'](${currentPg + 1})" ${nextDisabled}>
                        Mbele <i class="bi bi-chevron-right"></i>
                    </button>
                </li>
            </ul>
        </nav>`;
}

// Minimal Bootstrap Modal fallback so system works even if
// Bootstrap JS CDN is not available (e.g. fully offline use).
if (typeof window !== 'undefined' && typeof window.bootstrap === 'undefined') {
    window.bootstrap = {
        Modal: class {
            constructor(element, options = {}) {
                this._element = element;
            }
            show() {
                if (this._element) {
                    this._element.classList.add('show');
                    this._element.style.display = 'block';
                }
            }
            hide() {
                if (this._element) {
                    this._element.classList.remove('show');
                    this._element.style.display = 'none';
                }
            }
            static getInstance(element) {
                return new this(element);
            }
        }
    };
}

// Delete confirmation state
let pendingDeleteAction = null;

// API Helper
async function api(endpoint, options = {}) {
    try {
        const response = await fetch(endpoint, {
            ...options,
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            }
        });
        return await response.json();
    } catch (error) {
        console.error('API Error:', error);
        showToast('Hitilafu ya mtandao', 'danger');
        return { success: false, message: 'Network error' };
    }
}

// Toast notifications
function showToast(message, type = 'success') {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = `toast show align-items-center text-white bg-${type} border-0`;
    toast.setAttribute('role', 'alert');
    toast.innerHTML = `
        <div class="d-flex">
            <div class="toast-body">
                <i class="bi bi-${type === 'success' ? 'check-circle' : 'exclamation-circle'} me-2"></i>
                ${message}
            </div>
            <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
        </div>
    `;
    container.appendChild(toast);
    
    setTimeout(() => {
        toast.remove();
    }, 5000);
}

// Format currency
function formatCurrency(amount) {
    return new Intl.NumberFormat('sw-TZ', {
        style: 'decimal',
        minimumFractionDigits: 0
    }).format(amount) + ' TZS';
}

function formatCurrencyShort(amount) {
    if (amount >= 1_000_000) return (amount / 1_000_000).toFixed(1).replace(/\.0$/, '') + 'M';
    if (amount >= 1_000) return Math.round(amount / 1_000) + 'K';
    return String(amount);
}

// Format date
function formatDate(date) {
    return new Date(date).toLocaleDateString('sw-TZ', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric'
    });
}

function formatDateTime(date) {
    return new Date(date).toLocaleString('sw-TZ', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

// Initialize application
async function initApp() {
    console.log('Initializing app...');
    
    // Check authentication
    try {
        const authResult = await api('/api/auth/me');
        console.log('Auth result:', authResult);
        
        if (!authResult.success) {
            console.log('Not authenticated, redirecting to login...');
            window.location.replace('/login');
            return;
        }
        
        currentUser = authResult.user;
        console.log('User authenticated:', currentUser);
        
        updateUserUI();
        setupNavigation();
        setupEventListeners();
        
        // Load initial data
        await loadCategories();
        await loadBranches();
        
        // Check role permissions — reveal sidebar only after filtering to prevent flash
        applyRolePermissions();
        const sidebarMenu = document.querySelector('.sidebar-menu');
        if (sidebarMenu) sidebarMenu.style.visibility = 'visible';

        // Load notifications
        loadNotifications();
        
        // Navigate to the page based on current URL
        initPageFromUrl();
        
        console.log('App initialized successfully');
    } catch (error) {
        console.error('Init error:', error);
        window.location.replace('/login');
    }
}

// Update user interface elements
function updateUserUI() {
    const userAvatar = document.querySelector('.user-avatar');
    const userName = document.querySelector('.user-name');
    const userRole = document.querySelector('.user-role');
    
    if (userAvatar) userAvatar.textContent = currentUser.fullName.charAt(0).toUpperCase();
    if (userName) userName.textContent = currentUser.fullName;
    if (userRole) {
        const roles = { 
            admin: 'Msimamizi', 
            cashier: 'Karani', 
            storekeeper: 'Mhifadhi Stoo',
            reception: 'Reception',
            store_viewer: 'Mwangaliaji Stoo'
        };
        userRole.textContent = roles[currentUser.role] || currentUser.role;
    }
}

// Apply role-based permissions
function applyRolePermissions() {
    if (!currentUser) return;
    
    const role = currentUser.role;
    
    // Special handling for store_viewer - only show store-orders and my-guide
    if (role === 'store_viewer') {
        // Hide ALL menu items first
        document.querySelectorAll('.menu-item').forEach(item => {
            item.style.display = 'none';
        });
        
        // Hide all menu categories
        document.querySelectorAll('.menu-category').forEach(category => {
            category.style.display = 'none';
        });
        
        // Only show my-guide (Agizo za Stoo hidden until feature is ready)
        // const storeOrdersMenuItem = document.querySelector('a[data-page="store-orders"]');
        const myGuideMenuItem = document.querySelector('a[data-page="my-guide"]');
        
        // if (storeOrdersMenuItem) storeOrdersMenuItem.style.display = 'block'; // TODO: re-enable when Agizo feature is ready
        if (myGuideMenuItem) myGuideMenuItem.style.display = 'block';
        
        return; // Exit early for store_viewer
    }
    
    // Show role-specific guide menu item (Mwongozo) for all roles except admin (admin uses full docs)
    const myGuideMenuItem = document.querySelector('a[data-page="my-guide"]');
    const adminDocsMenuItem = document.querySelector('a[data-page="docs"]');
    
    if (role === 'admin') {
        // Admin sees full documentation
        if (myGuideMenuItem) myGuideMenuItem.style.display = 'none';
        if (adminDocsMenuItem) adminDocsMenuItem.style.display = 'block';
    } else {
        // All other roles see role-specific guide (Mwongozo)
        if (myGuideMenuItem) myGuideMenuItem.style.display = 'block';
        if (adminDocsMenuItem) adminDocsMenuItem.style.display = 'none';
    }
    
    // TODO: Agizo pages (pending-orders, ongoing-orders, store-orders) hidden until feature is ready
    // Re-enable by uncommenting the display = 'block' lines below.
    const pendingOrdersMenuItem = document.querySelector('a[data-page="pending-orders"]');
    if (pendingOrdersMenuItem) pendingOrdersMenuItem.style.display = 'none';
    // if (pendingOrdersMenuItem && (role === 'cashier' || role === 'admin')) pendingOrdersMenuItem.style.display = 'block';

    const ongoingOrdersMenuItem = document.querySelector('a[data-page="ongoing-orders"]');
    if (ongoingOrdersMenuItem) ongoingOrdersMenuItem.style.display = 'none';
    // if (ongoingOrdersMenuItem && role !== 'store_viewer') ongoingOrdersMenuItem.style.display = 'block';

    const storeOrdersMenuItem = document.querySelector('a[data-page="store-orders"]');
    if (storeOrdersMenuItem) storeOrdersMenuItem.style.display = 'none';
    // if (storeOrdersMenuItem && (role === 'admin')) storeOrdersMenuItem.style.display = 'block';
    
    // Hide credits menu for reception
    const creditsMenuItem = document.querySelector('a[data-page="credits"]');
    if (creditsMenuItem) {
        if (role === 'reception') {
            creditsMenuItem.style.display = 'none';
        }
    }

    // Storekeeper and reception don't use the dashboard — hide the link
    const dashboardMenuItem = document.querySelector('a[data-page="dashboard"]');
    if (dashboardMenuItem && (role === 'storekeeper' || role === 'reception')) {
        dashboardMenuItem.style.display = 'none';
    }
    
    // Hide menu items based on role
    document.querySelectorAll('[data-role]').forEach(el => {
        const allowedRoles = el.dataset.role.split(',');
        if (!allowedRoles.includes(role)) {
            el.style.display = 'none';
        }
    });
}

// Setup navigation
function setupNavigation() {
    document.querySelectorAll('.menu-item[data-page]').forEach(item => {
        item.addEventListener('click', function(e) {
            e.preventDefault();
            const page = this.dataset.page;
            navigateTo(page, true);
        });
    });
    
    // Handle browser back/forward buttons
    window.addEventListener('popstate', function(e) {
        const page = getPageFromUrl();
        navigateTo(page, false);
    });
}

// Get page name from current URL
function getPageFromUrl() {
    const path = window.location.pathname;
    const page = path.substring(1) || 'dashboard'; // Remove leading slash
    return page;
}

// Initialize page based on URL
function initPageFromUrl() {
    let page = getPageFromUrl();
    
    // Redirect store_viewer to store-orders if accessing unauthorized page or dashboard
    if (currentUser && currentUser.role === 'store_viewer') {
        const allowedPages = ['store-orders', 'my-guide'];
        if (!allowedPages.includes(page) || page === 'dashboard' || page === '') {
            page = 'store-orders';
        }
    }

    // Storekeeper and reception don't have a dashboard — redirect to their main page
    if (currentUser && currentUser.role === 'storekeeper') {
        if (page === 'dashboard' || page === '') page = 'stock';
    }
    if (currentUser && currentUser.role === 'reception') {
        if (page === 'dashboard' || page === '') page = 'pos';
    }
    
    navigateTo(page, false);
}

// Navigate to page
function navigateTo(page, updateUrl = true) {
    // Redirect settings sub-pages to the settings page
    const settingsSubPages = ['branches', 'logs'];
    const stockSubPages = ['products', 'categories'];
    let effectivePage = settingsSubPages.includes(page) ? 'settings' : page;
    if (stockSubPages.includes(page)) effectivePage = 'stock';

    // Update active menu item
    document.querySelectorAll('.menu-item').forEach(item => {
        item.classList.remove('active');
        if (item.dataset.page === effectivePage) {
            item.classList.add('active');
        }
    });
    
    // Check if store_viewer is trying to access unauthorized pages
    if (currentUser && currentUser.role === 'store_viewer') {
        const allowedPages = ['store-orders', 'my-guide'];
        if (!allowedPages.includes(page)) {
            navigateTo('store-orders', true);
            showToast('Huna ruhusa ya kuona ukurasa huu. Unaweza kuona tu "Agizo za Stoo" na "Mwongozo"', 'warning');
            return;
        }
    }
    
    // Show active page section
    document.querySelectorAll('.page-section').forEach(section => {
        section.classList.remove('active');
    });
    
    const targetSection = document.getElementById(`page-${effectivePage}`);
    if (targetSection) {
        targetSection.classList.add('active');
    } else {
        // If page doesn't exist or user doesn't have access, redirect appropriately
        if (currentUser && currentUser.role === 'reception' && page === 'credits') {
            navigateTo('dashboard', true);
            showToast('Huna ruhusa ya kuona ukurasa huu', 'warning');
            return;
        }
        if (currentUser && currentUser.role === 'store_viewer') {
            navigateTo('store-orders', true);
            showToast('Huna ruhusa ya kuona ukurasa huu', 'warning');
            return;
        }
    }
    
    // Update page title
    const titles = {
        dashboard: 'Dashboard',
        pos: 'Point of Sale',
        products: 'Stoo',
        categories: 'Stoo',
        stock: 'Stoo',
        sales: 'Mauzo',
        purchases: 'Manunuzi',
        suppliers: 'Wasambazaji',
        customers: 'Wateja',
        credits: 'Madeni',
        expenses: 'Matumizi',
        'ongoing-orders': 'Agizo za Endelea',
        'pending-orders': 'Agizo za Kuthibitisha',
        'store-orders': 'Agizo za Stoo',
        reports: 'Ripoti',
        'my-guide': 'Mwongozo',
        docs: 'Mwongozo (Admin)',
        branches: 'Mipangilio',
        users: 'Watumiaji',
        settings: 'Mipangilio',
        logs: 'Mipangilio',
    };
    
    const pageTitle = titles[page] || page;
    document.querySelector('.page-title').textContent = pageTitle;
    document.title = `${pageTitle} - HASLIM GROUP`;
    currentPage = page;
    
    // Update URL without page reload
    if (updateUrl) {
        const newUrl = `/${page}`;
        window.history.pushState({ page: page }, pageTitle, newUrl);
    }
    
    // Load page-specific data
    loadPageData(page);
    
    // Close sidebar on mobile
    document.querySelector('.sidebar')?.classList.remove('show');
    document.querySelector('.sidebar-overlay')?.classList.remove('show');
}

// Load page-specific data
async function loadPageData(page) {
    switch(page) {
        case 'dashboard':
            await loadDashboard();
            break;
        case 'pos':
            await loadPOS();
            break;
        case 'products':
            switchStockTab('bidhaa');
            await loadProducts();
            break;
        case 'categories':
            switchStockTab('kategoria');
            await loadCategoriesList();
            break;
        case 'stock':
            switchStockTab('bidhaa');
            await loadProducts();
            break;
        case 'sales':
            await loadSales();
            break;
        case 'purchases':
            await loadPurchases();
            break;
        case 'suppliers':
            await loadSuppliers();
            break;
        case 'customers':
            await loadCustomers();
            break;
        case 'credits':
            // Check if user has permission (not reception)
            if (currentUser && currentUser.role === 'reception') {
                navigateTo('dashboard', true);
                showToast('Huna ruhusa ya kuona ukurasa huu', 'warning');
                return;
            }
            await loadCredits();
            break;
        case 'expenses':
            await loadExpenses();
            break;
        case 'ongoing-orders':
            await loadOngoingOrders();
            break;
        case 'pending-orders':
            await loadPendingOrders();
            break;
        case 'store-orders':
            await loadStoreOrders();
            break;
        case 'reports':
            await loadReports();
            break;
        case 'branches':
            switchSettingsTab('branches');
            await loadBranchesList();
            break;
        case 'users':
            await loadUsers();
            break;
        case 'logs':
            switchSettingsTab('logs');
            await loadActivityLogs();
            break;
        case 'settings':
            switchSettingsTab('general');
            await loadSettings();
            break;
        case 'docs':
            // Full documentation for admin
            break;
        case 'my-guide':
            await loadRoleSpecificGuide();
            break;
    }
}

// Setup event listeners
// =========================
// SETTINGS TABS
// =========================
function switchSettingsTab(tab) {
    // Make sure settings page is showing
    const settingsPage = document.getElementById('page-settings');
    if (settingsPage && !settingsPage.classList.contains('active')) {
        document.querySelectorAll('.page-section').forEach(s => s.classList.remove('active'));
        settingsPage.classList.add('active');
        document.querySelectorAll('.menu-item').forEach(item => {
            item.classList.toggle('active', item.dataset.page === 'settings');
        });
    }

    const panes = ['general', 'branches', 'logs'];
    panes.forEach(p => {
        const pane = document.getElementById(`settingsPane-${p}`);
        const tabEl = document.getElementById(`settingsTab-${p}`);
        if (pane) pane.style.display = p === tab ? '' : 'none';
        if (tabEl) tabEl.classList.toggle('active', p === tab);
    });

    // Load data for the selected tab
    if (tab === 'branches') loadBranchesList();
    if (tab === 'logs') loadActivityLogs();
}

function switchStockTab(tab) {
    // Make sure stock page is showing
    const stockPage = document.getElementById('page-stock');
    if (stockPage && !stockPage.classList.contains('active')) {
        document.querySelectorAll('.page-section').forEach(s => s.classList.remove('active'));
        stockPage.classList.add('active');
        document.querySelectorAll('.menu-item').forEach(item => {
            item.classList.toggle('active', item.dataset.page === 'stock');
        });
    }

    const panes = ['bidhaa', 'stoo', 'kategoria'];
    panes.forEach(p => {
        const pane = document.getElementById(`stockPane-${p}`);
        const tabEl = document.getElementById(`stockTab-${p}`);
        if (pane) pane.style.display = p === tab ? '' : 'none';
        if (tabEl) tabEl.classList.toggle('active', p === tab);
    });

    // Load data for the selected tab
    if (tab === 'bidhaa') loadProducts();
    if (tab === 'stoo') loadStock();
    if (tab === 'kategoria') loadCategoriesList();
}

function toggleFullscreen() {
    if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen().catch(() => {});
    } else {
        document.exitFullscreen();
    }
}

document.addEventListener('fullscreenchange', () => {
    const icon = document.getElementById('fullscreenIcon');
    if (!icon) return;
    if (document.fullscreenElement) {
        icon.className = 'bi bi-fullscreen-exit';
        document.getElementById('fullscreenBtn').title = 'Exit Full Screen';
    } else {
        icon.className = 'bi bi-fullscreen';
        document.getElementById('fullscreenBtn').title = 'Full Screen';
    }
});

function setupEventListeners() {
    // Sidebar toggle
    document.querySelector('.toggle-sidebar')?.addEventListener('click', () => {
        document.querySelector('.sidebar').classList.toggle('show');
        document.querySelector('.sidebar-overlay').classList.toggle('show');
    });
    
    document.querySelector('.sidebar-overlay')?.addEventListener('click', () => {
        document.querySelector('.sidebar').classList.remove('show');
        document.querySelector('.sidebar-overlay').classList.remove('show');
    });
    
    // Logout
    document.getElementById('btnLogout')?.addEventListener('click', async () => {
        if (confirm('Una uhakika unataka kutoka?')) {
            await api('/api/auth/logout', { method: 'POST' });
            window.location.href = '/login';
        }
    });
    
    // Notification button
    document.getElementById('notificationBtn')?.addEventListener('click', () => {
        document.getElementById('notificationPanel').classList.toggle('show');
    });
    
    // Close notification panel when clicking outside
    document.addEventListener('click', (e) => {
        const panel = document.getElementById('notificationPanel');
        const btn = document.getElementById('notificationBtn');
        if (panel && btn && !panel.contains(e.target) && !btn.contains(e.target)) {
            panel.classList.remove('show');
        }
    });
}

// =========================
// DASHBOARD
// =========================
async function loadDashboard() {
    // Only admin and cashier can see dashboard
    const role = currentUser && currentUser.role;
    if (role === 'storekeeper') {
        navigateTo('stock', true);
        return;
    }
    if (role === 'reception') {
        navigateTo('pos', true);
        return;
    }
    if (role === 'store_viewer') {
        navigateTo('store-orders', true);
        return;
    }

    const result = await api('/api/dashboard/stats');
    if (!result.success) return;

    let data = result.data;

    // Cashier sees only their own sales figures
    const isCashier = role === 'cashier';
    if (isCashier) {
        // Filter today/week/month stats to cashier's own sales
        const salesResult = await api('/api/sales');
        const allSales = salesResult.success ? salesResult.data : [];
        const mySales = allSales.filter(s => s.cashierId === currentUser.id || s.cashierName === currentUser.fullName);
        const today = new Date(); today.setHours(0,0,0,0);
        const weekAgo = new Date(); weekAgo.setDate(weekAgo.getDate() - 7); weekAgo.setHours(0,0,0,0);
        const monthAgo = new Date(); monthAgo.setDate(1); monthAgo.setHours(0,0,0,0);
        const sum = arr => arr.reduce((t, s) => t + (s.totalAmount || 0), 0);
        const todaySales = mySales.filter(s => new Date(s.createdAt) >= today);
        const weekSales  = mySales.filter(s => new Date(s.createdAt) >= weekAgo);
        const monthSales = mySales.filter(s => new Date(s.createdAt) >= monthAgo);
        data = { ...data,
            today: { revenue: sum(todaySales), transactions: todaySales.length },
            week:  { revenue: sum(weekSales) },
            month: { revenue: sum(monthSales), profit: 0 }
        };
    }

    // Hide financial information for Reception role
    const isReception = false; // reception is redirected above, kept for safety
    
    // Hide financial stat cards for Reception
    const todayRevenueCard = document.getElementById('todayRevenueCard');
    const weekRevenueCard = document.getElementById('weekRevenueCard');
    const monthRevenueCard = document.getElementById('monthRevenueCard');
    const monthlyChartCard = document.getElementById('monthlyChartCard');
    const debtsChartCard = document.getElementById('debtsChartCard');
    const topProductsCard = document.getElementById('topProductsCard');
    const revenueColumnHeader = document.querySelector('#topProductsHeader .revenue-column');
    
    if (isReception) {
        if (todayRevenueCard) todayRevenueCard.style.display = 'none';
        if (weekRevenueCard) weekRevenueCard.style.display = 'none';
        if (monthRevenueCard) monthRevenueCard.style.display = 'none';
        if (monthlyChartCard) monthlyChartCard.style.display = 'none';
        if (debtsChartCard) debtsChartCard.style.display = 'none';
        if (topProductsCard) topProductsCard.style.display = 'none';
    } else {
        // Show and update financial stat cards for other roles
        if (todayRevenueCard) todayRevenueCard.style.display = '';
        if (weekRevenueCard) weekRevenueCard.style.display = '';
        if (monthRevenueCard) monthRevenueCard.style.display = '';
        if (monthlyChartCard) monthlyChartCard.style.display = '';
        if (debtsChartCard) debtsChartCard.style.display = '';
        if (topProductsCard) topProductsCard.style.display = '';
        
        // Update financial stat cards for other roles
        if (document.getElementById('todayRevenue')) {
            document.getElementById('todayRevenue').textContent = formatCurrency(data.today.revenue);
            document.getElementById('todayTransactions').textContent = data.today.transactions;
        }
        if (document.getElementById('weekRevenue')) {
            document.getElementById('weekRevenue').textContent = formatCurrency(data.week.revenue);
        }
        if (document.getElementById('monthRevenue')) {
            document.getElementById('monthRevenue').textContent = formatCurrency(data.month.revenue);
            document.getElementById('monthProfit').textContent = formatCurrency(data.month.profit);
        }

        // ── 3-Month Revenue Chart ─────────────────────────────────
        const monthlyChartEl = document.getElementById('monthlyRevenueChart');
        if (monthlyChartEl) {
            const last3 = (data.salesByMonth || []).slice(-3);
            const maxVal = Math.max(...last3.map(m => m.revenue), 1);
            monthlyChartEl.innerHTML = `
                <div class="mini-bar-chart">
                    ${last3.map(m => {
                        const pct = Math.max(4, Math.round((m.revenue / maxVal) * 100));
                        return `
                            <div class="mini-bar-col">
                                <div class="mini-bar-value">${formatCurrencyShort(m.revenue)}</div>
                                <div class="mini-bar" style="height:${pct}%;"></div>
                                <div class="mini-bar-label">${m.month} ${m.year}</div>
                            </div>`;
                    }).join('')}
                </div>`;
        }

        // ── Madeni vs Makusanyo Chart ─────────────────────────────
        const debtsChartEl = document.getElementById('debtsVsCollectedChart');
        if (debtsChartEl) {
            const outstanding = data.debts.total || 0;
            const collected = data.debts.collected || 0;
            const maxVal = Math.max(outstanding, collected, 1);
            const outPct = Math.max(2, Math.round((outstanding / maxVal) * 100));
            const colPct = Math.max(2, Math.round((collected / maxVal) * 100));
            debtsChartEl.innerHTML = `
                <div class="hbar-chart">
                    <div class="hbar-row">
                        <div class="hbar-label-row">
                            <span><i class="bi bi-cash-coin me-1" style="color:#0d6efd;"></i>Makusanyo</span>
                            <span style="color:#0d6efd;font-weight:700;">${formatCurrency(collected)}</span>
                        </div>
                        <div class="hbar-track">
                            <div class="hbar-fill hbar-blue" style="width:${colPct}%;"></div>
                        </div>
                    </div>
                    <div class="hbar-row">
                        <div class="hbar-label-row">
                            <span><i class="bi bi-exclamation-circle me-1" style="color:#e6a800;"></i>Madeni Baki</span>
                            <span style="color:#e6a800;font-weight:700;">${formatCurrency(outstanding)}</span>
                        </div>
                        <div class="hbar-track">
                            <div class="hbar-fill hbar-yellow" style="width:${outPct}%;"></div>
                        </div>
                    </div>
                    <div class="hbar-footer">
                        Wanadaiwa: <strong>${data.debts.count}</strong> &nbsp;|&nbsp; Jumla ya Mkopo: <strong>${formatCurrency(outstanding + collected)}</strong>
                    </div>
                </div>`;
        }
    }
    
    // Always update non-financial stats
    if (document.getElementById('lowStockCount')) {
        document.getElementById('lowStockCount').textContent = data.products.lowStock;
    }
    
    // Low stock alerts — primary blue colors
    const lowStockList = document.getElementById('lowStockList');
    if (lowStockList) {
        const lsItems = data.lowStockProducts || [];
        lowStockList.innerHTML = lsItems.length
            ? lsItems.map(p => `
                <div class="alert-item low-stock">
                    <div>
                        <strong>${p.name}</strong>
                        <div class="text-muted small">Stock: ${p.currentStock} ${p.unit || 'pcs'}</div>
                    </div>
                    <span class="badge bg-primary">${p.currentStock}</span>
                </div>`).join('')
            : '<p class="text-muted text-center py-3 mb-0">Hakuna bidhaa zenye stock chini</p>';
    }

    // Top products — show first 3 rows; reveal footer if there are more
    const topProductsList = document.getElementById('topProductsList');
    const topProductsFooter = document.getElementById('topProductsFooter');
    const topProductsMeta = document.getElementById('topProductsMeta');
    if (topProductsList && !isReception) {
        const all = data.topProducts || [];
        const visible = all.slice(0, 3);
        const medalColors = ['text-warning', 'text-secondary', 'text-danger'];
        topProductsList.innerHTML = visible.length
            ? visible.map((p, i) => `
                <tr>
                    <td><i class="bi bi-trophy-fill ${medalColors[i] || 'text-muted'}"></i> ${i + 1}</td>
                    <td><strong>${p.productName}</strong></td>
                    <td>${p.totalQuantity}</td>
                    <td>${formatCurrency(p.totalRevenue)}</td>
                </tr>`).join('')
            : '<tr><td colspan="4" class="text-center text-muted py-3">Hakuna data</td></tr>';
        if (topProductsMeta) topProductsMeta.textContent = all.length > 3 ? `Top 3 kati ya ${all.length}` : '';
        if (topProductsFooter) topProductsFooter.style.display = all.length > 3 ? '' : 'none';
    }
    
    // Sales chart - hide for Reception
    if (window.salesChart && !isReception) {
        window.salesChart.data.labels = data.salesByDay.map(d => d.dayName);
        window.salesChart.data.datasets[0].data = data.salesByDay.map(d => d.revenue);
        window.salesChart.update();
    }
}

// =========================
// PRODUCTS
// =========================
async function loadProducts() {
    const result = await api('/api/products');
    if (!result.success) {
        console.error('Failed to load products:', result.message);
        products = [];
        return;
    }
    
    products = result.data || [];
    allProducts = [...products]; // Store original data for search
    
    // Load suppliers for product modal dropdown
    await loadSuppliers();
    
    renderProductsTable();
}

function filterProductsTable() {
    const searchInput = document.getElementById('productsSearchInput');
    if (!searchInput) return;
    
    const searchTerm = searchInput.value.toLowerCase().trim();
    
    if (searchTerm === '') {
        products = [...allProducts];
    } else {
        products = allProducts.filter(p => {
            const searchText = `${p.name || ''} ${p.sku || ''} ${p.categoryName || ''}`.toLowerCase();
            return searchText.includes(searchTerm);
        });
    }
    
    productsCurrentPage = 1;
    renderProductsTable(1);
}

function renderProductsTable(page = productsCurrentPage) {
    const tbody = document.getElementById('productsTableBody');
    if (!tbody) return;

    productsCurrentPage = page;
    const totalPages = Math.max(1, Math.ceil(products.length / PRODUCTS_PAGE_LIMIT));
    const start = (page - 1) * PRODUCTS_PAGE_LIMIT;
    const pageItems = products.slice(start, start + PRODUCTS_PAGE_LIMIT);

    if (pageItems.length === 0) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">Hakuna matokeo yaliyopatikana</td></tr>';
        renderPagination('productsPagination', 1, 1, renderProductsTable);
        return;
    }

    tbody.innerHTML = pageItems.map(p => `
        <tr>
            <td>${p.sku}</td>
            <td>${p.name}</td>
            <td>${p.categoryName}</td>
            <td>${formatCurrency(p.wholesalePrice)}</td>
            <td>${formatCurrency(p.retailPrice)}</td>
            <td>${p.unit}</td>
            <td>
                <span class="badge ${p.currentStock <= p.minStock ? 'bg-danger' : 'bg-success'}">
                    ${p.currentStock}
                </span>
            </td>
            <td>
                <div class="dropdown">
                    <button class="btn btn-sm btn-outline-secondary" type="button" data-bs-toggle="dropdown" data-bs-boundary="viewport" data-bs-strategy="fixed" aria-expanded="false" title="Vitendo">
                        <i class="bi bi-three-dots-vertical"></i>
                    </button>
                    <ul class="dropdown-menu dropdown-menu-end">
                        <li><a class="dropdown-item text-success" href="#" onclick="event.preventDefault();showStockInModal('${p.id}')"><i class="bi bi-plus-circle me-2"></i>Ongeza Stock</a></li>
                        <li><a class="dropdown-item" href="#" onclick="event.preventDefault();editProduct('${p.id}')"><i class="bi bi-pencil me-2"></i>Hariri</a></li>
                        <li><hr class="dropdown-divider"></li>
                        <li><a class="dropdown-item text-danger" href="#" onclick="event.preventDefault();deleteProduct('${p.id}')"><i class="bi bi-trash me-2"></i>Futa</a></li>
                    </ul>
                </div>
            </td>
        </tr>
    `).join('');

    renderPagination('productsPagination', page, totalPages, renderProductsTable);
}

async function saveProduct() {
    const form = document.getElementById('productForm');
    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());
    
    const productId = document.getElementById('productId').value;
    const url = productId ? `/api/products/${productId}` : '/api/products';
    const method = productId ? 'PUT' : 'POST';
    
    const result = await api(url, { method, body: JSON.stringify(data) });
    
    if (result.success) {
        showToast(result.message);
        bootstrap.Modal.getInstance(document.getElementById('productModal')).hide();
        form.reset();
        await loadProducts();
    } else {
        showToast(result.message, 'danger');
    }
}

async function showAddProductModal() {
    try {
        document.getElementById('productId').value = '';
        document.getElementById('productForm').reset();
        document.getElementById('productModalLabel').textContent = 'Ongeza Bidhaa';
        
        // Load categories first (synchronous)
        loadCategoryOptions('productCategory');
        
        // Load suppliers (async)
        await loadSupplierOptions('productSupplier');
        
        const modalElement = document.getElementById('productModal');
        const modal = new bootstrap.Modal(modalElement);
        modal.show();
    } catch (error) {
        console.error('Error opening product modal:', error);
        showToast('Hitilafu katika kufungua fomu ya bidhaa', 'danger');
    }
}

async function editProduct(id) {
    const product = products.find(p => p.id === id);
    if (!product) return;
    
    document.getElementById('productId').value = product.id;
    document.getElementById('productName').value = product.name;
    document.getElementById('productSku').value = product.sku;
    document.getElementById('productBarcode').value = product.barcode;
    document.getElementById('productWholesalePrice').value = product.wholesalePrice;
    document.getElementById('productRetailPrice').value = product.retailPrice;
    document.getElementById('productUnit').value = product.unit;
    document.getElementById('productMinStock').value = product.minStock;
    document.getElementById('productDescription').value = product.description || '';
    
    await loadCategoryOptions('productCategory');
    await loadSupplierOptions('productSupplier');
    
    document.getElementById('productCategory').value = product.categoryId;
    document.getElementById('productSupplier').value = product.supplierId || '';
    
    document.getElementById('productModalLabel').textContent = 'Hariri Bidhaa';
    new bootstrap.Modal(document.getElementById('productModal')).show();
}

async function deleteProduct(id) {
    if (!confirm('Una uhakika unataka kufuta bidhaa hii?')) return;
    
    const result = await api(`/api/products/${id}`, { method: 'DELETE' });
    if (result.success) {
        showToast(result.message);
        await loadProducts();
    } else {
        showToast(result.message, 'danger');
    }
}

// =========================
// CATEGORIES
// =========================
async function loadCategories() {
    const result = await api('/api/categories');
    if (result.success) {
        categories = result.data;
    }
}

async function loadCategoriesList() {
    await loadCategories();
    allCategories = [...categories]; // Store original data for search
    
    renderCategoriesTable();
}

function filterCategoriesTable() {
    const searchInput = document.getElementById('categoriesSearchInput');
    if (!searchInput || !allCategories) return;
    
    const searchTerm = searchInput.value.toLowerCase().trim();
    
    if (searchTerm === '') {
        categories = [...allCategories];
    } else {
        categories = allCategories.filter(c => {
            const searchText = `${c.name || ''} ${c.description || ''}`.toLowerCase();
            return searchText.includes(searchTerm);
        });
    }

    categoriesCurrentPage = 1;
    renderCategoriesTable(1);
}

function renderCategoriesTable(page = categoriesCurrentPage) {
    const tbody = document.getElementById('categoriesTableBody');
    if (!tbody) return;

    categoriesCurrentPage = page;
    const totalPages = Math.max(1, Math.ceil(categories.length / CATEGORIES_PAGE_LIMIT));
    const start = (page - 1) * CATEGORIES_PAGE_LIMIT;
    const pageItems = categories.slice(start, start + CATEGORIES_PAGE_LIMIT);

    if (pageItems.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" class="text-center text-muted">Hakuna matokeo yaliyopatikana</td></tr>';
        renderPagination('categoriesPagination', 1, 1, renderCategoriesTable);
        return;
    }

    tbody.innerHTML = pageItems.map(c => `
        <tr>
            <td>${c.name}</td>
            <td>${c.description || '-'}</td>
            <td>
                <span class="status-dot ${c.status === 'active' ? 'active' : 'inactive'}"></span>
                ${c.status === 'active' ? 'Active' : 'Inactive'}
            </td>
            <td>
                <button class="btn btn-sm btn-primary btn-icon me-1" onclick="editCategory('${c.id}')" title="Hariri">
                    <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-danger btn-icon" onclick="deleteCategory('${c.id}')" title="Futa">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        </tr>
    `).join('');

    renderPagination('categoriesPagination', page, totalPages, renderCategoriesTable);
}

function loadCategoryOptions(selectId) {
    const select = document.getElementById(selectId);
    if (!select) return;
    
    select.innerHTML = '<option value="">Chagua Kategoria</option>' + 
        categories.filter(c => c.status === 'active').map(c => 
            `<option value="${c.id}">${c.name}</option>`
        ).join('');
}

async function saveCategory() {
    const form = document.getElementById('categoryForm');
    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());
    
    const categoryId = document.getElementById('categoryId').value;
    const url = categoryId ? `/api/categories/${categoryId}` : '/api/categories';
    const method = categoryId ? 'PUT' : 'POST';
    
    const result = await api(url, { method, body: JSON.stringify(data) });
    
    if (result.success) {
        showToast(result.message);
        bootstrap.Modal.getInstance(document.getElementById('categoryModal')).hide();
        form.reset();
        await loadCategoriesList();
    } else {
        showToast(result.message, 'danger');
    }
}

function showAddCategoryModal() {
    document.getElementById('categoryId').value = '';
    document.getElementById('categoryForm').reset();
    document.getElementById('categoryModalLabel').textContent = 'Ongeza Kategoria';
    new bootstrap.Modal(document.getElementById('categoryModal')).show();
}

function editCategory(id) {
    const category = categories.find(c => c.id === id);
    if (!category) return;
    
    document.getElementById('categoryId').value = category.id;
    document.getElementById('categoryName').value = category.name;
    document.getElementById('categoryDescription').value = category.description || '';
    document.getElementById('categoryStatus').value = category.status;
    
    document.getElementById('categoryModalLabel').textContent = 'Hariri Kategoria';
    new bootstrap.Modal(document.getElementById('categoryModal')).show();
}

async function deleteCategory(id) {
    if (!confirm('Una uhakika unataka kufuta kategoria hii?')) return;
    
    const result = await api(`/api/categories/${id}`, { method: 'DELETE' });
    if (result.success) {
        showToast(result.message);
        await loadCategoriesList();
    } else {
        showToast(result.message, 'danger');
    }
}

// =========================
// STOCK
// =========================
async function loadStock() {
    const result = await api('/api/stock');
    if (!result.success) return;
    
    // Group stock by product
    const stockByProduct = {};
    result.data.filter(s => s.type === 'in').forEach(s => {
        if (!stockByProduct[s.productId]) {
            stockByProduct[s.productId] = {
                productId: s.productId,
                productName: s.productName,
                unit: s.unit,
                quantity: 0,
                batches: []
            };
        }
        stockByProduct[s.productId].quantity += s.quantity;
        stockByProduct[s.productId].batches.push(s);
    });
    
    const stockData = Object.values(stockByProduct);
    allStock = [...stockData]; // Store original data for search
    
    renderStockTable();
}

function filterStockTable() {
    const searchInput = document.getElementById('stockSearchInput');
    if (!searchInput || !allStock) return;
    
    const searchTerm = searchInput.value.toLowerCase().trim();
    
    if (searchTerm === '') {
        stockCurrentPage = 1;
        renderStockTableWithData(allStock, 1);
    } else {
        const filtered = allStock.filter(s => {
            const searchText = `${s.productName || ''}`.toLowerCase();
            return searchText.includes(searchTerm);
        });
        stockCurrentPage = 1;
        renderStockTableWithData(filtered, 1);
    }
}

function renderStockTable() {
    renderStockTableWithData(allStock, stockCurrentPage);
}

function renderStockTableWithData(stockData, page = stockCurrentPage) {
    const tbody = document.getElementById('stockTableBody');
    if (!tbody) return;

    stockCurrentPage = page;
    const totalPages = Math.max(1, Math.ceil((stockData || []).length / STOCK_PAGE_LIMIT));
    const start = (page - 1) * STOCK_PAGE_LIMIT;
    const pageItems = (stockData || []).slice(start, start + STOCK_PAGE_LIMIT);

    if (pageItems.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" class="text-center text-muted">Hakuna matokeo yaliyopatikana</td></tr>';
        renderPagination('stockPagination', 1, 1, (p) => renderStockTableWithData(stockData, p));
        return;
    }

    tbody.innerHTML = pageItems.map(s => `
        <tr>
            <td>${s.productName}</td>
            <td>${s.quantity} ${s.unit}</td>
            <td>${s.batches.length}</td>
            <td>
                <button class="btn btn-sm btn-success btn-icon" onclick="showStockInModal('${s.productId}')" title="Stock In">
                    <i class="bi bi-plus"></i>
                </button>
            </td>
        </tr>
    `).join('');

    renderPagination('stockPagination', page, totalPages, (p) => renderStockTableWithData(stockData, p));
}

async function saveStockIn() {
    const form = document.getElementById('stockInForm');
    const productId = document.getElementById('stockProductId').value;
    
    if (!productId) {
        showToast('Tafadhali chagua bidhaa', 'danger');
        return;
    }
    
    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());
    data.productId = productId; // Ensure productId is set
    
    const result = await api('/api/stock/in', { 
        method: 'POST', 
        body: JSON.stringify(data) 
    });
    
    if (result.success) {
        showToast(result.message);
        bootstrap.Modal.getInstance(document.getElementById('stockInModal')).hide();
        form.reset();
        document.getElementById('stockProductId').value = '';
        document.getElementById('stockProductSearch').value = '';
        await loadStock();
    } else {
        showToast(result.message, 'danger');
    }
}

async function showStockInModal(productId = '') {
    document.getElementById('stockInForm').reset();
    document.getElementById('stockProductId').value = '';
    document.getElementById('stockProductSearch').value = '';
    document.getElementById('stockInProductList').innerHTML = '';
    document.getElementById('stockInProductList').style.display = 'none';
    
    // Ensure products are loaded
    if (!products || products.length === 0) {
        await loadProducts();
    }
    
    // If productId is provided, pre-select it
    if (productId) {
        const product = products.find(p => p.id === productId);
        if (product) {
            document.getElementById('stockProductId').value = product.id;
            document.getElementById('stockProductSearch').value = `${product.name} (${product.currentStock || 0} ${product.unit || 'pcs'})`;
        }
    }
    
    new bootstrap.Modal(document.getElementById('stockInModal')).show();
}

let stockInProducts = [];

function showStockInProductList() {
    const list = document.getElementById('stockInProductList');
    if (list && list.innerHTML.trim() !== '') {
        list.style.display = 'block';
    }
}

function hideStockInProductList() {
    const list = document.getElementById('stockInProductList');
    if (list) {
        list.style.display = 'none';
    }
}

function filterStockInProducts(searchTerm) {
    const list = document.getElementById('stockInProductList');
    const hiddenInput = document.getElementById('stockProductId');
    if (!list || !hiddenInput) return;
    
    // If search is cleared, clear selection
    if (!searchTerm || searchTerm.trim() === '') {
        hiddenInput.value = '';
        list.innerHTML = '';
        list.style.display = 'none';
        return;
    }
    
    const term = searchTerm.toLowerCase().trim();
    
    // Filter active products
    const activeProducts = products.filter(p => p.status === 'active');
    
    // Filter by search term
    const filtered = activeProducts.filter(p => {
        const searchText = `${p.name || ''} ${p.sku || ''}`.toLowerCase();
        return searchText.includes(term);
    });
    
    stockInProducts = filtered;
    
    if (filtered.length === 0) {
        list.innerHTML = '<div class="dropdown-item-text text-muted">Hakuna bidhaa zilizopatikana</div>';
        list.style.display = 'block';
        return;
    }
    
    // Show filtered products (limit to 10 for performance)
    list.innerHTML = filtered.slice(0, 20).map(p => `
        <a class="dropdown-item" href="#" onclick="selectStockInProduct('${p.id}', '${(p.name || '').replace(/'/g, "\\'")}', '${p.currentStock || 0}', '${p.unit || 'pcs'}'); return false;">
            <div class="fw-bold">${p.name}</div>
            <small class="text-muted">SKU: ${p.sku || 'N/A'} | Stock: ${p.currentStock || 0} ${p.unit || 'pcs'}</small>
        </a>
    `).join('');
    
    list.style.display = 'block';
}

function selectStockInProduct(productId, productName, currentStock, unit) {
    document.getElementById('stockProductId').value = productId;
    document.getElementById('stockProductSearch').value = `${productName} (${currentStock} ${unit})`;
    document.getElementById('stockInProductList').style.display = 'none';
}

// =========================
// SUPPLIERS
// =========================
async function loadSuppliers() {
    const result = await api('/api/suppliers');
    if (!result.success) {
        console.error('Failed to load suppliers:', result.message);
        suppliers = [];
        return;
    }
    
    const suppliersData = result.data || [];
    allSuppliers = [...suppliersData]; // Store original data for search
    
    // If there's an active search filter, apply it
    const searchInput = document.getElementById('suppliersSearchInput');
    if (searchInput && searchInput.value.trim() !== '') {
        // Apply existing search filter
        filterSuppliersTable();
        return;
    }
    
    // Otherwise, show all suppliers
    suppliers = [...suppliersData];
    
    // Load debt balances for each supplier
    const debtsResult = await api('/api/supplier-debts');
    const supplierDebts = {};
    if (debtsResult.success && debtsResult.data && debtsResult.data.suppliers) {
        debtsResult.data.suppliers.forEach(s => {
            supplierDebts[s.supplierId] = s.balance;
        });
    }
    
    renderSuppliersTable(supplierDebts);
}

function filterSuppliersTable() {
    const searchInput = document.getElementById('suppliersSearchInput');
    if (!searchInput || !allSuppliers) return;
    
    const searchTerm = searchInput.value.toLowerCase().trim();
    
    if (searchTerm === '') {
        suppliers = [...allSuppliers];
    } else {
        suppliers = allSuppliers.filter(s => {
            const searchText = `${s.name || ''} ${s.phone || ''} ${s.email || ''} ${s.contactPerson || ''}`.toLowerCase();
            return searchText.includes(searchTerm);
        });
    }
    
    // Load debt balances and render with filtered suppliers
    loadSuppliersDebtsAndRender();
}

async function loadSuppliersDebtsAndRender() {
    const debtsResult = await api('/api/supplier-debts');
    const supplierDebts = {};
    if (debtsResult.success && debtsResult.data && debtsResult.data.suppliers) {
        debtsResult.data.suppliers.forEach(s => {
            supplierDebts[s.supplierId] = s.balance;
        });
    }
    renderSuppliersTable(supplierDebts);
}

function renderSuppliersTable(supplierDebts = {}) {
    const tbody = document.getElementById('suppliersTableBody');
    if (!tbody) return;
    
    if (suppliers.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted">Hakuna matokeo yaliyopatikana</td></tr>';
        return;
    }
    
    tbody.innerHTML = suppliers.map(s => {
        const debtBalance = supplierDebts[s.id] || 0;
        const hasDebt = debtBalance > 0;
        const supplierNameEscaped = (s.name || '').replace(/'/g, "\\'");
        
        return `
        <tr class="align-middle">
            <td>${s.name}</td>
            <td>${s.contactPerson || '-'}</td>
            <td>${s.phone || '-'}</td>
            <td>${s.email || '-'}</td>
            <td>
                ${hasDebt ? `<span class="badge bg-warning">${formatCurrency(debtBalance)}</span>` : '<span class="badge bg-success">Hakuna Deni</span>'}
            </td>
            <td>
                <span class="status-dot ${s.status === 'active' ? 'active' : 'inactive'}"></span>
                ${s.status === 'active' ? 'Active' : 'Inactive'}
            </td>
            <td>
                <div class="dropdown">
                    <button class="btn btn-sm btn-outline-secondary" type="button" data-bs-toggle="dropdown" data-bs-boundary="viewport" data-bs-strategy="fixed" aria-expanded="false" title="Vitendo">
                        <i class="bi bi-three-dots-vertical"></i>
                    </button>
                    <ul class="dropdown-menu dropdown-menu-end">
                        ${hasDebt ? `<li><a class="dropdown-item text-success" href="#" onclick="event.preventDefault();showSupplierPaymentModal('${s.id}','${supplierNameEscaped}',${debtBalance})"><i class="bi bi-cash-coin me-2"></i>Lipia Deni</a></li>` : ''}
                        <li><a class="dropdown-item" href="#" onclick="event.preventDefault();editSupplier('${s.id}')"><i class="bi bi-pencil me-2"></i>Hariri</a></li>
                        <li><hr class="dropdown-divider"></li>
                        <li><a class="dropdown-item text-danger" href="#" onclick="event.preventDefault();deleteSupplier('${s.id}')"><i class="bi bi-trash me-2"></i>Futa</a></li>
                    </ul>
                </div>
            </td>
        </tr>
        `;
    }).join('') || '<tr><td colspan="7" class="text-center text-muted">Hakuna wasambazaji</td></tr>';
}

async function loadSupplierOptions(selectId) {
    const select = document.getElementById(selectId);
    if (!select) {
        console.error('Supplier select element not found:', selectId);
        return;
    }
    
    // Ensure suppliers are loaded before populating dropdown
    if (!suppliers || suppliers.length === 0) {
        await loadSuppliers();
    }
    
    // Filter active suppliers
    const activeSuppliers = suppliers.filter(s => s.status === 'active');
    
    // Populate dropdown
    if (activeSuppliers.length === 0) {
        select.innerHTML = '<option value="">Hakuna wasambazaji (Ongeza msambazaji kwanza)</option>';
    } else {
        select.innerHTML = '<option value="">Chagua Msambazaji</option>' + 
            activeSuppliers.map(s => 
                `<option value="${s.id}">${s.name}</option>`
            ).join('');
    }
}

async function saveSupplier() {
    const form = document.getElementById('supplierForm');
    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());
    
    const supplierId = document.getElementById('supplierId').value;
    const url = supplierId ? `/api/suppliers/${supplierId}` : '/api/suppliers';
    const method = supplierId ? 'PUT' : 'POST';
    
    const result = await api(url, { method, body: JSON.stringify(data) });
    
    if (result.success) {
        showToast(result.message);
        bootstrap.Modal.getInstance(document.getElementById('supplierModal')).hide();
        form.reset();
        await loadSuppliers();
    } else {
        showToast(result.message, 'danger');
    }
}

function showAddSupplierModal() {
    document.getElementById('supplierId').value = '';
    document.getElementById('supplierForm').reset();
    document.getElementById('supplierModalLabel').textContent = 'Ongeza Msambazaji';
    new bootstrap.Modal(document.getElementById('supplierModal')).show();
}

function editSupplier(id) {
    const supplier = suppliers.find(s => s.id === id);
    if (!supplier) return;
    
    document.getElementById('supplierId').value = supplier.id;
    document.getElementById('supplierName').value = supplier.name;
    document.getElementById('supplierContact').value = supplier.contactPerson || '';
    document.getElementById('supplierPhone').value = supplier.phone || '';
    document.getElementById('supplierEmail').value = supplier.email || '';
    document.getElementById('supplierAddress').value = supplier.address || '';
    document.getElementById('supplierTaxId').value = supplier.taxId || '';
    document.getElementById('supplierStatus').value = supplier.status;
    
    document.getElementById('supplierModalLabel').textContent = 'Hariri Msambazaji';
    new bootstrap.Modal(document.getElementById('supplierModal')).show();
}

async function deleteSupplier(id) {
    if (!confirm('Una uhakika unataka kufuta msambazaji huyu?')) return;
    
    // Show password confirmation modal
    pendingDeleteAction = {
        type: 'supplier',
        id: id,
        callback: async (password) => {
            const result = await api(`/api/suppliers/${id}`, { 
                method: 'DELETE',
                body: JSON.stringify({ adminPassword: password })
            });
            if (result.success) {
                showToast(result.message);
                await loadSuppliers();
            } else {
                showToast(result.message, 'danger');
            }
        }
    };
    
    document.getElementById('passwordConfirmInput').value = '';
    new bootstrap.Modal(document.getElementById('passwordConfirmModal')).show();
}

function showSupplierPaymentModal(supplierId, supplierName, currentDebt) {
    document.getElementById('supplierPaymentSupplierId').value = supplierId;
    document.getElementById('supplierPaymentSupplierName').value = supplierName;
    document.getElementById('supplierPaymentCurrentDebt').value = formatCurrency(currentDebt);
    document.getElementById('supplierPaymentAmount').value = '';
    document.getElementById('supplierPaymentAmount').max = currentDebt;
    document.getElementById('supplierPaymentMethod').value = 'cash';
    document.getElementById('supplierPaymentMethodOther').style.display = 'none';
    document.getElementById('supplierPaymentMethodOther').value = '';
    document.getElementById('supplierPaymentReference').value = '';
    document.getElementById('supplierPaymentNotes').value = '';
    
    // Load payment methods
    populateSupplierPaymentMethods();
    
    new bootstrap.Modal(document.getElementById('supplierPaymentModal')).show();
}

function handleSupplierPaymentMethodChange() {
    const paymentMethod = document.getElementById('supplierPaymentMethod').value;
    const paymentMethodOther = document.getElementById('supplierPaymentMethodOther');
    
    if (paymentMethod === 'other') {
        paymentMethodOther.style.display = 'block';
        paymentMethodOther.required = true;
    } else {
        paymentMethodOther.style.display = 'none';
        paymentMethodOther.required = false;
        paymentMethodOther.value = '';
    }
}

async function populateSupplierPaymentMethods() {
    const paymentMethodSelect = document.getElementById('supplierPaymentMethod');
    if (!paymentMethodSelect) return;
    
    const paymentMethods = await loadPaymentMethods();
    const paymentMethodLabels = {
        'cash': 'Cash',
        'bank': 'Bank Transfer',
        'mpesa': 'M-Pesa',
        'airtel': 'Airtel Money',
        'tigo': 'Tigo Pesa',
        'halopesa': 'Halo Pesa'
    };
    
    function formatMethodName(method) {
        if (paymentMethodLabels[method]) {
            return paymentMethodLabels[method];
        }
        return method.split('_').map(word => 
            word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
        ).join(' ');
    }
    
    const currentValue = paymentMethodSelect.value;
    paymentMethodSelect.innerHTML = '';
    
    paymentMethods.forEach(method => {
        const option = document.createElement('option');
        option.value = method;
        option.textContent = formatMethodName(method);
        paymentMethodSelect.appendChild(option);
    });
    
    const otherOption = document.createElement('option');
    otherOption.value = 'other';
    otherOption.textContent = 'Nyingine';
    paymentMethodSelect.appendChild(otherOption);
    
    if (currentValue && Array.from(paymentMethodSelect.options).some(opt => opt.value === currentValue)) {
        paymentMethodSelect.value = currentValue;
    } else {
        paymentMethodSelect.value = 'cash';
    }
}

async function saveSupplierPayment() {
    const supplierId = document.getElementById('supplierPaymentSupplierId').value;
    const amount = parseFloat(document.getElementById('supplierPaymentAmount').value);
    const selectedMethod = document.getElementById('supplierPaymentMethod').value;
    const otherMethod = document.getElementById('supplierPaymentMethodOther').value.trim();
    const reference = document.getElementById('supplierPaymentReference').value;
    const notes = document.getElementById('supplierPaymentNotes').value;
    
    if (!supplierId || !amount || amount <= 0) {
        showToast('Jaza kiasi cha malipo', 'danger');
        return;
    }
    
    // Get current debt to validate
    const currentDebtText = document.getElementById('supplierPaymentCurrentDebt').value;
    const currentDebt = parseFloat(currentDebtText.replace(/[^\d.]/g, '')) || 0;
    
    if (amount > currentDebt) {
        showToast(`Kiasi kinazidi deni. Deni ni: ${formatCurrency(currentDebt)}`, 'danger');
        return;
    }
    
    let paymentMethod = selectedMethod;
    if (selectedMethod === 'other') {
        if (!otherMethod) {
            showToast('Andika njia ya malipo', 'danger');
            return;
        }
        paymentMethod = otherMethod.toLowerCase().trim().replace(/\s+/g, '_');
    }
    
    const data = {
        supplierId: supplierId,
        amount: amount,
        paymentMethod: paymentMethod,
        reference: reference || `PAY-${Date.now()}`,
        notes: notes || `Malipo ya deni la msambazaji`
    };
    
    const result = await api('/api/supplier-payments', {
        method: 'POST',
        body: JSON.stringify(data)
    });
    
    if (result.success) {
        const newBalance = result.data?.newBalance || 0;
        showToast(`Malipo yameingizwa. Deni jipya: ${formatCurrency(newBalance)}`, 'success');
        bootstrap.Modal.getInstance(document.getElementById('supplierPaymentModal')).hide();
        document.getElementById('supplierPaymentForm').reset();
        await loadSuppliers(); // Reload to show updated debt
    } else {
        showToast(result.message || 'Hitilafu katika kuingiza malipo', 'danger');
    }
}

// =========================
// CUSTOMERS
// =========================
async function loadCustomers() {
    const result = await api('/api/customers');
    if (!result.success) return;
    
    customers = result.data;
    allCustomers = [...customers]; // Store original data for search
    
    renderCustomersTable();
}

function filterCustomersTable() {
    const searchInput = document.getElementById('customersSearchInput');
    if (!searchInput) return;
    
    const searchTerm = searchInput.value.toLowerCase().trim();
    
    if (searchTerm === '') {
        customers = [...allCustomers];
    } else {
        customers = allCustomers.filter(c => {
            const searchText = `${c.name || ''} ${c.businessName || ''} ${c.phone || ''}`.toLowerCase();
            return searchText.includes(searchTerm);
        });
    }

    customersCurrentPage = 1;
    renderCustomersTable(1);
}

function renderCustomersTable(page = customersCurrentPage) {
    const tbody = document.getElementById('customersTableBody');
    if (!tbody) return;

    customersCurrentPage = page;
    const totalPages = Math.max(1, Math.ceil(customers.length / CUSTOMERS_PAGE_LIMIT));
    const start = (page - 1) * CUSTOMERS_PAGE_LIMIT;
    const pageItems = customers.slice(start, start + CUSTOMERS_PAGE_LIMIT);

    if (pageItems.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">Hakuna matokeo yaliyopatikana</td></tr>';
        renderPagination('customersPagination', 1, 1, renderCustomersTable);
        return;
    }

    tbody.innerHTML = pageItems.map(c => `
        <tr>
            <td>${c.name}</td>
            <td>${c.businessName || '-'}</td>
            <td>${c.type === 'wholesale' ? 'Jumla' : 'Rejareja'}</td>
            <td>${c.phone || '-'}</td>
            <td class="${c.totalDebt > 0 ? 'text-danger' : ''}">${formatCurrency(c.totalDebt || 0)}</td>
            <td>
                <button class="btn btn-sm btn-info btn-icon me-1" onclick="viewCustomerStatement('${c.id}')" title="Statement">
                    <i class="bi bi-file-text"></i>
                </button>
                <button class="btn btn-sm btn-primary btn-icon me-1" onclick="editCustomer('${c.id}')" title="Hariri">
                    <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-danger btn-icon" onclick="deleteCustomer('${c.id}')" title="Futa">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        </tr>
    `).join('');

    renderPagination('customersPagination', page, totalPages, renderCustomersTable);
}

async function saveCustomer() {
    const form = document.getElementById('customerForm');
    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());
    
    const customerId = document.getElementById('customerId').value;
    const url = customerId ? `/api/customers/${customerId}` : '/api/customers';
    const method = customerId ? 'PUT' : 'POST';
    
    const result = await api(url, { method, body: JSON.stringify(data) });
    
    if (result.success) {
        showToast(result.message);
        bootstrap.Modal.getInstance(document.getElementById('customerModal')).hide();
        form.reset();
        await loadCustomers();
    } else {
        showToast(result.message, 'danger');
    }
}

function showAddCustomerModal() {
    document.getElementById('customerId').value = '';
    document.getElementById('customerForm').reset();
    document.getElementById('customerModalLabel').textContent = 'Ongeza Mteja';
    new bootstrap.Modal(document.getElementById('customerModal')).show();
}

function editCustomer(id) {
    const customer = customers.find(c => c.id === id);
    if (!customer) return;
    
    document.getElementById('customerId').value = customer.id;
    document.getElementById('customerName').value = customer.name;
    document.getElementById('customerBusiness').value = customer.businessName || '';
    document.getElementById('customerType').value = customer.type;
    document.getElementById('customerPhone').value = customer.phone || '';
    document.getElementById('customerEmail').value = customer.email || '';
    document.getElementById('customerAddress').value = customer.address || '';
    document.getElementById('customerCreditLimit').value = customer.creditLimit || 0;
    
    document.getElementById('customerModalLabel').textContent = 'Hariri Mteja';
    new bootstrap.Modal(document.getElementById('customerModal')).show();
}

async function deleteCustomer(id) {
    if (!confirm('Una uhakika unataka kufuta mteja huyu?')) return;
    
    const result = await api(`/api/customers/${id}`, { method: 'DELETE' });
    if (result.success) {
        showToast(result.message);
        await loadCustomers();
    } else {
        showToast(result.message, 'danger');
    }
}

// =========================
// SALES
// =========================
async function loadSales(page = 1) {
    salesCurrentPage = page;
    const startDate = document.getElementById('salesStartDate')?.value;
    const endDate = document.getElementById('salesEndDate')?.value;
    
    const params = new URLSearchParams({ page, limit: PAGE_LIMIT });
    if (startDate) params.append('startDate', startDate);
    if (endDate) params.append('endDate', endDate);
    
    const result = await api('/api/sales?' + params.toString());
    if (!result.success) return;
    
    allSales = result.data || [];
    salesTotalPages = result.pages || 1;
    
    renderSalesTable();
    renderPagination('salesPagination', salesCurrentPage, salesTotalPages, loadSales);
}

function filterSalesTable() {
    const searchInput = document.getElementById('salesSearchInput');
    if (!searchInput || !allSales) return;
    
    const searchTerm = searchInput.value.toLowerCase().trim();
    
    if (searchTerm === '') {
        renderSalesTableWithData(allSales);
    } else {
        const filtered = allSales.filter(s => {
            const searchText = `${s.receiptNumber || ''} ${s.customerName || ''} ${formatDateTime(s.createdAt) || ''}`.toLowerCase();
            return searchText.includes(searchTerm);
        });
        renderSalesTableWithData(filtered);
    }
}

function renderSalesTable() {
    renderSalesTableWithData(allSales);
}

function renderSalesTableWithData(sales) {
    const tbody = document.getElementById('salesTableBody');
    if (!tbody) return;
    
    if (!sales || sales.length === 0) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">Hakuna matokeo yaliyopatikana</td></tr>';
        return;
    }
    
    function getStatusBadge(status) {
        switch(status) {
            case 'pending_verification':
                return '<span class="badge bg-warning">Inasubiri</span>';
            case 'verified':
                return '<span class="badge bg-info">Imethibitishwa</span>';
            case 'completed':
                return '<span class="badge bg-success">Imekamilika</span>';
            default:
                return '<span class="badge bg-secondary">' + (status || 'N/A') + '</span>';
        }
    }
    
    tbody.innerHTML = sales.map(s => `
        <tr>
            <td>${s.receiptNumber || 'N/A'}</td>
            <td>${formatDateTime(s.completedAt || s.verifiedAt || s.createdAt)}</td>
            <td>${s.customerName || 'Walk-in Customer'}</td>
            <td>${s.items ? s.items.length : 0}</td>
            <td>${formatCurrency(s.totalAmount || 0)}</td>
            <td>${s.paymentMethod ? s.paymentMethod.toUpperCase() : '-'}</td>
            <td>
                ${s.status ? getStatusBadge(s.status) : (
                    s.isCredit ? '<span class="badge bg-warning">Credit</span>' : '<span class="badge bg-success">Paid</span>'
                )}
            </td>
            <td>
                <button class="btn btn-sm btn-info btn-icon me-1" onclick="viewSale('${s.id}')" title="Ona">
                    <i class="bi bi-eye"></i>
                </button>
                ${(s.status === 'verified' || s.status === 'completed' || !s.status) ? `
                    <button class="btn btn-sm btn-secondary btn-icon" onclick="printReceipt('${s.id}')" title="Print">
                        <i class="bi bi-printer"></i>
                    </button>
                ` : ''}
            </td>
        </tr>
    `).join('');
}

function printReceipt(saleId) {
    window.open(`/api/sales/${saleId}/receipt`, '_blank');
}

// =========================
// CREDITS
// =========================
async function loadCredits() {
    const [creditsResult, settingsResult] = await Promise.all([
        api('/api/credit-sales'),
        api('/api/settings')
    ]);
    
    if (!creditsResult.success) return;
    const credits = creditsResult.data || [];
    
    const tbody = document.getElementById('creditsTableBody');
    if (!tbody) return;
    
    const loanLimitDays = (settingsResult.success && settingsResult.data?.loanLimitAlertDays) ?? 7;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const overdue = credits.filter(c => c.status !== 'paid' && c.dueDate && new Date(c.dueDate) < today);
    const nearDue = credits.filter(c => {
        if (c.status === 'paid' || !c.dueDate) return false;
        const due = new Date(c.dueDate);
        due.setHours(0, 0, 0, 0);
        const diffDays = Math.ceil((due - today) / (1000 * 60 * 60 * 24));
        return diffDays >= 0 && diffDays <= loanLimitDays;
    });
    
    const alertEl = document.getElementById('creditsLoanAlert');
    const alertText = document.getElementById('creditsLoanAlertText');
    if (alertEl && alertText) {
        if (overdue.length > 0) {
            alertEl.className = 'alert alert-danger d-flex align-items-center mb-3';
            alertEl.classList.remove('d-none');
            alertText.textContent = `ONYO: Kuna ${overdue.length} mkopo ${overdue.length === 1 ? 'umefika' : 'wamefika'} tarehe ya malipo! Tafadhali wasiliana na wateja.`;
        } else if (nearDue.length > 0) {
            alertEl.className = 'alert alert-warning d-flex align-items-center mb-3';
            alertEl.classList.remove('d-none');
            alertText.textContent = `ONYO: Kuna ${nearDue.length} mkopo ${nearDue.length === 1 ? 'unakaribia' : 'wanakaribia'} tarehe ya malipo (ndani ya siku ${loanLimitDays}).`;
        } else {
            alertEl.classList.add('d-none');
        }
    }
    
    tbody.innerHTML = credits.map(c => {
        const isOverdue = c.status !== 'paid' && c.dueDate && new Date(c.dueDate) < today;
        const isNearDue = !isOverdue && c.status !== 'paid' && c.dueDate && (() => {
            const due = new Date(c.dueDate);
            due.setHours(0, 0, 0, 0);
            const diffDays = Math.ceil((due - today) / (1000 * 60 * 60 * 24));
            return diffDays >= 0 && diffDays <= loanLimitDays;
        })();
        const dueDateClass = isOverdue ? 'text-danger fw-bold' : isNearDue ? 'text-warning' : '';
        return `
        <tr class="${isOverdue ? 'table-danger' : isNearDue ? 'table-warning' : ''}">
            <td>${c.receiptNumber}</td>
            <td>${c.customerName}</td>
            <td>${formatCurrency(c.totalAmount)}</td>
            <td>${formatCurrency(c.paidAmount)}</td>
            <td class="text-danger">${formatCurrency(c.balance)}</td>
            <td class="${dueDateClass}">${formatDate(c.dueDate)}${isOverdue ? ' <span class="badge bg-danger">Umechelewa</span>' : isNearDue ? ' <span class="badge bg-warning text-dark">Karibu</span>' : ''}</td>
            <td>
                <span class="badge ${c.status === 'paid' ? 'bg-success' : 'bg-warning'}">
                    ${c.status === 'paid' ? 'Paid' : 'Pending'}
                </span>
            </td>
            <td>
                ${c.status !== 'paid' ? `
                    <button class="btn btn-sm btn-success btn-icon" onclick="showPaymentModal('${c.id}')" title="Lipa">
                        <i class="bi bi-cash"></i>
                    </button>
                ` : ''}
            </td>
        </tr>
    `}).join('') || '<tr><td colspan="8" class="text-center text-muted">Hakuna madeni</td></tr>';
}

function showPaymentModal(creditId) {
    document.getElementById('paymentCreditId').value = creditId;
    document.getElementById('paymentAmount').value = '';
    document.getElementById('paymentMethod').value = 'cash';
    document.getElementById('paymentReference').value = '';
    new bootstrap.Modal(document.getElementById('paymentModal')).show();
}

async function savePayment() {
    const creditId = document.getElementById('paymentCreditId').value;
    const data = {
        amount: document.getElementById('paymentAmount').value,
        paymentMethod: document.getElementById('paymentMethod').value,
        reference: document.getElementById('paymentReference').value
    };
    
    const result = await api(`/api/credit-sales/${creditId}/pay`, { 
        method: 'POST', 
        body: JSON.stringify(data) 
    });
    
    if (result.success) {
        showToast(result.message);
        bootstrap.Modal.getInstance(document.getElementById('paymentModal')).hide();
        await loadCredits();
    } else {
        showToast(result.message, 'danger');
    }
}

// =========================
// EXPENSES
// =========================
async function loadExpenses() {
    const startDate = document.getElementById('expensesStartDate')?.value;
    const endDate = document.getElementById('expensesEndDate')?.value;
    
    let url = '/api/expenses';
    const params = new URLSearchParams();
    if (startDate) params.append('startDate', startDate);
    if (endDate) params.append('endDate', endDate);
    if (params.toString()) {
        url += '?' + params.toString();
    }
    
    const result = await api(url);
    if (!result.success) return;
    
    const expenses = result.data || [];
    allExpenses = [...expenses]; // Store original data for search
    
    renderExpensesTable();
}

function filterExpensesTable() {
    const searchInput = document.getElementById('expensesSearchInput');
    if (!searchInput || !allExpenses) return;
    
    const searchTerm = searchInput.value.toLowerCase().trim();
    
    if (searchTerm === '') {
        renderExpensesTableWithData(allExpenses);
    } else {
        const filtered = allExpenses.filter(e => {
            const categoryLabels = {
                rent: 'kodi',
                utilities: 'umeme maji',
                salaries: 'mishahara',
                transport: 'usafiri',
                supplies: 'vifaa',
                other: 'mengine'
            };
            const searchText = `${categoryLabels[e.category] || e.category || ''} ${e.description || ''}`.toLowerCase();
            return searchText.includes(searchTerm);
        });
        renderExpensesTableWithData(filtered);
    }
}

function renderExpensesTable() {
    renderExpensesTableWithData(allExpenses);
}

function renderExpensesTableWithData(expenses) {
    const tbody = document.getElementById('expensesTableBody');
    if (!tbody) return;
    
    if (!expenses || expenses.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">Hakuna matokeo yaliyopatikana</td></tr>';
        return;
    }
    
    const categoryLabels = {
        rent: 'Kodi',
        utilities: 'Umeme/Maji',
        salaries: 'Mishahara',
        transport: 'Usafiri',
        supplies: 'Vifaa',
        other: 'Mengine'
    };
    
    tbody.innerHTML = expenses.map(e => `
        <tr>
            <td>${formatDate(e.date)}</td>
            <td>${categoryLabels[e.category] || e.category}</td>
            <td>${e.description}</td>
            <td>${formatCurrency(e.amount)}</td>
            <td>${e.paymentMethod?.toUpperCase() || 'CASH'}</td>
            <td>
                <button class="btn btn-sm btn-primary btn-icon me-1" onclick="editExpense('${e.id}')" title="Hariri">
                    <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-danger btn-icon" onclick="deleteExpense('${e.id}')" title="Futa">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        </tr>
    `).join('');
}

async function saveExpense() {
    const form = document.getElementById('expenseForm');
    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());
    
    const expenseId = document.getElementById('expenseId').value;
    const url = expenseId ? `/api/expenses/${expenseId}` : '/api/expenses';
    const method = expenseId ? 'PUT' : 'POST';
    
    const result = await api(url, { method, body: JSON.stringify(data) });
    
    if (result.success) {
        showToast(result.message);
        bootstrap.Modal.getInstance(document.getElementById('expenseModal')).hide();
        form.reset();
        await loadExpenses();
    } else {
        showToast(result.message, 'danger');
    }
}

function showAddExpenseModal() {
    document.getElementById('expenseId').value = '';
    document.getElementById('expenseForm').reset();
    document.getElementById('expenseDate').value = new Date().toISOString().split('T')[0];
    document.getElementById('expenseModalLabel').textContent = 'Ongeza Matumizi';
    new bootstrap.Modal(document.getElementById('expenseModal')).show();
}

function editExpense(id) {
    if (!allExpenses || allExpenses.length === 0) {
        // If expenses aren't loaded, load them first
        loadExpenses().then(() => editExpense(id));
        return;
    }
    
    const expense = allExpenses.find(e => e.id === id);
    if (!expense) {
        showToast('Matumizi hayapatikani', 'danger');
        return;
    }
    
    document.getElementById('expenseId').value = expense.id;
    document.getElementById('expenseCategory').value = expense.category || 'other';
    document.getElementById('expenseDescription').value = expense.description || '';
    document.getElementById('expenseAmount').value = expense.amount || '';
    document.getElementById('expenseDate').value = expense.date ? expense.date.split('T')[0] : new Date().toISOString().split('T')[0];
    document.getElementById('expensePaymentMethod').value = expense.paymentMethod || 'cash';
    
    document.getElementById('expenseModalLabel').textContent = 'Hariri Matumizi';
    new bootstrap.Modal(document.getElementById('expenseModal')).show();
}

async function deleteExpense(id) {
    if (!confirm('Una uhakika unataka kufuta matumizi haya?')) return;
    
    const result = await api(`/api/expenses/${id}`, { method: 'DELETE' });
    if (result.success) {
        showToast(result.message);
        await loadExpenses();
    } else {
        showToast(result.message, 'danger');
    }
}

// =========================
// USERS
// =========================
async function loadUsers() {
    const result = await api('/api/users');
    if (!result.success) return;
    
    const users = result.data || [];
    allUsers = [...users]; // Store original data for search
    
    renderUsersTable();
}

function filterUsersTable() {
    const searchInput = document.getElementById('usersSearchInput');
    if (!searchInput || !allUsers) return;
    
    const searchTerm = searchInput.value.toLowerCase().trim();
    
    if (searchTerm === '') {
        renderUsersTableWithData(allUsers);
    } else {
        const filtered = allUsers.filter(u => {
            const searchText = `${u.username || ''} ${u.fullName || ''} ${u.email || ''}`.toLowerCase();
            return searchText.includes(searchTerm);
        });
        renderUsersTableWithData(filtered);
    }
}

function renderUsersTable() {
    renderUsersTableWithData(allUsers);
}

function renderUsersTableWithData(users) {
    const tbody = document.getElementById('usersTableBody');
    if (!tbody) return;
    
    if (!users || users.length === 0) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">Hakuna matokeo yaliyopatikana</td></tr>';
        return;
    }
    
    const roleLabels = {
        admin: 'Msimamizi',
        cashier: 'Karani',
        storekeeper: 'Mhifadhi Stoo',
        reception: 'Reception',
        store_viewer: 'Mwangaliaji Stoo'
    };
    
    tbody.innerHTML = users.map(u => `
        <tr>
            <td>${u.username}</td>
            <td>${u.fullName}</td>
            <td>${u.email || '-'}</td>
            <td>${u.phone || '-'}</td>
            <td><span class="badge bg-primary">${roleLabels[u.role] || u.role}</span></td>
            <td>
                <span class="status-dot ${u.status === 'active' ? 'active' : 'inactive'}"></span>
                ${u.status === 'active' ? 'Active' : 'Inactive'}
            </td>
            <td>${u.lastLogin ? formatDateTime(u.lastLogin) : 'Hajaingia'}</td>
            <td>
                <button class="btn btn-sm btn-primary btn-icon me-1" onclick="editUser('${u.id}')" title="Hariri">
                    <i class="bi bi-pencil"></i>
                </button>
                ${u.username !== 'admin' ? `
                    <button class="btn btn-sm btn-danger btn-icon" onclick="deleteUser('${u.id}')" title="Futa">
                        <i class="bi bi-trash"></i>
                    </button>
                ` : ''}
            </td>
        </tr>
    `).join('');
}

async function saveUser() {
    const form = document.getElementById('userForm');
    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());
    
    // Remove empty password
    if (!data.password) delete data.password;
    
    const userId = document.getElementById('userId').value;
    const url = userId ? `/api/users/${userId}` : '/api/users';
    const method = userId ? 'PUT' : 'POST';
    
    const result = await api(url, { method, body: JSON.stringify(data) });
    
    if (result.success) {
        showToast(result.message);
        bootstrap.Modal.getInstance(document.getElementById('userModal')).hide();
        form.reset();
        await loadUsers();
    } else {
        showToast(result.message, 'danger');
    }
}

function showAddUserModal() {
    document.getElementById('userId').value = '';
    document.getElementById('userForm').reset();
    document.getElementById('userPassword').required = true;
    document.getElementById('userModalLabel').textContent = 'Ongeza Mtumiaji';
    // Remove any temporarily-added hidden role options from a previous edit
    document.querySelectorAll('#userRole option[data-hidden="true"]').forEach(o => o.remove());
    loadBranchOptions('userBranch');
    new bootstrap.Modal(document.getElementById('userModal')).show();
}

async function editUser(id) {
    const result = await api('/api/users');
    if (!result.success) return;
    
    const user = result.data.find(u => u.id === id);
    if (!user) return;
    
    document.getElementById('userId').value = user.id;
    document.getElementById('userUsername').value = user.username;
    document.getElementById('userFullName').value = user.fullName;
    document.getElementById('userEmail').value = user.email || '';
    document.getElementById('userPhone').value = user.phone || '';
    document.getElementById('userRole').value = user.role;
    // If user has a hidden role (reception/store_viewer), temporarily add it so it shows correctly
    const roleSelect = document.getElementById('userRole');
    if (!roleSelect.querySelector(`option[value="${user.role}"]`)) {
        const labels = { reception: 'Reception', store_viewer: 'Mwangaliaji Stoo (Store Viewer)' };
        const opt = document.createElement('option');
        opt.value = user.role;
        opt.textContent = labels[user.role] || user.role;
        opt.dataset.hidden = 'true';
        roleSelect.appendChild(opt);
    }
    roleSelect.value = user.role;
    document.getElementById('userStatus').value = user.status;
    document.getElementById('userPassword').value = '';
    document.getElementById('userPassword').required = false;
    
    await loadBranchOptions('userBranch');
    document.getElementById('userBranch').value = user.branchId;
    
    document.getElementById('userModalLabel').textContent = 'Hariri Mtumiaji';
    new bootstrap.Modal(document.getElementById('userModal')).show();
}

async function deleteUser(id) {
    if (!confirm('Una uhakika unataka kufuta mtumiaji huyu?')) return;
    
    // Show password confirmation modal
    pendingDeleteAction = {
        type: 'user',
        id: id,
        callback: async (password) => {
            const result = await api(`/api/users/${id}`, { 
                method: 'DELETE',
                body: JSON.stringify({ adminPassword: password })
            });
            if (result.success) {
                showToast(result.message);
                await loadUsers();
            } else {
                showToast(result.message, 'danger');
            }
        }
    };
    
    document.getElementById('passwordConfirmInput').value = '';
    new bootstrap.Modal(document.getElementById('passwordConfirmModal')).show();
}

// =========================
// BRANCHES
// =========================
async function loadBranches() {
    const result = await api('/api/branches');
    if (result.success) {
        branches = result.data;
    }
}

async function loadBranchesList() {
    await loadBranches();
    
    const tbody = document.getElementById('branchesTableBody');
    if (!tbody) return;
    
    tbody.innerHTML = branches.map(b => `
        <tr>
            <td>${b.name}</td>
            <td>${b.address || '-'}</td>
            <td>${b.phone || '-'}</td>
            <td>${b.email || '-'}</td>
            <td>
                <span class="status-dot ${b.status === 'active' ? 'active' : 'inactive'}"></span>
                ${b.status === 'active' ? 'Active' : 'Inactive'}
            </td>
            <td>
                <button class="btn btn-sm btn-primary btn-icon me-1" onclick="editBranch('${b.id}')" title="Hariri">
                    <i class="bi bi-pencil"></i>
                </button>
            </td>
        </tr>
    `).join('') || '<tr><td colspan="6" class="text-center text-muted">Hakuna matawi</td></tr>';
}

function loadBranchOptions(selectId) {
    const select = document.getElementById(selectId);
    if (!select) return;
    
    select.innerHTML = '<option value="">Chagua Tawi</option>' + 
        branches.filter(b => b.status === 'active').map(b => 
            `<option value="${b.id}">${b.name}</option>`
        ).join('');
}

async function saveBranch() {
    const form = document.getElementById('branchForm');
    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());
    
    const branchId = document.getElementById('branchId').value;
    const url = branchId ? `/api/branches/${branchId}` : '/api/branches';
    const method = branchId ? 'PUT' : 'POST';
    
    const result = await api(url, { method, body: JSON.stringify(data) });
    
    if (result.success) {
        showToast(result.message);
        bootstrap.Modal.getInstance(document.getElementById('branchModal')).hide();
        form.reset();
        await loadBranchesList();
    } else {
        showToast(result.message, 'danger');
    }
}

function showAddBranchModal() {
    document.getElementById('branchId').value = '';
    document.getElementById('branchForm').reset();
    document.getElementById('branchModalLabel').textContent = 'Ongeza Tawi';
    new bootstrap.Modal(document.getElementById('branchModal')).show();
}

function editBranch(id) {
    const branch = branches.find(b => b.id === id);
    if (!branch) return;
    document.getElementById('branchId').value = branch.id;
    document.getElementById('branchName').value = branch.name || '';
    document.getElementById('branchAddress').value = branch.address || '';
    document.getElementById('branchPhone').value = branch.phone || '';
    document.getElementById('branchEmail').value = branch.email || '';
    document.getElementById('branchModalLabel').textContent = 'Hariri Tawi';
    new bootstrap.Modal(document.getElementById('branchModal')).show();
}

// =========================
// REPORTS
// =========================
async function loadReports() {
    // Initialize report containers
    const purchaseReportDiv = document.getElementById('purchaseReport');
    const profitLossReportDiv = document.getElementById('profitLossReport');
    if (purchaseReportDiv) purchaseReportDiv.style.display = 'none';
    if (profitLossReportDiv) profitLossReportDiv.style.display = 'none';
    
    // Load suppliers for filter (admin only)
    if (currentUser && currentUser.role === 'admin') {
        await loadSuppliers();
        const supplierFilter = document.getElementById('reportSupplierFilter');
        if (supplierFilter && suppliers.length > 0) {
            supplierFilter.innerHTML = '<option value="">Msambazaji Wote</option>' + 
                suppliers.filter(s => s.status === 'active').map(s => 
                    `<option value="${s.id}">${s.name}</option>`
                ).join('');
        }
    } else {
        const supplierFilter = document.getElementById('reportSupplierFilter');
        if (supplierFilter) supplierFilter.style.display = 'none';
    }
    
    // Default to sales report
    await loadSalesReport();
}

async function loadSalesReport() {
    // Update active tab
    const salesTab = document.getElementById('salesReportTab');
    const purchaseTab = document.getElementById('purchaseReportTab');
    const profitLossTab = document.getElementById('profitLossReportTab');
    const purchaseReportDiv = document.getElementById('purchaseReport');
    const profitLossReportDiv = document.getElementById('profitLossReport');
    
    if (salesTab) salesTab.classList.add('active');
    if (purchaseTab) purchaseTab.classList.remove('active');
    if (profitLossTab) profitLossTab.classList.remove('active');
    if (purchaseReportDiv) purchaseReportDiv.style.display = 'none';
    if (profitLossReportDiv) profitLossReportDiv.style.display = 'none';
    
    const startDate = document.getElementById('reportStartDate')?.value;
    const endDate = document.getElementById('reportEndDate')?.value;
    const supplierId = document.getElementById('reportSupplierFilter')?.value || '';
    
    let url = '/api/reports/sales?groupBy=day';
    if (startDate && endDate) {
        url += `&startDate=${startDate}&endDate=${endDate}`;
    }
    if (supplierId && currentUser && currentUser.role === 'admin') {
        url += `&supplierId=${supplierId}`;
    }
    
    const result = await api(url);
    if (!result.success) {
        showToast('Hitilafu katika kupata ripoti ya mauzo', 'danger');
        return;
    }
    
    const data = result.data;
    
    // Update summary
    const revenueEl = document.getElementById('reportTotalRevenue');
    const transactionsEl = document.getElementById('reportTotalTransactions');
    const avgTransactionEl = document.getElementById('reportAvgTransaction');
    
    if (revenueEl) revenueEl.textContent = formatCurrency(data.summary.totalRevenue);
    if (transactionsEl) transactionsEl.textContent = data.summary.totalTransactions;
    if (avgTransactionEl) avgTransactionEl.textContent = formatCurrency(data.summary.averageTransaction);
}

async function loadPurchaseReport() {
    // Update active tab
    const salesTab = document.getElementById('salesReportTab');
    const purchaseTab = document.getElementById('purchaseReportTab');
    const profitLossTab = document.getElementById('profitLossReportTab');
    const purchaseReportDiv = document.getElementById('purchaseReport');
    const profitLossReportDiv = document.getElementById('profitLossReport');
    
    if (salesTab) salesTab.classList.remove('active');
    if (purchaseTab) purchaseTab.classList.add('active');
    if (profitLossTab) profitLossTab.classList.remove('active');
    if (purchaseReportDiv) purchaseReportDiv.style.display = 'block';
    if (profitLossReportDiv) profitLossReportDiv.style.display = 'none';
    
    const startDate = document.getElementById('reportStartDate')?.value;
    const endDate = document.getElementById('reportEndDate')?.value;
    const supplierId = document.getElementById('reportSupplierFilter')?.value || '';
    
    let url = '/api/reports/purchases';
    const params = [];
    if (startDate && endDate) {
        params.push(`startDate=${startDate}`);
        params.push(`endDate=${endDate}`);
    }
    if (supplierId && currentUser && currentUser.role === 'admin') {
        params.push(`supplierId=${supplierId}`);
    }
    if (params.length > 0) {
        url += '?' + params.join('&');
    }
    
    const result = await api(url);
    if (!result.success) {
        showToast('Hitilafu katika kupata ripoti ya manunuzi', 'danger');
        return;
    }
    
    const data = result.data;
    const container = document.getElementById('purchaseReport');
    if (!container) return;
    
    // Update summary cards
    const revenueEl = document.getElementById('reportTotalRevenue');
    const transactionsEl = document.getElementById('reportTotalTransactions');
    const avgTransactionEl = document.getElementById('reportAvgTransaction');
    
    if (revenueEl) revenueEl.textContent = formatCurrency(data.summary.totalPurchases);
    if (transactionsEl) transactionsEl.textContent = data.summary.totalOrders;
    if (avgTransactionEl) avgTransactionEl.textContent = formatCurrency(data.summary.averageOrder);
    
    // Display purchase details
    container.innerHTML = `
        <div class="row g-4 mb-4">
            <div class="col-md-3">
                <div class="stat-card">
                    <div class="label">Manunuzi ya Cash</div>
                    <div class="value text-success">${formatCurrency(data.summary.cashPurchases)}</div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="stat-card">
                    <div class="label">Manunuzi ya Mkopo</div>
                    <div class="value text-warning">${formatCurrency(data.summary.creditPurchases)}</div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="stat-card">
                    <div class="label">Msambazaji</div>
                    <div class="value">${data.summary.totalSuppliers}</div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="stat-card">
                    <div class="label">Bidhaa Zinazonunuliwa</div>
                    <div class="value">${data.summary.totalItems}</div>
                </div>
            </div>
        </div>
        
        ${data.summary.creditPurchases > 0 ? `
            <div class="row g-4 mb-4">
                <div class="col-md-4">
                    <div class="stat-card">
                        <div class="label">Jumla ya Manunuzi ya Mkopo</div>
                        <div class="value text-warning">${formatCurrency(data.summary.creditPurchases)}</div>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="stat-card">
                        <div class="label">Kiasi Kilicholipwa</div>
                        <div class="value text-success">${formatCurrency(data.summary.totalPaidForCredits || 0)}</div>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="stat-card">
                        <div class="label">Deni Baki</div>
                        <div class="value text-danger">${formatCurrency(data.summary.totalRemainingDebt || 0)}</div>
                    </div>
                </div>
            </div>
        ` : ''}
        
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h6 class="mb-0">Orodha ya Manunuzi</h6>
            <button class="btn btn-sm btn-success" onclick="exportPurchaseReportToExcel()">
                <i class="bi bi-file-earmark-excel me-1"></i>Export Excel
            </button>
        </div>
        <div class="table-responsive">
            <table class="table table-sm">
                <thead>
                    <tr>
                        <th>Tarehe</th>
                        <th>Invoice</th>
                        <th>Msambazaji</th>
                        <th>Kiasi</th>
                        <th>Aina ya Malipo</th>
                        <th>Njia ya Malipo</th>
                        ${data.summary.creditPurchases > 0 ? '<th>Kiasi Kilicholipwa</th><th>Deni Baki</th><th>Vitendo</th>' : '<th>Vitendo</th>'}
                    </tr>
                </thead>
                <tbody>
                    ${data.purchases.map(p => {
                        const paymentMethodLabels = {
                            'cash': 'Cash',
                            'bank': 'Bank Transfer',
                            'mpesa': 'M-Pesa',
                            'airtel': 'Airtel Money',
                            'tigo': 'Tigo Pesa',
                            'halopesa': 'Halo Pesa'
                        };
                        
                        function formatPaymentMethod(method) {
                            if (paymentMethodLabels[method]) {
                                return paymentMethodLabels[method];
                            }
                            return method ? method.split('_').map(word => 
                                word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
                            ).join(' ') : '-';
                        }
                        
                        // Get payment info for credit purchases
                        let paidAmount = p.totalPaid !== undefined ? p.totalPaid : 0;
                        let remainingBalance = p.paymentType === 'credit' ? (p.remainingBalance !== undefined ? p.remainingBalance : p.totalAmount) : 0;
                        
                        return `
                        <tr>
                            <td>${formatDate(p.createdAt)}</td>
                            <td>${p.invoiceNumber}</td>
                            <td>${p.supplierName}</td>
                            <td>${formatCurrency(p.totalAmount)}</td>
                            <td><span class="badge bg-${p.paymentType === 'credit' ? 'warning' : 'success'}">${p.paymentType === 'credit' ? 'Mkopo' : 'Cash'}</span></td>
                            <td>${p.paymentType === 'cash' ? formatPaymentMethod(p.paymentMethod || 'cash') : '-'}</td>
                            ${data.summary.creditPurchases > 0 ? `
                                <td>${p.paymentType === 'credit' ? formatCurrency(paidAmount) : '-'}</td>
                                <td>${p.paymentType === 'credit' ? `<span class="text-danger fw-bold">${formatCurrency(remainingBalance)}</span>` : '-'}</td>
                            ` : ''}
                            <td>
                                <button class="btn btn-sm btn-info btn-icon" onclick="viewPurchaseDetails('${p.id}')" title="Angalia Maelezo">
                                    <i class="bi bi-eye"></i>
                                </button>
                            </td>
                        </tr>
                        `;
                    }).join('') || '<tr><td colspan="' + (data.summary.creditPurchases > 0 ? '9' : '7') + '" class="text-center text-muted">Hakuna manunuzi</td></tr>'}
                </tbody>
            </table>
        </div>
    `;
    
    // Store purchase data for Excel export
    window.currentPurchaseReportData = data;
}

function exportPurchaseReportToExcel() {
    if (!window.currentPurchaseReportData) {
        showToast('Hakuna data ya ku-export', 'danger');
        return;
    }
    
    const data = window.currentPurchaseReportData;
    const startDate = document.getElementById('reportStartDate')?.value || '';
    const endDate = document.getElementById('reportEndDate')?.value || '';
    const supplierId = document.getElementById('reportSupplierFilter')?.value || '';
    const supplierName = supplierId ? suppliers.find(s => s.id === supplierId)?.name || 'Msambazaji Wote' : 'Msambazaji Wote';
    
    // Create CSV content
    let csv = '\uFEFF'; // BOM for Excel UTF-8 support
    
    // Header
    csv += 'RIPOTI YA MANUNUZI\n';
    csv += `Tarehe: ${startDate && endDate ? `${startDate} - ${endDate}` : 'Zote'}\n`;
    csv += `Msambazaji: ${supplierName}\n`;
    csv += `Tarehe ya Kuunda: ${formatDateTime(new Date())}\n\n`;
    
    // Summary
    csv += 'MUHTASARI\n';
    csv += `Jumla ya Manunuzi,${data.summary.totalPurchases.toLocaleString()}\n`;
    csv += `Idadi ya Manunuzi,${data.summary.totalOrders}\n`;
    csv += `Wastani wa Manunuzi,${data.summary.averageOrder.toLocaleString()}\n`;
    csv += `Manunuzi ya Cash,${data.summary.cashPurchases.toLocaleString()}\n`;
    csv += `Manunuzi ya Mkopo,${data.summary.creditPurchases.toLocaleString()}\n`;
    if (data.summary.creditPurchases > 0) {
        csv += `Kiasi Kilicholipwa,${(data.summary.totalPaidForCredits || 0).toLocaleString()}\n`;
        csv += `Deni Baki,${(data.summary.totalRemainingDebt || 0).toLocaleString()}\n`;
    }
    csv += `Msambazaji,${data.summary.totalSuppliers}\n`;
    csv += `Bidhaa Zinazonunuliwa,${data.summary.totalItems}\n\n`;
    
    // Purchase details
    csv += 'ORODHA YA MANUNUZI\n';
    csv += 'Tarehe,Invoice,Msambazaji,Kiasi,Aina ya Malipo,Njia ya Malipo';
    if (data.summary.creditPurchases > 0) {
        csv += ',Kiasi Kilicholipwa,Deni Baki';
    }
    csv += '\n';
    
    const paymentMethodLabels = {
        'cash': 'Cash',
        'bank': 'Bank Transfer',
        'mpesa': 'M-Pesa',
        'airtel': 'Airtel Money',
        'tigo': 'Tigo Pesa',
        'halopesa': 'Halo Pesa'
    };
    
    function formatPaymentMethod(method) {
        if (paymentMethodLabels[method]) {
            return paymentMethodLabels[method];
        }
        return method ? method.split('_').map(word => 
            word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
        ).join(' ') : '-';
    }
    
    data.purchases.forEach(p => {
        const date = formatDate(p.createdAt);
        const invoice = p.invoiceNumber || '';
        const supplier = p.supplierName || '';
        const amount = p.totalAmount || 0;
        const paymentType = p.paymentType === 'credit' ? 'Mkopo' : 'Cash';
        const paymentMethod = p.paymentType === 'cash' ? formatPaymentMethod(p.paymentMethod || 'cash') : '-';
        
        csv += `"${date}","${invoice}","${supplier}",${amount.toLocaleString()},"${paymentType}","${paymentMethod}"`;
        
        if (data.summary.creditPurchases > 0) {
            const paid = p.paymentType === 'credit' ? (p.totalPaid !== undefined ? p.totalPaid : 0) : 0;
            const balance = p.paymentType === 'credit' ? (p.remainingBalance !== undefined ? p.remainingBalance : p.totalAmount) : 0;
            csv += `,${paid.toLocaleString()},${balance.toLocaleString()}`;
        }
        
        csv += '\n';
    });
    
    // Create blob and download
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', `Ripoti_Manunuzi_${startDate || 'zote'}_${endDate || 'zote'}.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    
    showToast('Ripoti ime-download kama faili ya Excel', 'success');
}

async function loadProfitLossReport() {
    // Update active tab
    const salesTab = document.getElementById('salesReportTab');
    const purchaseTab = document.getElementById('purchaseReportTab');
    const profitLossTab = document.getElementById('profitLossReportTab');
    const purchaseReportDiv = document.getElementById('purchaseReport');
    const profitLossReportDiv = document.getElementById('profitLossReport');
    
    if (salesTab) salesTab.classList.remove('active');
    if (purchaseTab) purchaseTab.classList.remove('active');
    if (profitLossTab) profitLossTab.classList.add('active');
    if (purchaseReportDiv) purchaseReportDiv.style.display = 'none';
    if (profitLossReportDiv) profitLossReportDiv.style.display = 'block';
    
    const startDate = document.getElementById('reportStartDate')?.value;
    const endDate = document.getElementById('reportEndDate')?.value;
    
    let url = '/api/reports/profit-loss';
    if (startDate && endDate) {
        url += `?startDate=${startDate}&endDate=${endDate}`;
    }
    
    const result = await api(url);
    if (!result.success) return;
    
    const data = result.data;
    const container = document.getElementById('profitLossReport');
    if (!container) return;
    
    container.innerHTML = `
        <div class="row g-4">
            <div class="col-md-4">
                <div class="stat-card">
                    <div class="label">Mapato</div>
                    <div class="value text-primary">${formatCurrency(data.revenue)}</div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="stat-card">
                    <div class="label">Gharama za Bidhaa</div>
                    <div class="value text-danger">${formatCurrency(data.costOfGoodsSold)}</div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="stat-card">
                    <div class="label">Faida Ghafi</div>
                    <div class="value ${data.grossProfit >= 0 ? 'text-success' : 'text-danger'}">
                        ${formatCurrency(data.grossProfit)}
                    </div>
                    <div class="small text-muted">${data.grossProfitMargin}%</div>
                </div>
            </div>
            <div class="col-md-6">
                <div class="stat-card">
                    <div class="label">Matumizi</div>
                    <div class="value text-warning">${formatCurrency(data.totalExpenses)}</div>
                </div>
            </div>
            <div class="col-md-6">
                <div class="stat-card">
                    <div class="label">Faida Halisi</div>
                    <div class="value ${data.netProfit >= 0 ? 'text-success' : 'text-danger'}">
                        ${formatCurrency(data.netProfit)}
                    </div>
                    <div class="small text-muted">${data.netProfitMargin}%</div>
                </div>
            </div>
        </div>
    `;
}

// =========================
// ACTIVITY LOGS
// =========================
async function loadActivityLogs() {
    const result = await api('/api/activity-logs');
    if (!result.success) return;
    
    const tbody = document.getElementById('logsTableBody');
    if (!tbody) return;

    const allowed = ['LOGIN', 'LOGOUT', 'LOGIN_FAILED'];
    const filtered = result.data.filter(l =>
        allowed.includes(l.action) || l.action.startsWith('DELETE')
    );
    
    tbody.innerHTML = filtered.slice(0, 200).map(l => {
        const badgeClass = l.action === 'LOGOUT' ? 'bg-secondary'
            : l.action === 'LOGIN_FAILED' ? 'bg-danger'
            : l.action.startsWith('DELETE') ? 'bg-warning text-dark'
            : 'bg-success';
        return `
        <tr>
            <td>${formatDateTime(l.timestamp)}</td>
            <td>${l.userName}</td>
            <td><span class="badge ${badgeClass}">${l.action}</span></td>
            <td>${l.details}</td>
            <td><code>${l.ipAddress}</code></td>
        </tr>`;
    }).join('') || '<tr><td colspan="5" class="text-center text-muted">Hakuna logs</td></tr>';
}

// =========================
// SETTINGS
// =========================
async function loadSettings() {
    const result = await api('/api/settings');
    if (!result.success) return;
    
    const settings = result.data;
    
    document.getElementById('settingCompanyName').value = settings.companyName || '';
    document.getElementById('settingCompanyAddress').value = settings.companyAddress || '';
    document.getElementById('settingCompanyPhone').value = settings.companyPhone || '';
    document.getElementById('settingCompanyEmail').value = settings.companyEmail || '';
    document.getElementById('settingCurrency').value = settings.currency || 'TZS';
    document.getElementById('settingLowStock').value = settings.lowStockThreshold || 10;
    document.getElementById('settingExpiryDays').value = settings.expiryAlertDays || 30;
    document.getElementById('settingLoanLimitDays').value = settings.loanLimitAlertDays ?? 7;
    document.getElementById('settingTaxRate').value = settings.taxRate || 18;
    document.getElementById('settingReceiptFooter').value = settings.receiptFooter || '';
}

async function saveSettings() {
    const data = {
        companyName: document.getElementById('settingCompanyName').value,
        companyAddress: document.getElementById('settingCompanyAddress').value,
        companyPhone: document.getElementById('settingCompanyPhone').value,
        companyEmail: document.getElementById('settingCompanyEmail').value,
        currency: document.getElementById('settingCurrency').value,
        lowStockThreshold: parseInt(document.getElementById('settingLowStock').value),
        expiryAlertDays: parseInt(document.getElementById('settingExpiryDays').value),
        loanLimitAlertDays: parseInt(document.getElementById('settingLoanLimitDays').value) || 7,
        taxRate: parseFloat(document.getElementById('settingTaxRate').value),
        receiptFooter: document.getElementById('settingReceiptFooter').value
    };
    
    const result = await api('/api/settings', { 
        method: 'PUT', 
        body: JSON.stringify(data) 
    });
    
    if (result.success) {
        showToast(result.message);
    } else {
        showToast(result.message, 'danger');
    }
}

async function createBackup() {
    const result = await api('/api/backup', { method: 'POST' });
    if (result.success) {
        showToast(result.message);
    } else {
        showToast(result.message, 'danger');
    }
}

// =========================
// NOTIFICATIONS
// =========================
async function loadNotifications() {
    try {
        const result = await api('/api/notifications');
        if (!result.success) return;
        
        const notifications = result.data || [];
        const unreadCount = notifications.filter(n => !n.read).length;
        
        // Update badge
        const badge = document.getElementById('notificationBadge');
        if (badge) {
            badge.textContent = unreadCount;
            badge.style.display = unreadCount > 0 ? 'flex' : 'none';
        }
        
        // Update list
        const list = document.getElementById('notificationList');
        if (list) {
            list.innerHTML = notifications.slice(0, 20).map(n => `
                <div class="notification-item ${n.read ? '' : 'unread'}" onclick="markNotificationRead('${n.id}')">
                    <div class="title">
                        <i class="bi bi-${n.type === 'low_stock' ? 'exclamation-triangle text-warning' : 'clock text-danger'} me-2"></i>
                        ${n.title}
                    </div>
                    <div class="message">${n.message}</div>
                    <div class="time">${formatDateTime(n.createdAt)}</div>
                </div>
            `).join('') || '<div class="text-center text-muted p-4">Hakuna arifa</div>';
        }
    } catch (error) {
        console.log('Failed to load notifications:', error);
    }
}

async function markNotificationRead(id) {
    await api(`/api/notifications/${id}/read`, { method: 'PUT' });
    await loadNotifications();
}

// =========================
// HELPER FUNCTIONS
// =========================
async function loadProductOptions(selectId) {
    const select = document.getElementById(selectId);
    if (!select) {
        console.error('Product select element not found:', selectId);
        return;
    }
    
    // Ensure products are loaded before populating dropdown
    if (!products || products.length === 0) {
        await loadProducts();
    }
    
    // Filter active products
    const activeProducts = products.filter(p => p.status === 'active');
    
    // Populate dropdown
    if (activeProducts.length === 0) {
        select.innerHTML = '<option value="">Hakuna bidhaa (Ongeza bidhaa kwanza)</option>';
    } else {
        select.innerHTML = '<option value="">Chagua Bidhaa</option>' + 
            activeProducts.map(p => 
                `<option value="${p.id}">${p.name} (${p.currentStock || 0} ${p.unit || 'pcs'})</option>`
            ).join('');
    }
}

// =========================
// POS SYSTEM
// =========================
function addToCart(productId) {
    const product = products.find(p => p.id === productId);
    if (!product) return;
    
    const existingItem = cart.find(item => item.productId === productId);
    
    if (existingItem) {
        if (existingItem.quantity >= product.currentStock) {
            showToast('Stock haitoshi', 'danger');
            return;
        }
        existingItem.quantity++;
    } else {
        cart.push({
            productId: product.id,
            name: product.name,
            price: product.retailPrice,
            wholesalePrice: product.wholesalePrice,
            quantity: 1,
            maxStock: product.currentStock
        });
    }
    
    renderCart();
}

function updateCartItemQty(productId, change) {
    const item = cart.find(i => i.productId === productId);
    if (!item) return;
    
    const newQty = item.quantity + change;
    
    if (newQty <= 0) {
        removeFromCart(productId);
        return;
    }
    
    if (newQty > item.maxStock) {
        showToast('Stock haitoshi', 'danger');
        return;
    }
    
    item.quantity = newQty;
    renderCart();
}

function setCartItemQty(productId, newQty) {
    const item = cart.find(i => i.productId === productId);
    if (!item) return;
    
    // Parse and validate input
    const qty = parseInt(newQty);
    
    if (isNaN(qty) || qty <= 0) {
        // If invalid, restore original quantity
        renderCart();
        return;
    }
    
    if (qty > item.maxStock) {
        showToast('Stock haitoshi. Kiwango cha juu ni ' + item.maxStock, 'danger');
        renderCart(); // Restore original quantity
        return;
    }
    
    item.quantity = qty;
    renderCart();
}

function removeFromCart(productId) {
    cart = cart.filter(item => item.productId !== productId);
    renderCart();
}

function clearCart() {
    if (cart.length > 0 && confirm('Futa vitu vyote?')) {
        cart = [];
        renderCart();
    }
}

function renderCart() {
    const cartItems = document.getElementById('cartItems');
    const cartTotal = document.getElementById('cartTotal');
    const cartCount = document.getElementById('cartCount');
    
    const saleType = document.getElementById('posSaleType')?.value || 'retail';
    
    if (cartItems) {
        cartItems.innerHTML = cart.map(item => {
            const price = saleType === 'wholesale' ? item.wholesalePrice : item.price;
            const total = price * item.quantity;
            return `
                <div class="cart-item">
                    <div>
                        <div class="fw-bold">${item.name}</div>
                        <div class="small text-muted">${formatCurrency(price)} x ${item.quantity}</div>
                    </div>
                    <div class="d-flex align-items-center gap-2">
                        <div class="qty-control">
                            <button onclick="updateCartItemQty('${item.productId}', -1)">-</button>
                            <input type="number" 
                                   min="1" 
                                   max="${item.maxStock}" 
                                   value="${item.quantity}" 
                                   onchange="setCartItemQty('${item.productId}', this.value)"
                                   onblur="setCartItemQty('${item.productId}', this.value)"
                                   onkeypress="if(event.key === 'Enter') { setCartItemQty('${item.productId}', this.value); this.blur(); }">
                            <button onclick="updateCartItemQty('${item.productId}', 1)">+</button>
                        </div>
                        <span class="fw-bold">${formatCurrency(total)}</span>
                        <button class="btn btn-sm btn-danger btn-icon" onclick="removeFromCart('${item.productId}')">
                            <i class="bi bi-x"></i>
                        </button>
                    </div>
                </div>
            `;
        }).join('') || '<p class="text-muted text-center p-4">Hakuna bidhaa kwenye kikapu</p>';
    }
    
    // Calculate total
    const subtotal = cart.reduce((sum, item) => {
        const price = saleType === 'wholesale' ? item.wholesalePrice : item.price;
        return sum + (price * item.quantity);
    }, 0);
    
    const discount = parseFloat(document.getElementById('posDiscount')?.value) || 0;
    const total = subtotal - discount;
    
    if (cartTotal) {
        cartTotal.textContent = formatCurrency(total);
    }
    
    if (cartCount) {
        cartCount.textContent = cart.reduce((sum, item) => sum + item.quantity, 0);
    }
}

async function completeSale() {
    if (cart.length === 0) {
        showToast('Hakuna bidhaa kwenye kikapu', 'danger');
        return;
    }
    
    const saleType = document.getElementById('posSaleType').value;
    const customerId = document.getElementById('posCustomer').value;
    const paymentMethod = document.getElementById('posPaymentMethod').value;
    const discount = parseFloat(document.getElementById('posDiscount').value) || 0;
    const isCredit = document.getElementById('posIsCredit').checked;
    const creditRequest = document.getElementById('posCreditRequest')?.checked || false;
    
    // Reception role: check if credit request needs customer
    if (currentUser && currentUser.role === 'reception' && creditRequest && !customerId) {
        showToast('Chagua mteja kwa ombi la mkopo', 'danger');
        return;
    }
    
    // Admin/Cashier: check if credit sale needs customer
    if (isCredit && !customerId && (!currentUser || currentUser.role !== 'reception')) {
        showToast('Chagua mteja kwa mauzo ya mkopo', 'danger');
        return;
    }
    
    const items = cart.map(item => ({
        productId: item.productId,
        quantity: item.quantity
    }));
    
    const data = {
        items,
        customerId: customerId || null,
        saleType,
        paymentMethod,
        discount,
        isCredit: (currentUser && currentUser.role === 'reception') ? false : isCredit, // Reception can't create credit sales directly
        creditRequest: (currentUser && currentUser.role === 'reception') ? creditRequest : false // Reception can request credit
    };
    
    const result = await api('/api/sales', { 
        method: 'POST', 
        body: JSON.stringify(data) 
    });
    
    if (result.success) {
        showToast(result.message);
        cart = [];
        document.getElementById('posDiscount').value = '';
        document.getElementById('posCustomer').value = '';
        document.getElementById('posCustomerSearch').value = '';
        document.getElementById('posIsCredit').checked = false;
        if (document.getElementById('posCreditRequest')) {
            document.getElementById('posCreditRequest').checked = false;
        }
        renderCart();
        await loadProducts(); // Refresh stock
        renderPOSProducts();
        
        // Only ask to print if order is completed (not pending verification)
        if (result.data.status === 'completed' && confirm('Chapisha risiti?')) {
            printReceipt(result.data.id);
        } else if (result.data.status === 'pending_verification') {
            showToast('Agizo limewasilishwa. Cashier atathibitisha na kukamilisha malipo.', 'info');
        }
    } else {
        showToast(result.message, 'danger');
    }
}

// =========================
// PURCHASES
// =========================
let purchaseItems = [];

async function loadPurchases(page = 1) {
    purchasesCurrentPage = page;
    const startDate = document.getElementById('purchasesStartDate')?.value;
    const endDate = document.getElementById('purchasesEndDate')?.value;
    
    const params = new URLSearchParams({ page, limit: PAGE_LIMIT });
    if (startDate) params.append('startDate', startDate);
    if (endDate) params.append('endDate', endDate);
    
    const result = await api('/api/purchases?' + params.toString());
    if (!result.success) return;
    
    // Load suppliers and products for purchase modal dropdowns
    await loadSuppliers();
    await loadProducts();
    
    allPurchases = result.data || [];
    purchasesTotalPages = result.pages || 1;
    
    renderPurchasesTable();
    renderPagination('purchasesPagination', purchasesCurrentPage, purchasesTotalPages, loadPurchases);
}

function filterPurchasesTable() {
    const searchInput = document.getElementById('purchasesSearchInput');
    if (!searchInput || !allPurchases) return;
    
    const searchTerm = searchInput.value.toLowerCase().trim();
    
    if (searchTerm === '') {
        renderPurchasesTableWithData(allPurchases);
    } else {
        const filtered = allPurchases.filter(p => {
            const searchText = `${p.invoiceNumber || ''} ${p.supplierName || ''} ${formatDateTime(p.createdAt) || ''}`.toLowerCase();
            return searchText.includes(searchTerm);
        });
        renderPurchasesTableWithData(filtered);
    }
}

function renderPurchasesTable() {
    renderPurchasesTableWithData(allPurchases);
}

function renderPurchasesTableWithData(purchases) {
    const tbody = document.getElementById('purchasesTableBody');
    if (!tbody) return;
    
    if (!purchases || purchases.length === 0) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">Hakuna matokeo yaliyopatikana</td></tr>';
        return;
    }
    
    const paymentTypeLabels = {
        'cash': 'Cash',
        'credit': 'Mkopo'
    };
    
    const paymentMethodLabels = {
        'cash': 'Cash',
        'bank': 'Bank Transfer',
        'mpesa': 'M-Pesa',
        'airtel': 'Airtel Money',
        'tigo': 'Tigo Pesa',
        'halopesa': 'Halo Pesa'
    };
    
    // Helper function to format payment method name
    function formatPaymentMethod(method) {
        if (paymentMethodLabels[method]) {
            return paymentMethodLabels[method];
        }
        // Convert snake_case or lowercase to Title Case
        return method.split('_').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
    }
    
    tbody.innerHTML = purchases.map(p => {
        const paymentType = p.paymentType || 'cash';
        const paymentMethod = p.paymentMethod || 'cash';
        const paymentTypeBadge = paymentType === 'credit' ? 'warning' : 'success';
        
        return `
        <tr>
            <td>${p.invoiceNumber}</td>
            <td>${formatDateTime(p.createdAt)}</td>
            <td>${p.supplierName}</td>
            <td>${formatCurrency(p.totalAmount)}</td>
            <td><span class="badge bg-${paymentTypeBadge}">${paymentTypeLabels[paymentType] || paymentType}</span></td>
            <td>${paymentType === 'cash' ? formatPaymentMethod(paymentMethod) : '-'}</td>
            <td><span class="badge bg-success">${p.status}</span></td>
            <td>
                <button class="btn btn-sm btn-info btn-icon" onclick="viewPurchaseDetails('${p.id}')" title="Angalia Maelezo">
                    <i class="bi bi-eye"></i>
                </button>
            </td>
        </tr>
        `;
    }).join('');
}

async function viewPurchaseDetails(purchaseId) {
    const result = await api(`/api/purchases/${purchaseId}`);
    if (!result.success) {
        showToast('Hitilafu katika kupata maelezo ya manunuzi', 'danger');
        return;
    }
    
    const purchase = result.data;
    const paymentMethodLabels = {
        'cash': 'Cash',
        'bank': 'Bank Transfer',
        'mpesa': 'M-Pesa',
        'airtel': 'Airtel Money',
        'tigo': 'Tigo Pesa',
        'halopesa': 'Halo Pesa'
    };
    
    function formatPaymentMethod(method) {
        if (paymentMethodLabels[method]) {
            return paymentMethodLabels[method];
        }
        return method ? method.split('_').map(word => 
            word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
        ).join(' ') : '-';
    }
    
    const modalHtml = `
        <div class="modal fade" id="purchaseDetailModal" tabindex="-1">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">Maelezo ya Manunuzi - ${purchase.invoiceNumber}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="row mb-4">
                            <div class="col-md-6">
                                <h6>Taarifa za Msambazaji</h6>
                                <p class="mb-1"><strong>Jina:</strong> ${purchase.supplierName}</p>
                                ${purchase.supplierDetails ? `
                                    <p class="mb-1"><strong>Simu:</strong> ${purchase.supplierDetails.phone || '-'}</p>
                                    <p class="mb-1"><strong>Email:</strong> ${purchase.supplierDetails.email || '-'}</p>
                                ` : ''}
                            </div>
                            <div class="col-md-6">
                                <h6>Taarifa za Manunuzi</h6>
                                <p class="mb-1"><strong>Tarehe:</strong> ${formatDateTime(purchase.createdAt)}</p>
                                <p class="mb-1"><strong>Invoice:</strong> ${purchase.invoiceNumber}</p>
                                <p class="mb-1"><strong>Jumla:</strong> ${formatCurrency(purchase.totalAmount)}</p>
                                <p class="mb-1">
                                    <strong>Aina ya Malipo:</strong> 
                                    <span class="badge bg-${purchase.paymentType === 'credit' ? 'warning' : 'success'}">
                                        ${purchase.paymentType === 'credit' ? 'Mkopo' : 'Cash'}
                                    </span>
                                </p>
                                ${purchase.paymentType === 'cash' ? `
                                    <p class="mb-1"><strong>Njia ya Malipo:</strong> ${formatPaymentMethod(purchase.paymentMethod)}</p>
                                ` : ''}
                            </div>
                        </div>
                        
                        ${purchase.paymentType === 'credit' ? `
                            <div class="alert alert-info mb-4">
                                <h6>Hali ya Deni</h6>
                                <div class="row">
                                    <div class="col-md-4">
                                        <p class="mb-1"><strong>Jumla ya Deni:</strong> ${formatCurrency(purchase.totalAmount)}</p>
                                    </div>
                                    <div class="col-md-4">
                                        <p class="mb-1"><strong>Kiasi Kilicholipwa:</strong> ${formatCurrency(purchase.totalPaid)}</p>
                                    </div>
                                    <div class="col-md-4">
                                        <p class="mb-1"><strong>Deni Baki:</strong> <span class="text-danger fw-bold">${formatCurrency(purchase.remainingBalance)}</span></p>
                                    </div>
                                </div>
                            </div>
                            
                            ${purchase.paymentHistory && purchase.paymentHistory.length > 0 ? `
                                <h6 class="mb-3">Historia ya Malipo</h6>
                                <div class="table-responsive">
                                    <table class="table table-sm">
                                        <thead>
                                            <tr>
                                                <th>Tarehe</th>
                                                <th>Kiasi</th>
                                                <th>Njia ya Malipo</th>
                                                <th>Reference</th>
                                                <th>Maelezo</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            ${purchase.paymentHistory.map(payment => `
                                                <tr>
                                                    <td>${formatDateTime(payment.createdAt)}</td>
                                                    <td>${formatCurrency(payment.amount)}</td>
                                                    <td>${formatPaymentMethod(payment.paymentMethod)}</td>
                                                    <td>${payment.reference || '-'}</td>
                                                    <td>${payment.notes || '-'}</td>
                                                </tr>
                                            `).join('')}
                                        </tbody>
                                    </table>
                                </div>
                            ` : '<p class="text-muted">Bado hakuna malipo yaliyorekodiwa</p>'}
                        ` : ''}
                        
                        <h6 class="mb-3">Bidhaa Zinazonunuliwa</h6>
                        <div class="table-responsive">
                            <table class="table table-sm">
                                <thead>
                                    <tr>
                                        <th>Bidhaa</th>
                                        <th>Kiasi</th>
                                        <th>Bei ya Ununuzi</th>
                                        <th>Jumla</th>
                                        <th>Batch</th>
                                        ${purchase.items.some(item => item.expiryDate) ? '<th>Expiry</th>' : ''}
                                    </tr>
                                </thead>
                                <tbody>
                                    ${purchase.items.map(item => `
                                        <tr>
                                            <td>${item.productName || 'N/A'}</td>
                                            <td>${item.quantity} ${item.productUnit || 'pcs'}</td>
                                            <td>${formatCurrency(item.costPrice)}</td>
                                            <td>${formatCurrency(item.quantity * item.costPrice)}</td>
                                            <td>${item.batchNumber || '-'}</td>
                                            ${item.expiryDate ? `<td>${formatDate(item.expiryDate)}</td>` : ''}
                                        </tr>
                                    `).join('')}
                                </tbody>
                                <tfoot>
                                    <tr>
                                        <td colspan="${purchase.items.some(item => item.expiryDate) ? '5' : '4'}" class="text-end fw-bold">JUMLA:</td>
                                        <td class="fw-bold">${formatCurrency(purchase.totalAmount)}</td>
                                    </tr>
                                </tfoot>
                            </table>
                        </div>
                        
                        ${purchase.notes ? `
                            <div class="mt-3">
                                <h6>Maelezo</h6>
                                <p class="text-muted">${purchase.notes}</p>
                            </div>
                        ` : ''}
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Funga</button>
                    </div>
                </div>
            </div>
        </div>
    `;
    
    // Remove existing modal if any
    const existingModal = document.getElementById('purchaseDetailModal');
    if (existingModal) {
        existingModal.remove();
    }
    
    // Add modal to body
    document.body.insertAdjacentHTML('beforeend', modalHtml);
    
    // Show modal
    const modal = new bootstrap.Modal(document.getElementById('purchaseDetailModal'));
    modal.show();
    
    // Clean up when modal is hidden
    document.getElementById('purchaseDetailModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
    });
}

async function showPurchaseModal() {
    try {
        purchaseItems = [];
        document.getElementById('purchaseInvoice').value = '';
        document.getElementById('purchaseNotes').value = '';
        document.getElementById('purchasePaymentType').value = 'cash';
        updatePurchasePaymentMethodVisibility();
        
        // Load dropdowns and payment methods before showing modal
        await Promise.all([
            loadSupplierOptions('purchaseSupplier'),
            populatePaymentMethods()
        ]);
        
        // Ensure products are loaded for search
        if (!products || products.length === 0) {
            await loadProducts();
        }
        
        // Clear product search field
        document.getElementById('purchaseProduct').value = '';
        document.getElementById('purchaseProductSearch').value = '';
        document.getElementById('purchaseProductList').innerHTML = '';
        document.getElementById('purchaseProductList').style.display = 'none';
        
        document.getElementById('purchasePaymentMethod').value = 'cash';
        
        renderPurchaseItems();
        
        // Show modal after dropdowns are loaded
        const modalElement = document.getElementById('purchaseModal');
        const modal = new bootstrap.Modal(modalElement);
        modal.show();
    } catch (error) {
        console.error('Error opening purchase modal:', error);
        showToast('Hitilafu katika kufungua fomu ya manunuzi', 'danger');
    }
}

function updatePurchasePaymentMethodVisibility() {
    const paymentType = document.getElementById('purchasePaymentType').value;
    const paymentMethodContainer = document.getElementById('purchasePaymentMethodContainer');
    const paymentMethod = document.getElementById('purchasePaymentMethod');
    const paymentMethodOther = document.getElementById('purchasePaymentMethodOther');
    
    if (paymentType === 'cash') {
        paymentMethodContainer.style.display = 'block';
        paymentMethod.required = true;
        handlePaymentMethodChange();
    } else {
        paymentMethodContainer.style.display = 'none';
        paymentMethod.required = false;
        paymentMethod.value = '';
        if (paymentMethodOther) {
            paymentMethodOther.style.display = 'none';
            paymentMethodOther.value = '';
        }
    }
}

function handlePaymentMethodChange() {
    const paymentMethod = document.getElementById('purchasePaymentMethod').value;
    const paymentMethodOther = document.getElementById('purchasePaymentMethodOther');
    
    if (paymentMethod === 'other') {
        paymentMethodOther.style.display = 'block';
        paymentMethodOther.required = true;
    } else {
        paymentMethodOther.style.display = 'none';
        paymentMethodOther.required = false;
        paymentMethodOther.value = '';
    }
}

async function loadPaymentMethods() {
    const result = await api('/api/settings');
    if (!result.success) return [];
    
    const settings = result.data;
    return settings.paymentMethods || ['cash', 'bank', 'mpesa', 'airtel', 'tigo', 'halopesa'];
}

async function populatePaymentMethods() {
    const paymentMethodSelect = document.getElementById('purchasePaymentMethod');
    if (!paymentMethodSelect) return;
    
    const paymentMethods = await loadPaymentMethods();
    const paymentMethodLabels = {
        'cash': 'Cash (Pesa taslimu)',
        'bank': 'Bank Transfer',
        'mpesa': 'M-Pesa',
        'airtel': 'Airtel Money',
        'tigo': 'Tigo Pesa',
        'halopesa': 'Halo Pesa'
    };
    
    // Helper to format custom method names
    function formatMethodName(method) {
        if (paymentMethodLabels[method]) {
            return paymentMethodLabels[method];
        }
        // Convert snake_case to Title Case with spaces
        return method.split('_').map(word => 
            word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
        ).join(' ');
    }
    
    // Get current value before updating
    const currentValue = paymentMethodSelect.value;
    
    // Clear and populate with saved methods
    paymentMethodSelect.innerHTML = '';
    
    paymentMethods.forEach(method => {
        const option = document.createElement('option');
        option.value = method;
        option.textContent = formatMethodName(method);
        paymentMethodSelect.appendChild(option);
    });
    
    // Add "Other" option
    const otherOption = document.createElement('option');
    otherOption.value = 'other';
    otherOption.textContent = 'Nyingine';
    paymentMethodSelect.appendChild(otherOption);
    
    // Restore previous value if it exists
    if (currentValue && Array.from(paymentMethodSelect.options).some(opt => opt.value === currentValue)) {
        paymentMethodSelect.value = currentValue;
    }
}

function addPurchaseItem() {
    const productId = document.getElementById('purchaseProduct').value;
    const quantity = parseInt(document.getElementById('purchaseQty').value);
    const costPrice = parseFloat(document.getElementById('purchaseCostPrice').value);
    const batchNumber = document.getElementById('purchaseBatch').value;
    const expiryDate = document.getElementById('purchaseExpiry').value;
    
    if (!productId || !quantity || !costPrice) {
        showToast('Jaza taarifa zote (Bidhaa, Kiasi, na Cost Price)', 'danger');
        return;
    }
    
    const product = products.find(p => p.id === productId);
    
    purchaseItems.push({
        productId,
        productName: product ? product.name : 'N/A',
        quantity,
        costPrice,
        batchNumber,
        expiryDate,
        total: quantity * costPrice
    });
    
    // Clear inputs
    document.getElementById('purchaseProduct').value = '';
    document.getElementById('purchaseProductSearch').value = '';
    document.getElementById('purchaseProductList').innerHTML = '';
    document.getElementById('purchaseProductList').style.display = 'none';
    document.getElementById('purchaseQty').value = '';
    document.getElementById('purchaseCostPrice').value = '';
    document.getElementById('purchaseBatch').value = '';
    document.getElementById('purchaseExpiry').value = '';
    
    renderPurchaseItems();
}

let purchaseProducts = [];

function showPurchaseProductList() {
    const list = document.getElementById('purchaseProductList');
    const searchInput = document.getElementById('purchaseProductSearch');
    if (!list || !searchInput) return;
    
    const searchTerm = (searchInput.value || '').trim();
    
    // If input is empty or has value, filter and show
    if (searchTerm === '') {
        // Show all products when input is empty
        filterPurchaseProducts('');
    } else {
        // Filter based on current search term
        filterPurchaseProducts(searchTerm);
    }
}

function hidePurchaseProductList() {
    const list = document.getElementById('purchaseProductList');
    if (list) {
        list.style.display = 'none';
    }
}

function filterPurchaseProducts(searchTerm) {
    const list = document.getElementById('purchaseProductList');
    const hiddenInput = document.getElementById('purchaseProduct');
    const searchInput = document.getElementById('purchaseProductSearch');
    if (!list || !hiddenInput || !searchInput) return;
    
    const term = (searchTerm || '').toLowerCase().trim();
    
    // Filter active products
    const activeProducts = products.filter(p => p.status === 'active');
    
    // If search is empty, show all products (but don't clear selection)
    const filtered = term === '' 
        ? activeProducts.slice(0, 20)
        : activeProducts.filter(p => {
            const searchText = `${p.name || ''} ${p.sku || ''}`.toLowerCase();
            return searchText.includes(term);
        }).slice(0, 20);
    
    purchaseProducts = filtered;
    
    if (filtered.length === 0) {
        list.innerHTML = '<div class="dropdown-item-text text-muted">Hakuna bidhaa zilizopatikana</div>';
        list.style.display = 'block';
        return;
    }
    
    // Show filtered products - escape product names properly for onclick
    list.innerHTML = filtered.map(p => {
        const safeName = (p.name || '').replace(/'/g, "&#39;").replace(/"/g, '&quot;').replace(/\n/g, ' ');
        const productId = p.id || '';
        const stock = p.currentStock || 0;
        const unit = p.unit || 'pcs';
        return `
            <a class="dropdown-item" href="#" onclick="selectPurchaseProduct('${productId}', '${safeName}', '${stock}', '${unit}'); event.stopPropagation(); return false;" onmousedown="event.preventDefault();">
                <div class="fw-bold">${p.name || 'N/A'}</div>
                <small class="text-muted">SKU: ${p.sku || 'N/A'} | Stock: ${stock} ${unit}</small>
            </a>
        `;
    }).join('');
    
    list.style.display = 'block';
}

function selectPurchaseProduct(productId, productName, currentStock, unit) {
    try {
        const hiddenInput = document.getElementById('purchaseProduct');
        const searchInput = document.getElementById('purchaseProductSearch');
        const list = document.getElementById('purchaseProductList');
        
        if (!hiddenInput || !searchInput) {
            console.error('Purchase product inputs not found');
            return;
        }
        
        // Decode HTML entities in product name
        const decodedName = productName.replace(/&#39;/g, "'").replace(/&quot;/g, '"');
        
        // Set the hidden input with product ID
        hiddenInput.value = productId || '';
        
        // Set the visible search input with product name and stock info
        searchInput.value = decodedName ? `${decodedName} (${currentStock || 0} ${unit || 'pcs'})` : '';
        
        // Hide the dropdown
        if (list) {
            list.style.display = 'none';
            list.innerHTML = '';
        }
        
        // Focus back on the search input (optional - helps with UX)
        searchInput.focus();
    } catch (error) {
        console.error('Error selecting purchase product:', error);
        showToast('Hitilafu katika kuchagua bidhaa', 'danger');
    }
}

function removePurchaseItem(index) {
    purchaseItems.splice(index, 1);
    renderPurchaseItems();
}

function renderPurchaseItems() {
    const container = document.getElementById('purchaseItemsList');
    const totalEl = document.getElementById('purchaseTotal');
    
    if (container) {
        container.innerHTML = purchaseItems.map((item, index) => `
            <tr>
                <td>${item.productName}</td>
                <td>${item.quantity}</td>
                <td>${formatCurrency(item.costPrice)}</td>
                <td>${formatCurrency(item.total)}</td>
                <td>
                    <button class="btn btn-sm btn-danger btn-icon" onclick="removePurchaseItem(${index})">
                        <i class="bi bi-trash"></i>
                    </button>
                </td>
            </tr>
        `).join('') || '<tr><td colspan="5" class="text-center text-muted">Hakuna bidhaa</td></tr>';
    }
    
    const total = purchaseItems.reduce((sum, item) => sum + item.total, 0);
    if (totalEl) {
        totalEl.textContent = formatCurrency(total);
    }
}

async function savePurchase() {
    if (purchaseItems.length === 0) {
        showToast('Ongeza bidhaa kwanza', 'danger');
        return;
    }
    
    const supplierId = document.getElementById('purchaseSupplier').value;
    if (!supplierId) {
        showToast('Chagua msambazaji', 'danger');
        return;
    }
    
    const paymentType = document.getElementById('purchasePaymentType').value;
    if (!paymentType) {
        showToast('Chagua aina ya malipo', 'danger');
        return;
    }
    
    let paymentMethod = null;
    if (paymentType === 'cash') {
        const selectedMethod = document.getElementById('purchasePaymentMethod').value;
        if (!selectedMethod) {
            showToast('Chagua njia ya malipo', 'danger');
            return;
        }
        
        if (selectedMethod === 'other') {
            const otherMethod = document.getElementById('purchasePaymentMethodOther').value.trim();
            if (!otherMethod) {
                showToast('Andika njia ya malipo', 'danger');
                return;
            }
            paymentMethod = otherMethod.toLowerCase().replace(/\s+/g, '_'); // Normalize: lowercase with underscores
        } else {
            paymentMethod = selectedMethod;
        }
    }
    
    const data = {
        supplierId,
        items: purchaseItems.map(item => ({
            productId: item.productId,
            quantity: item.quantity,
            costPrice: item.costPrice,
            batchNumber: item.batchNumber,
            expiryDate: item.expiryDate
        })),
        invoiceNumber: document.getElementById('purchaseInvoice').value,
        notes: document.getElementById('purchaseNotes').value,
        paymentType: paymentType,
        paymentMethod: paymentMethod,
        paymentMethodCustom: paymentMethod && document.getElementById('purchasePaymentMethod').value === 'other' ? document.getElementById('purchasePaymentMethodOther').value.trim() : null
    };
    
    const result = await api('/api/purchases', { 
        method: 'POST', 
        body: JSON.stringify(data) 
    });
    
    if (result.success) {
        showToast(result.message);
        bootstrap.Modal.getInstance(document.getElementById('purchaseModal')).hide();
        purchaseItems = [];
        await loadPurchases();
        await loadProducts();
    } else {
        showToast(result.message, 'danger');
    }
}

// =========================
// POS IMPROVEMENTS
// =========================
async function loadPOS() {
    await loadProducts();
    await loadCustomers();
    await loadSuppliers();
    renderPOSProducts();
    renderCart();
    loadCustomerOptions();
    
    // Hide credit checkbox for reception role, show credit request instead
    const creditContainer = document.getElementById('posCreditCheckContainer');
    const creditRequestContainer = document.getElementById('posCreditRequestContainer');
    if (creditContainer && creditRequestContainer && currentUser && currentUser.role === 'reception') {
        creditContainer.style.display = 'none';
        creditRequestContainer.style.display = 'block';
    } else if (creditContainer && creditRequestContainer) {
        creditContainer.style.display = 'block';
        creditRequestContainer.style.display = 'none';
    }
    
    // Update button text for reception
    const completeBtn = document.querySelector('button[onclick="completeSale()"]');
    if (completeBtn && currentUser && currentUser.role === 'reception') {
        completeBtn.innerHTML = '<i class="bi bi-send me-2"></i>Wasilisha Agizo';
    } else if (completeBtn) {
        completeBtn.innerHTML = '<i class="bi bi-check-circle me-2"></i>Maliza Mauzo';
    }
    
    // Setup search
    const searchInput = document.getElementById('posSearchProduct');
    if (searchInput) {
        searchInput.addEventListener('input', function() {
            const query = this.value.toLowerCase();
            renderPOSProducts(query);
        });
    }
}

function loadCustomerOptions() {
    // This function is kept for compatibility but no longer needed
    // Customer selection is now handled by searchable input
}

function filterPOSCustomers(searchTerm) {
    const list = document.getElementById('posCustomerList');
    const hiddenInput = document.getElementById('posCustomer');
    const searchInput = document.getElementById('posCustomerSearch');
    if (!list || !hiddenInput || !searchInput) return;
    
    // If search is cleared, show "Walk-in Customer" option but don't clear existing selection
    if (!searchTerm || searchTerm.trim() === '') {
        list.innerHTML = '<a class="dropdown-item" href="#" onclick="selectPOSCustomer(\'\', \'Walk-in Customer\'); return false;"><div class="fw-bold">Walk-in Customer</div></a>';
        list.style.display = 'block';
        return;
    }
    
    const term = searchTerm.toLowerCase().trim();
    
    // Filter active customers
    const activeCustomers = customers.filter(c => c.status !== 'inactive');
    
    // Filter by search term (name, business name, phone)
    const filtered = activeCustomers.filter(c => {
        const searchText = `${c.name || ''} ${c.businessName || ''} ${c.phone || ''}`.toLowerCase();
        return searchText.includes(term);
    });
    
    if (filtered.length === 0) {
        list.innerHTML = '<div class="dropdown-item-text text-muted">Hakuna mteja aliyepatikana</div>';
        list.style.display = 'block';
        return;
    }
    
    // Show filtered customers (limit to 20 for performance)
    list.innerHTML = filtered.slice(0, 20).map(c => `
        <a class="dropdown-item" href="#" onclick="selectPOSCustomer('${c.id}', '${(c.name || '').replace(/'/g, "\\'")}${c.businessName ? ' (' + (c.businessName || '').replace(/'/g, "\\'") + ')' : ''}'); return false;">
            <div class="fw-bold">${c.name || 'N/A'}</div>
            <small class="text-muted">${c.businessName || 'N/A'}${c.phone ? ' | ' + c.phone : ''}</small>
        </a>
    `).join('');
    
    list.style.display = 'block';
}

function showPOSCustomerList() {
    const list = document.getElementById('posCustomerList');
    const searchInput = document.getElementById('posCustomerSearch');
    if (!list || !searchInput) return;
    
    // If input is empty or matches the current selected value, show "Walk-in Customer" option
    const currentValue = searchInput.value.trim();
    if (!currentValue || currentValue === 'Walk-in Customer') {
        list.innerHTML = '<a class="dropdown-item" href="#" onclick="selectPOSCustomer(\'\', \'Walk-in Customer\'); return false;"><div class="fw-bold">Walk-in Customer</div></a>';
        list.style.display = 'block';
    } else if (list.innerHTML.trim() !== '') {
        // If there are already filtered results, just show them
        list.style.display = 'block';
    } else {
        // If no results but input has value, trigger filter
        filterPOSCustomers(currentValue);
    }
}

function hidePOSCustomerList() {
    const list = document.getElementById('posCustomerList');
    if (list) {
        list.style.display = 'none';
    }
}

function selectPOSCustomer(customerId, customerDisplayName) {
    const hiddenInput = document.getElementById('posCustomer');
    const searchInput = document.getElementById('posCustomerSearch');
    const list = document.getElementById('posCustomerList');
    
    // Set values - ensure customerDisplayName is set even if empty
    if (hiddenInput) {
        hiddenInput.value = customerId || '';
    }
    if (searchInput) {
        searchInput.value = customerDisplayName || 'Walk-in Customer';
    }
    if (list) {
        list.style.display = 'none';
    }
}

function renderPOSProducts(searchQuery = '') {
    const grid = document.getElementById('posProductGrid');
    if (!grid) {
        console.error('POS product grid element not found');
        return;
    }
    
    // Ensure products array exists
    if (!products || !Array.isArray(products)) {
        console.error('Products array not available');
        grid.innerHTML = '<p class="text-muted text-center p-4">Hakuna bidhaa (Inapakia...)</p>';
        return;
    }
    
    // Filter active products with stock > 0
    // Handle cases where currentStock might be undefined or null
    let filteredProducts = products.filter(p => {
        if (!p || p.status !== 'active') return false;
        const stock = p.currentStock || 0;
        return stock > 0;
    });
    
    if (searchQuery) {
        const query = searchQuery.toLowerCase().trim();
        filteredProducts = filteredProducts.filter(p => {
            const name = (p.name || '').toLowerCase();
            const sku = (p.sku || '').toLowerCase();
            const barcode = (p.barcode || '').toLowerCase();
            return name.includes(query) || sku.includes(query) || barcode.includes(query);
        });
    }
    
    if (filteredProducts.length === 0) {
        grid.innerHTML = '<p class="text-muted text-center p-4">Hakuna bidhaa zilizopatikana</p>';
        return;
    }
    
    // Escape HTML to prevent XSS issues
    grid.innerHTML = filteredProducts.map(p => {
        const name = (p.name || 'N/A').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
        const price = formatCurrency(p.retailPrice || 0);
        const stock = p.currentStock || 0;
        const unit = p.unit || 'pcs';
        const productId = p.id || '';
        
        return `
        <div class="product-card" onclick="addToCart('${productId}')">
            <div class="name">${name}</div>
            <div class="price">${price}</div>
            <div class="stock">Stock: ${stock} ${unit}</div>
        </div>
        `;
    }).join('');
}

// =========================
// ADDITIONAL HELPERS
// =========================
async function viewCustomerStatement(customerId) {
    const result = await api(`/api/customers/${customerId}/statement`);
    if (!result.success) return;
    
    const data = result.data;
    const modalHtml = `
        <div class="modal fade" id="statementModal" tabindex="-1">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">Statement - ${data.customer.name}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="row mb-4">
                            <div class="col-md-4">
                                <h6>Mteja</h6>
                                <p class="mb-0">${data.customer.name}</p>
                                <p class="text-muted">${data.customer.phone || ''}</p>
                            </div>
                            <div class="col-md-4">
                                <h6>Jumla ya Mauzo</h6>
                                <p class="mb-0 fs-5">${formatCurrency(data.summary.totalSales)}</p>
                            </div>
                            <div class="col-md-4">
                                <h6>Deni Baki</h6>
                                <p class="mb-0 fs-5 text-danger">${formatCurrency(data.summary.balance)}</p>
                            </div>
                        </div>
                        
                        <h6>Historia ya Mauzo</h6>
                        <table class="table table-sm">
                            <thead>
                                <tr>
                                    <th>Tarehe</th>
                                    <th>Risiti</th>
                                    <th>Jumla</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${data.sales.map(s => `
                                    <tr>
                                        <td>${formatDate(s.createdAt)}</td>
                                        <td>${s.receiptNumber}</td>
                                        <td>${formatCurrency(s.totalAmount)}</td>
                                    </tr>
                                `).join('') || '<tr><td colspan="3" class="text-muted">Hakuna mauzo</td></tr>'}
                            </tbody>
                        </table>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Funga</button>
                    </div>
                </div>
            </div>
        </div>
    `;
    
    // Remove existing modal if any
    const existingModal = document.getElementById('statementModal');
    if (existingModal) {
        existingModal.remove();
    }
    
    document.body.insertAdjacentHTML('beforeend', modalHtml);
    new bootstrap.Modal(document.getElementById('statementModal')).show();
}

async function viewSale(saleId) {
    const result = await api('/api/sales');
    if (!result.success) return;
    
    const sale = result.data.find(s => s.id === saleId);
    if (!sale) return;
    
    const modalHtml = `
        <div class="modal fade" id="saleDetailModal" tabindex="-1">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">Mauzo - ${sale.receiptNumber}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <p><strong>Tarehe:</strong> ${formatDateTime(sale.createdAt)}</p>
                        <p><strong>Mteja:</strong> ${sale.customerName}</p>
                        <p><strong>Aina:</strong> ${sale.saleType === 'wholesale' ? 'Jumla' : 'Rejareja'}</p>
                        <p><strong>Malipo:</strong> ${sale.paymentMethod.toUpperCase()}</p>
                        
                        <h6 class="mt-3">Bidhaa</h6>
                        <table class="table table-sm">
                            <thead>
                                <tr>
                                    <th>Bidhaa</th>
                                    <th>Qty</th>
                                    <th>Bei</th>
                                    <th>Jumla</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${sale.items.map(item => `
                                    <tr>
                                        <td>${item.productName}</td>
                                        <td>${item.quantity}</td>
                                        <td>${formatCurrency(item.price)}</td>
                                        <td>${formatCurrency(item.total)}</td>
                                    </tr>
                                `).join('')}
                            </tbody>
                            <tfoot>
                                <tr>
                                    <td colspan="3" class="text-end"><strong>Subtotal:</strong></td>
                                    <td>${formatCurrency(sale.subtotal)}</td>
                                </tr>
                                ${sale.discount > 0 ? `
                                    <tr>
                                        <td colspan="3" class="text-end">Discount:</td>
                                        <td>-${formatCurrency(sale.discount)}</td>
                                    </tr>
                                ` : ''}
                                <tr>
                                    <td colspan="3" class="text-end"><strong>JUMLA:</strong></td>
                                    <td><strong>${formatCurrency(sale.totalAmount)}</strong></td>
                                </tr>
                            </tfoot>
                        </table>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Funga</button>
                        <button type="button" class="btn btn-primary" onclick="printReceipt('${sale.id}')">
                            <i class="bi bi-printer me-1"></i>Chapisha
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;
    
    const existingModal = document.getElementById('saleDetailModal');
    if (existingModal) {
        existingModal.remove();
    }
    
    document.body.insertAdjacentHTML('beforeend', modalHtml);
    new bootstrap.Modal(document.getElementById('saleDetailModal')).show();
}

function viewStockDetails(productId) {
    // Navigate to stock page with filter
    navigateTo('stock');
}

function showStockAdjustModal(productId) {
    const product = products.find(p => p.id === productId);
    if (!product) return;
    
    const modalHtml = `
        <div class="modal fade" id="stockAdjustModal" tabindex="-1">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">Sahihisha Stock - ${product.name}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <p><strong>Stock ya Sasa:</strong> ${product.currentStock} ${product.unit}</p>
                        <div class="mb-3">
                            <label class="form-label">Stock Halisi</label>
                            <input type="number" class="form-control" id="adjustActualQty" value="${product.currentStock}">
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Sababu</label>
                            <input type="text" class="form-control" id="adjustReason" placeholder="Mfano: Inventory count">
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Ghairi</button>
                        <button type="button" class="btn btn-primary" onclick="saveStockAdjustment('${productId}')">Hifadhi</button>
                    </div>
                </div>
            </div>
        </div>
    `;
    
    const existingModal = document.getElementById('stockAdjustModal');
    if (existingModal) {
        existingModal.remove();
    }
    
    document.body.insertAdjacentHTML('beforeend', modalHtml);
    new bootstrap.Modal(document.getElementById('stockAdjustModal')).show();
}

async function saveStockAdjustment(productId) {
    const actualQty = document.getElementById('adjustActualQty').value;
    const reason = document.getElementById('adjustReason').value;
    
    const result = await api('/api/stock/adjust', {
        method: 'POST',
        body: JSON.stringify({
            productId,
            actualQuantity: actualQty,
            reason
        })
    });
    
    if (result.success) {
        showToast('Stock imesahihishwa');
        bootstrap.Modal.getInstance(document.getElementById('stockAdjustModal')).hide();
        await loadStock();
        await loadProducts();
    } else {
        showToast(result.message, 'danger');
    }
}

// Password confirmation function
async function confirmDeleteAction() {
    const password = document.getElementById('passwordConfirmInput').value;
    if (!password) {
        showToast('Tafadhali ingiza nenosiri la admin', 'danger');
        return;
    }
    
    if (!pendingDeleteAction) {
        showToast('Hitilafu: hakuna kitendo cha kufuta', 'danger');
        return;
    }
    
    // Close modal
    const modal = bootstrap.Modal.getInstance(document.getElementById('passwordConfirmModal'));
    if (modal) modal.hide();
    
    // Execute the delete action
    await pendingDeleteAction.callback(password);
    
    // Clear pending action
    pendingDeleteAction = null;
}

// =========================
// PENDING ORDERS (CASHIER)
// =========================
let allPendingOrders = [];

async function loadPendingOrders() {
    const result = await api('/api/sales/pending');
    if (!result.success) return;
    
    const orders = result.data || [];
    allPendingOrders = [...orders];
    
    renderPendingOrdersTable();
}

function filterPendingOrdersTable() {
    const searchInput = document.getElementById('pendingOrdersSearchInput');
    if (!searchInput || !allPendingOrders) return;
    
    const searchTerm = searchInput.value.toLowerCase().trim();
    
    if (searchTerm === '') {
        renderPendingOrdersTableWithData(allPendingOrders);
    } else {
        const filtered = allPendingOrders.filter(order => {
            const searchText = `${order.receiptNumber || ''} ${order.customerName || ''} ${order.receptionistName || ''}`.toLowerCase();
            return searchText.includes(searchTerm);
        });
        renderPendingOrdersTableWithData(filtered);
    }
}

function renderPendingOrdersTable() {
    renderPendingOrdersTableWithData(allPendingOrders);
}

function renderPendingOrdersTableWithData(orders) {
    const tbody = document.getElementById('pendingOrdersTableBody');
    if (!tbody) return;
    
    if (!orders || orders.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted">Hakuna agizo za kuthibitisha</td></tr>';
        return;
    }
    
    tbody.innerHTML = orders.map(order => `
        <tr>
            <td>${formatDateTime(order.createdAt)}</td>
            <td><strong>${order.receiptNumber}</strong></td>
            <td>${order.customerName || 'Walk-in Customer'}</td>
            <td><span class="badge bg-info">${order.saleType === 'wholesale' ? 'Jumla' : 'Rejareja'}</span></td>
            <td><strong>${formatCurrency(order.totalAmount)}</strong></td>
            <td>${order.receptionistName || 'N/A'}</td>
            <td>
                ${order.creditRequest ? '<span class="badge bg-warning me-2">Ombi la Mkopo</span>' : ''}
                <button class="btn btn-sm btn-success btn-icon" onclick="verifyOrder('${order.id}')" title="Thibitisha">
                    <i class="bi bi-check-circle"></i> Thibitisha
                </button>
                <button class="btn btn-sm btn-primary btn-icon" onclick="viewPendingOrder('${order.id}')" title="Angalia">
                    <i class="bi bi-eye"></i>
                </button>
            </td>
        </tr>
    `).join('');
}

async function verifyOrder(orderId) {
    const order = allPendingOrders.find(o => o.id === orderId);
    if (!order) return;
    
    // Show modal for payment confirmation
    document.getElementById('verifyOrderId').value = orderId;
    document.getElementById('verifyOrderReceipt').textContent = order.receiptNumber;
    document.getElementById('verifyOrderTotal').textContent = formatCurrency(order.totalAmount);
    document.getElementById('verifyPaymentMethod').value = order.paymentMethod || 'cash';
    
    // Show credit request status
    const creditRequestAlert = document.getElementById('verifyCreditRequestAlert');
    if (creditRequestAlert) {
        if (order.creditRequest) {
            creditRequestAlert.style.display = 'block';
            creditRequestAlert.innerHTML = `
                <i class="bi bi-info-circle me-2"></i>
                <strong>Ombi la Mkopo:</strong> Reception amewasilisha agizo hili kama ombi la mkopo. 
                Mteja anataka mkopo. Tafadhali thibitisha na uweke kama mkopo.
            `;
            // Pre-check credit if it's a credit request
            document.getElementById('verifyIsCredit').checked = true;
        } else {
            creditRequestAlert.style.display = 'none';
            document.getElementById('verifyIsCredit').checked = false;
        }
    } else {
        document.getElementById('verifyIsCredit').checked = false;
    }
    
    new bootstrap.Modal(document.getElementById('verifyOrderModal')).show();
}

async function confirmVerifyOrder() {
    const orderId = document.getElementById('verifyOrderId').value;
    const paymentMethod = document.getElementById('verifyPaymentMethod').value;
    const isCredit = document.getElementById('verifyIsCredit').checked;
    const customerId = allPendingOrders.find(o => o.id === orderId)?.customerId;
    
    if (isCredit && !customerId) {
        showToast('Agizo hili halina mteja. Hakuna mauzo ya mkopo bila mteja.', 'danger');
        return;
    }
    
    const result = await api(`/api/sales/${orderId}/verify`, {
        method: 'POST',
        body: JSON.stringify({ paymentMethod, isCredit })
    });
    
    if (result.success) {
        showToast(result.message);
        bootstrap.Modal.getInstance(document.getElementById('verifyOrderModal')).hide();
        await loadPendingOrders();
    } else {
        showToast(result.message, 'danger');
    }
}

function viewPendingOrder(orderId) {
    const order = allPendingOrders.find(o => o.id === orderId);
    if (!order) {
        console.error('Order not found:', orderId);
        showToast('Agizo halijapatikana', 'danger');
        return;
    }
    
    try {
        // Populate modal
        const receiptEl = document.getElementById('viewPendingOrderReceipt');
        const dateEl = document.getElementById('viewPendingOrderDate');
        const customerEl = document.getElementById('viewPendingOrderCustomer');
        const typeEl = document.getElementById('viewPendingOrderType');
        const totalHeaderEl = document.getElementById('viewPendingOrderTotalHeader');
        const subtotalEl = document.getElementById('viewPendingOrderSubtotal');
        const discountEl = document.getElementById('viewPendingOrderDiscount');
        const totalEl = document.getElementById('viewPendingOrderTotal');
        const itemsList = document.getElementById('viewPendingOrderItems');
        
        if (!receiptEl || !dateEl || !customerEl || !typeEl || !totalHeaderEl || 
            !subtotalEl || !discountEl || !totalEl || !itemsList) {
            console.error('Modal elements not found');
            showToast('Hitilafu katika kuonyesha agizo', 'danger');
            return;
        }
        
        receiptEl.textContent = order.receiptNumber || 'N/A';
        dateEl.textContent = formatDateTime(order.createdAt);
        customerEl.textContent = order.customerName || 'Walk-in Customer';
        typeEl.textContent = order.saleType === 'wholesale' ? 'Jumla' : 'Rejareja';
        totalHeaderEl.textContent = formatCurrency(order.totalAmount || 0);
        subtotalEl.textContent = formatCurrency(order.subtotal || order.totalAmount || 0);
        discountEl.textContent = formatCurrency(order.discount || 0);
        totalEl.textContent = formatCurrency(order.totalAmount || 0);
        
        // Show credit request status
        const creditRequestBadge = document.getElementById('viewPendingOrderCreditRequest');
        if (creditRequestBadge) {
            if (order.creditRequest) {
                creditRequestBadge.style.display = 'inline-block';
                creditRequestBadge.textContent = 'Ombi la Mkopo';
            } else {
                creditRequestBadge.style.display = 'none';
            }
        }
        
        if (order.items && Array.isArray(order.items) && order.items.length > 0) {
            itemsList.innerHTML = order.items.map(item => `
                <tr>
                    <td>${item.productName || 'N/A'}</td>
                    <td>${item.quantity || 0}</td>
                    <td>${formatCurrency(item.price || 0)}</td>
                    <td>${formatCurrency(item.total || (item.price * item.quantity) || 0)}</td>
                </tr>
            `).join('');
        } else {
            itemsList.innerHTML = '<tr><td colspan="4" class="text-center text-muted">Hakuna bidhaa</td></tr>';
        }
        
        const modalElement = document.getElementById('viewPendingOrderModal');
        if (modalElement) {
            const modal = new bootstrap.Modal(modalElement);
            modal.show();
        } else {
            console.error('Modal element not found');
            showToast('Hitilafu katika kuonyesha agizo', 'danger');
        }
    } catch (error) {
        console.error('Error viewing pending order:', error);
        showToast('Hitilafu katika kuonyesha agizo: ' + error.message, 'danger');
    }
}

// =========================
// ONGOING ORDERS (All roles except store_viewer)
// =========================
let allOngoingOrders = [];

async function loadOngoingOrders() {
    const result = await api('/api/sales/ongoing');
    if (!result.success) {
        showToast(result.message || 'Hitilafu katika kupakia agizo', 'danger');
        return;
    }
    
    const orders = result.data || [];
    allOngoingOrders = [...orders];
    
    renderOngoingOrdersTable();
}

function filterOngoingOrdersTable() {
    const searchInput = document.getElementById('ongoingOrdersSearchInput');
    if (!searchInput || !allOngoingOrders) return;
    
    const searchTerm = searchInput.value.toLowerCase().trim();
    
    if (searchTerm === '') {
        renderOngoingOrdersTableWithData(allOngoingOrders);
    } else {
        const filtered = allOngoingOrders.filter(order => {
            const searchText = `${order.receiptNumber || ''} ${order.customerName || ''} ${order.receptionistName || ''} ${order.cashierName || ''} ${order.status || ''}`.toLowerCase();
            return searchText.includes(searchTerm);
        });
        renderOngoingOrdersTableWithData(filtered);
    }
}

function renderOngoingOrdersTable() {
    renderOngoingOrdersTableWithData(allOngoingOrders);
}

function renderOngoingOrdersTableWithData(orders) {
    const tbody = document.getElementById('ongoingOrdersTableBody');
    if (!tbody) return;
    
    if (!orders || orders.length === 0) {
        tbody.innerHTML = '<tr><td colspan="9" class="text-center text-muted">Hakuna agizo za endelea</td></tr>';
        return;
    }
    
    function getStatusBadge(status) {
        switch(status) {
            case 'pending_verification':
                return '<span class="badge bg-warning">Inasubiri Uthibitisho</span>';
            case 'verified':
                return '<span class="badge bg-info">Imethibitishwa</span>';
            case 'completed':
                return '<span class="badge bg-success">Imekamilika</span>';
            default:
                return `<span class="badge bg-secondary">${status || 'N/A'}</span>`;
        }
    }
    
    tbody.innerHTML = orders.map(order => `
        <tr>
            <td>${formatDateTime(order.verifiedAt || order.createdAt)}</td>
            <td><strong>${order.receiptNumber}</strong></td>
            <td>${order.customerName || 'Walk-in Customer'}</td>
            <td><span class="badge bg-info">${order.saleType === 'wholesale' ? 'Jumla' : 'Rejareja'}</span></td>
            <td>${getStatusBadge(order.status)}</td>
            <td><strong>${formatCurrency(order.totalAmount)}</strong></td>
            <td>${order.receptionistName || 'N/A'}</td>
            <td>${order.cashierName || '-'}</td>
            <td>
                <button class="btn btn-sm btn-primary btn-icon" onclick="viewOngoingOrder('${order.id}')" title="Angalia">
                    <i class="bi bi-eye"></i>
                </button>
            </td>
        </tr>
    `).join('');
}

function viewOngoingOrder(orderId) {
    const order = allOngoingOrders.find(o => o.id === orderId);
    if (!order) {
        console.error('Order not found:', orderId);
        showToast('Agizo halijapatikana', 'danger');
        return;
    }
    
    try {
        const modalHtml = `
            <div class="modal fade" id="ongoingOrderDetailModal" tabindex="-1">
                <div class="modal-dialog modal-lg">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title">Maelezo ya Agizo - ${order.receiptNumber || 'N/A'}</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="row mb-3">
                                <div class="col-md-6">
                                    <strong>Namba ya Risiti:</strong> ${order.receiptNumber || 'N/A'}<br>
                                    <strong>Tarehe:</strong> ${formatDateTime(order.verifiedAt || order.createdAt)}<br>
                                    <strong>Mteja:</strong> ${order.customerName || 'Walk-in Customer'}
                                </div>
                                <div class="col-md-6">
                                    <strong>Aina:</strong> ${order.saleType === 'wholesale' ? 'Jumla' : 'Rejareja'}<br>
                                    <strong>Hali:</strong> ${
                                        order.status === 'pending_verification' ? '<span class="badge bg-warning">Inasubiri Uthibitisho</span>' :
                                        order.status === 'verified' ? '<span class="badge bg-info">Imethibitishwa</span>' :
                                        order.status === 'completed' ? '<span class="badge bg-success">Imekamilika</span>' :
                                        '<span class="badge bg-secondary">' + (order.status || 'N/A') + '</span>'
                                    }<br>
                                    <strong>Njia ya Malipo:</strong> ${order.paymentMethod ? order.paymentMethod.toUpperCase() : 'Bado haijathibitishwa'}<br>
                                    ${order.receptionistName ? '<strong>Reception:</strong> ' + order.receptionistName + '<br>' : ''}
                                    ${order.cashierName ? '<strong>Cashier:</strong> ' + order.cashierName + '<br>' : ''}
                                </div>
                            </div>
                            ${order.creditRequest ? '<div class="alert alert-warning"><i class="bi bi-exclamation-triangle me-2"></i><strong>Ombi la Mkopo:</strong> Mteja ameomba mkopo</div>' : ''}
                            <h6 class="mt-3">Bidhaa</h6>
                            <table class="table table-sm">
                                <thead>
                                    <tr>
                                        <th>Bidhaa</th>
                                        <th>Idadi</th>
                                        <th>Bei</th>
                                        <th>Jumla</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    ${order.items && Array.isArray(order.items) && order.items.length > 0 ? 
                                        order.items.map(item => `
                                            <tr>
                                                <td>${item.productName || 'N/A'}</td>
                                                <td>${item.quantity || 0}</td>
                                                <td>${formatCurrency(item.price || 0)}</td>
                                                <td>${formatCurrency(item.total || (item.price * item.quantity) || 0)}</td>
                                            </tr>
                                        `).join('') :
                                        '<tr><td colspan="4" class="text-center text-muted">Hakuna bidhaa</td></tr>'
                                    }
                                </tbody>
                                <tfoot>
                                    <tr>
                                        <td colspan="3" class="text-end"><strong>Jumla:</strong></td>
                                        <td>${formatCurrency(order.subtotal || order.totalAmount || 0)}</td>
                                    </tr>
                                    ${order.discount > 0 ? `
                                        <tr>
                                            <td colspan="3" class="text-end">Punguzo:</td>
                                            <td>-${formatCurrency(order.discount)}</td>
                                        </tr>
                                    ` : ''}
                                    <tr>
                                        <td colspan="3" class="text-end"><strong>Jumla ya Mwisho:</strong></td>
                                        <td><strong>${formatCurrency(order.totalAmount || 0)}</strong></td>
                                    </tr>
                                </tfoot>
                            </table>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Funga</button>
                            ${order.status === 'verified' || order.status === 'completed' ? `
                                <button type="button" class="btn btn-primary" onclick="printReceipt('${order.id}')">
                                    <i class="bi bi-printer me-1"></i>Chapisha Risiti
                                </button>
                            ` : ''}
                        </div>
                    </div>
                </div>
            </div>
        `;
        
        // Remove existing modal if any
        const existingModal = document.getElementById('ongoingOrderDetailModal');
        if (existingModal) {
            const existingModalInstance = bootstrap.Modal.getInstance(existingModal);
            if (existingModalInstance) {
                existingModalInstance.dispose();
            }
            existingModal.remove();
        }
        
        // Add modal to DOM
        document.body.insertAdjacentHTML('beforeend', modalHtml);
        
        // Get modal element and ensure it's in DOM
        const modalElement = document.getElementById('ongoingOrderDetailModal');
        if (!modalElement) {
            showToast('Hitilafu katika kuunda modal', 'danger');
            return;
        }
        
        // Remove any aria-hidden attribute that might be set incorrectly
        modalElement.removeAttribute('aria-hidden');
        
        // Initialize and show modal
        const modal = new bootstrap.Modal(modalElement, {
            backdrop: true,
            keyboard: true,
            focus: true
        });
        
        // Show modal after a brief delay to ensure DOM is ready
        setTimeout(() => {
            modal.show();
        }, 10);
        
        // Clean up modal on hide
        modalElement.addEventListener('hidden.bs.modal', function() {
            const instance = bootstrap.Modal.getInstance(this);
            if (instance) {
                instance.dispose();
            }
            this.remove();
        }, { once: true });
    } catch (error) {
        console.error('Error viewing ongoing order:', error);
        showToast('Hitilafu katika kuonyesha agizo: ' + error.message, 'danger');
    }
}

// =========================
// STORE ORDERS (STORE VIEWER)
// =========================
let allStoreOrders = [];

async function loadStoreOrders() {
    const result = await api('/api/sales/verified');
    if (!result.success) return;
    
    const orders = result.data || [];
    allStoreOrders = [...orders];
    
    renderStoreOrdersTable();
}

function filterStoreOrdersTable() {
    const searchInput = document.getElementById('storeOrdersSearchInput');
    if (!searchInput || !allStoreOrders) return;
    
    const searchTerm = searchInput.value.toLowerCase().trim();
    
    if (searchTerm === '') {
        renderStoreOrdersTableWithData(allStoreOrders);
    } else {
        const filtered = allStoreOrders.filter(order => {
            const searchText = `${order.receiptNumber || ''} ${order.customerName || ''} ${order.cashierName || ''}`.toLowerCase();
            return searchText.includes(searchTerm);
        });
        renderStoreOrdersTableWithData(filtered);
    }
}

function renderStoreOrdersTable() {
    renderStoreOrdersTableWithData(allStoreOrders);
}

function renderStoreOrdersTableWithData(orders) {
    const tbody = document.getElementById('storeOrdersTableBody');
    if (!tbody) return;
    
    if (!orders || orders.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted">Hakuna agizo za stoo</td></tr>';
        return;
    }
    
    tbody.innerHTML = orders.map(order => `
        <tr>
            <td>${formatDateTime(order.verifiedAt || order.createdAt)}</td>
            <td><strong>${order.receiptNumber}</strong></td>
            <td>${order.customerName || 'Walk-in Customer'}</td>
            <td><span class="badge bg-info">${order.saleType === 'wholesale' ? 'Jumla' : 'Rejareja'}</span></td>
            <td><strong>${formatCurrency(order.totalAmount)}</strong></td>
            <td>${order.cashierName || 'N/A'}</td>
            <td>
                <button class="btn btn-sm btn-success btn-icon" onclick="completeStoreOrder('${order.id}')" title="Kamilisha">
                    <i class="bi bi-check-circle"></i> Kamilisha
                </button>
                <button class="btn btn-sm btn-primary btn-icon" onclick="viewStoreOrder('${order.id}')" title="Angalia">
                    <i class="bi bi-eye"></i>
                </button>
            </td>
        </tr>
    `).join('');
}

async function completeStoreOrder(orderId) {
    if (!confirm('Una uhakika mteja amepokea bidhaa zote na unaweza kukamilisha agizo hili?')) {
        return;
    }
    
    const result = await api(`/api/sales/${orderId}/complete`, {
        method: 'POST'
    });
    
    if (result.success) {
        showToast(result.message);
        await loadStoreOrders();
    } else {
        showToast(result.message, 'danger');
    }
}

function viewStoreOrder(orderId) {
    const order = allStoreOrders.find(o => o.id === orderId);
    if (!order) {
        console.error('Order not found:', orderId);
        showToast('Agizo halijapatikana', 'danger');
        return;
    }
    
    try {
        // Populate modal
        const receiptEl = document.getElementById('viewStoreOrderReceipt');
        const dateEl = document.getElementById('viewStoreOrderDate');
        const customerEl = document.getElementById('viewStoreOrderCustomer');
        const typeEl = document.getElementById('viewStoreOrderType');
        const paymentMethodEl = document.getElementById('viewStoreOrderPaymentMethod');
        const totalHeaderEl = document.getElementById('viewStoreOrderTotalHeader');
        const subtotalEl = document.getElementById('viewStoreOrderSubtotal');
        const discountEl = document.getElementById('viewStoreOrderDiscount');
        const totalEl = document.getElementById('viewStoreOrderTotal');
        const itemsList = document.getElementById('viewStoreOrderItems');
        
        if (!receiptEl || !dateEl || !customerEl || !typeEl || !paymentMethodEl || 
            !totalHeaderEl || !subtotalEl || !discountEl || !totalEl || !itemsList) {
            console.error('Modal elements not found');
            showToast('Hitilafu katika kuonyesha agizo', 'danger');
            return;
        }
        
        receiptEl.textContent = order.receiptNumber || 'N/A';
        dateEl.textContent = formatDateTime(order.verifiedAt || order.createdAt);
        customerEl.textContent = order.customerName || 'Walk-in Customer';
        typeEl.textContent = order.saleType === 'wholesale' ? 'Jumla' : 'Rejareja';
        paymentMethodEl.textContent = order.paymentMethod ? order.paymentMethod.toUpperCase() : 'CASH';
        totalHeaderEl.textContent = formatCurrency(order.totalAmount || 0);
        subtotalEl.textContent = formatCurrency(order.subtotal || order.totalAmount || 0);
        discountEl.textContent = formatCurrency(order.discount || 0);
        totalEl.textContent = formatCurrency(order.totalAmount || 0);
        
        if (order.items && Array.isArray(order.items) && order.items.length > 0) {
            itemsList.innerHTML = order.items.map(item => `
                <tr>
                    <td>${item.productName || 'N/A'}</td>
                    <td>${item.quantity || 0}</td>
                    <td>${formatCurrency(item.price || 0)}</td>
                    <td>${formatCurrency(item.total || (item.price * item.quantity) || 0)}</td>
                </tr>
            `).join('');
        } else {
            itemsList.innerHTML = '<tr><td colspan="4" class="text-center text-muted">Hakuna bidhaa</td></tr>';
        }
        
        const modalElement = document.getElementById('viewStoreOrderModal');
        if (modalElement) {
            const modal = new bootstrap.Modal(modalElement);
            modal.show();
        } else {
            console.error('Modal element not found');
            showToast('Hitilafu katika kuonyesha agizo', 'danger');
        }
    } catch (error) {
        console.error('Error viewing store order:', error);
        showToast('Hitilafu katika kuonyesha agizo: ' + error.message, 'danger');
    }
}

// =========================
// ROLE-SPECIFIC DOCUMENTATION
// =========================
async function loadRoleSpecificGuide() {
    const contentDiv = document.getElementById('roleGuideContent');
    if (!contentDiv || !currentUser) return;
    
    const role = currentUser.role;
    let guideHTML = '';
    
    switch(role) {
        case 'admin':
            guideHTML = `
                <div class="alert alert-info">
                    <i class="bi bi-info-circle me-2"></i>
                    <strong>Msimamizi Mkuu</strong> - Unaweza kupata mwongozo kamili kwenye <a href="/docs">Mwongozo</a>.
                </div>
                <h5>📋 Haki Zako:</h5>
                <ul>
                    <li>Kusimamia watumiaji wote na kuongeza watumiaji wapya</li>
                    <li>Kusimamia bidhaa, kategoria, na stoo</li>
                    <li>Kufanya mauzo kamili na kuthibitisha agizo</li>
                    <li>Kutengeneza manunuzi na kusimamia wasambazaji</li>
                    <li>Kuona ripoti zote na kusimamia mipangilio</li>
                </ul>
            `;
            break;
            
        case 'cashier':
            guideHTML = `
                <h4 class="text-primary mb-4"><i class="bi bi-cash-stack me-2"></i>Mwongozo kwa Cashier</h4>
                
                <h5>🛒 1. Kufanya Mauzo (Point of Sale):</h5>
                <ol>
                    <li>Nenda <strong>Point of Sale</strong></li>
                    <li>Bonyeza bidhaa kuiongeza kwenye kikapu</li>
                    <li>Tumia <strong>+</strong> / <strong>-</strong> au andika idadi moja kwa moja</li>
                    <li>Chagua aina ya mauzo (Rejareja au Jumla)</li>
                    <li>Chagua mteja au acha "Walk-in Customer"</li>
                    <li>Chagua njia ya malipo (Cash, M-Pesa, Bank, Card)</li>
                    <li>Kama ni mkopo, weka ✓ kwenye "Mauzo ya Mkopo"</li>
                    <li>Bonyeza <strong>Maliza Mauzo</strong></li>
                </ol>
                
                <h5 class="mt-4">✅ 2. Kuthibitisha Agizo za Reception:</h5>
                <ol>
                    <li>Nenda <strong>Agizo za Kuthibitisha</strong></li>
                    <li>Unaona orodha ya agizo zote zilizowasilishwa na Reception</li>
                    <li>Tumia search kutafuta agizo maalum</li>
                    <li><strong>Angalia badges:</strong> Agizo zilizo na <span class="badge bg-warning">Ombi la Mkopo</span> zinaonyesha kuwa mteja anataka mkopo</li>
                    <li>Bonyeza <strong>Angalia</strong> <i class="bi bi-eye"></i> kuona maelezo kamili ya agizo</li>
                    <li>Bonyeza <strong>Thibitisha</strong> <i class="bi bi-check-circle"></i></li>
                    <li><strong>Kwa Agizo za Ombi la Mkopo:</strong>
                        <ul>
                            <li>Utauona alert box yenye ujumbe: "Ombi la Mkopo: Reception amewasilisha agizo hili kama ombi la mkopo. Mteja anataka mkopo."</li>
                            <li>Checkbox ya "Mauzo ya Mkopo" itakuwa tayari imewekwa ✓</li>
                            <li>Unaweza kukubali (acha ✓) au kukataa (ondoa ✓) kulingana na sera yako</li>
                            <li>Kama unakubali, agizo litakuwa mkopo na mteja atadaiwa</li>
                            <li>Kama unakataa, weka njia ya malipo ya cash na agizo litakamilika na malipo</li>
                        </ul>
                    </li>
                    <li>Chagua njia ya malipo (Cash, M-Pesa, Bank, Card)</li>
                    <li>Kama ni mkopo, weka ✓ kwenye "Mauzo ya Mkopo"</li>
                    <li>Bonyeza <strong>Thibitisha na Kamilisha</strong></li>
                    <li>Stock itapunguzwa na agizo litaonekana kwa Store Viewer</li>
                </ol>
                
                <h5 class="mt-4">📊 3. Kuona Historia ya Mauzo:</h5>
                <ol>
                    <li>Nenda <strong>Mauzo</strong></li>
                    <li>Tumia filter ya tarehe au search</li>
                    <li>Bonyeza <i class="bi bi-eye"></i> kuona maelezo</li>
                    <li>Bonyeza <i class="bi bi-printer"></i> kuchapisha risiti</li>
                </ol>
                
                <h5 class="mt-4">💳 4. Kusimamia Madeni:</h5>
                <ol>
                    <li>Nenda <strong>Madeni</strong></li>
                    <li>Unaona orodha ya wateja wanaodaiwa</li>
                    <li>Bonyeza <i class="bi bi-cash"></i> kupokea malipo</li>
                    <li>Weka kiasi na chagua njia ya malipo</li>
                </ol>
            `;
            break;
            
        case 'reception':
            guideHTML = `
                <h4 class="text-primary mb-4"><i class="bi bi-person-badge me-2"></i>Mwongozo kwa Reception</h4>
                
                <div class="alert alert-info">
                    <i class="bi bi-info-circle me-2"></i>
                    <strong>Kazi Yako:</strong> Kujaza agizo tu na kuwasilisha kwa Cashier kwa uthibitisho.
                </div>
                
                <h5>🛒 Kufanya Agizo:</h5>
                <ol>
                    <li>Nenda <strong>Point of Sale</strong></li>
                    <li>Bonyeza bidhaa kuiongeza kwenye kikapu</li>
                    <li>Tumia <strong>+</strong> / <strong>-</strong> au andika idadi moja kwa moja</li>
                    <li>Chagua aina ya mauzo (Rejareja au Jumla)</li>
                    <li>Chagua mteja au acha "Walk-in Customer"</li>
                    <li>Weka discount kama ipo</li>
                    <li><strong>Ombi la Mkopo:</strong> Kama mteja anataka mkopo:
                        <ul>
                            <li>Weka ✓ kwenye <strong>"Ombi la Mkopo (mteja anataka mkopo)"</strong></li>
                            <li><strong>Lazima uchague mteja</strong> - hauwezi kuweka ombi la mkopo bila mteja</li>
                            <li>Agizo litakuwa na badge ya <span class="badge bg-warning">Ombi la Mkopo</span></li>
                            <li>Cashier ataona agizo kama ombi la mkopo na atathibitisha au kukataa</li>
                        </ul>
                    </li>
                    <li>Bonyeza <strong>Wasilisha Agizo</strong> (sio "Maliza Mauzo")</li>
                </ol>
                
                <div class="alert alert-warning mt-3">
                    <i class="bi bi-exclamation-triangle me-2"></i>
                    <strong>Muhimu:</strong>
                    <ul class="mb-0 mt-2">
                        <li>Stock <strong>HAITAPUNGUKA</strong> mpaka Cashier athibitishe agizo</li>
                        <li>Agizo litakuwa na status "pending_verification"</li>
                        <li>Kama umeweka "Ombi la Mkopo", Cashier ataona alert na atathibitisha au kukataa</li>
                        <li>Cashier atathibitisha, aweke njia ya malipo, na kukamilisha malipo</li>
                        <li>Baada ya kuthibitishwa, agizo litaonekana kwa Store Viewer</li>
                    </ul>
                </div>
            `;
            break;
            
        case 'store_viewer':
            guideHTML = `
                <h4 class="text-primary mb-4"><i class="bi bi-box-arrow-right me-2"></i>Mwongozo kwa Store Viewer</h4>
                
                <div class="alert alert-info">
                    <i class="bi bi-info-circle me-2"></i>
                    <strong>Kazi Yako:</strong> Kuona agizo zilizothibitishwa na Cashier, kupanga bidhaa, na kumtoa mteja.
                </div>
                
                <h5>📦 Kukamilisha Agizo:</h5>
                <ol>
                    <li>Nenda <strong>Agizo za Stoo</strong></li>
                    <li>Unaona orodha ya agizo zote zilizothibitishwa na Cashier</li>
                    <li>Tumia search kutafuta agizo maalum</li>
                    <li>Bonyeza <strong>Angalia</strong> <i class="bi bi-eye"></i> kuona maelezo kamili ya agizo</li>
                    <li>Panga bidhaa kulingana na agizo</li>
                    <li>Mpa mteja bidhaa zake</li>
                    <li>Bonyeza <strong>Kamilisha</strong> <i class="bi bi-check-circle"></i></li>
                    <li>Thibitisha kuwa mteja amepokea bidhaa zote</li>
                    <li>Agizo litakuwa "completed" na mteja anaweza kuondoka</li>
                </ol>
                
                <div class="alert alert-warning mt-3">
                    <i class="bi bi-exclamation-triangle me-2"></i>
                    <strong>Kumbuka:</strong>
                    <ul class="mb-0 mt-2">
                        <li>Unaweza kuona tu agizo zilizothibitishwa na Cashier</li>
                        <li>Hauwezi kuona agizo zisizothibitishwa</li>
                        <li>Hauwezi kufanya mauzo au kubadilisha bidhaa</li>
                    </ul>
                </div>
            `;
            break;
            
        case 'storekeeper':
            guideHTML = `
                <h4 class="text-primary mb-4"><i class="bi bi-boxes me-2"></i>Mwongozo kwa Storekeeper</h4>
                
                <h5>📦 1. Kusimamia Bidhaa:</h5>
                <ol>
                    <li>Nenda <strong>Bidhaa</strong></li>
                    <li>Bonyeza <strong>Ongeza Bidhaa</strong> kuongeza bidhaa mpya</li>
                    <li>Jaza maelezo yote (jina, kategoria, bei, nk)</li>
                    <li>Tumia search kutafuta bidhaa</li>
                </ol>
                
                <h5 class="mt-4">📥 2. Stock In (Kupokea Mzigo):</h5>
                <ol>
                    <li>Nenda <strong>Stoo</strong></li>
                    <li>Bonyeza <strong>Stock In</strong></li>
                    <li>Chagua bidhaa (tumia search)</li>
                    <li>Weka idadi, bei ya ununuzi, batch number</li>
                    <li>Weka tarehe ya expiry (kama ina expiry)</li>
                </ol>
                
                <h5 class="mt-4">🛒 3. Manunuzi:</h5>
                <ol>
                    <li>Nenda <strong>Manunuzi</strong></li>
                    <li>Bonyeza <strong>Purchase Order</strong></li>
                    <li>Chagua msambazaji</li>
                    <li>Ongeza bidhaa na kiasi</li>
                    <li>Chagua aina ya malipo (Cash au Mkopo)</li>
                    <li>Weka njia ya malipo</li>
                    <li>Hifadhi</li>
                </ol>
                
                <h5 class="mt-4">👥 4. Wasambazaji:</h5>
                <ol>
                    <li>Nenda <strong>Wasambazaji</strong></li>
                    <li>Ongeza msambazaji mpya</li>
                    <li>Simamia madeni ya wasambazaji</li>
                    <li>Rekodi malipo ya madeni</li>
                </ol>
            `;
            break;
            
        default:
            guideHTML = `
                <div class="alert alert-warning">
                    <i class="bi bi-exclamation-triangle me-2"></i>
                    Hakuna mwongozo maalum kwa role yako. Tafadhali wasiliana na msimamizi.
                </div>
            `;
    }
    
    contentDiv.innerHTML = guideHTML;
}

// Allow Enter key in password input
document.addEventListener('DOMContentLoaded', function() {
    const passwordInput = document.getElementById('passwordConfirmInput');
    if (passwordInput) {
        passwordInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                confirmDeleteAction();
            }
        });
    }
});

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', initApp);

