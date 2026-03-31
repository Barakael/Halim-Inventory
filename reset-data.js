/**
 * HASLIM GROUP - Data Reset Script
 * This script resets all test data to start fresh for production use
 * 
 * Usage: node reset-data.js [options]
 * Options:
 *   --backup        Create backup before reset (default: true)
 *   --reset-users   Reset users to default (keeps admin user)
 *   --reset-all     Reset everything including users, categories, branches
 *   --no-backup     Skip backup creation
 */

const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');

// Database file paths
const DB_PATH = path.join(__dirname, 'data');
const BACKUP_PATH = path.join(__dirname, 'backups');

// All database files
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

// Parse command line arguments
const args = process.argv.slice(2);
const createBackup = !args.includes('--no-backup');
const resetUsers = args.includes('--reset-users') || args.includes('--reset-all');
const resetAll = args.includes('--reset-all');

// Helper function to read JSON file
function readJSON(filePath) {
    try {
        if (!fs.existsSync(filePath)) {
            return null;
        }
        const data = fs.readFileSync(filePath, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        console.error(`Error reading ${filePath}:`, error.message);
        return null;
    }
}

// Helper function to write JSON file
function writeJSON(filePath, data) {
    try {
        fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
        return true;
    } catch (error) {
        console.error(`Error writing ${filePath}:`, error.message);
        return false;
    }
}

// Create backup
function createDataBackup() {
    if (!createBackup) {
        console.log('⚠️  Backup skipped (--no-backup flag used)');
        return null;
    }

    // Create backup directory if it doesn't exist
    if (!fs.existsSync(BACKUP_PATH)) {
        fs.mkdirSync(BACKUP_PATH, { recursive: true });
    }

    // Create timestamped backup folder
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
    const backupDir = path.join(BACKUP_PATH, `backup-${timestamp}`);
    fs.mkdirSync(backupDir, { recursive: true });

    console.log(`📦 Creating backup in: ${backupDir}`);

    // Copy all data files to backup
    let backedUp = 0;
    Object.keys(dbFiles).forEach(key => {
        const filePath = dbFiles[key];
        if (fs.existsSync(filePath)) {
            const backupFilePath = path.join(backupDir, path.basename(filePath));
            fs.copyFileSync(filePath, backupFilePath);
            backedUp++;
        }
    });

    console.log(`✓ Backed up ${backedUp} files`);
    return backupDir;
}

// Default data templates
function getDefaultUsers() {
    return [{
        id: uuidv4(),
        username: 'admin',
        password: bcrypt.hashSync('admin123', 10),
        fullName: 'System Administrator',
        email: 'admin@haslimgroup.co.tz',
        phone: '+255712345678',
        role: 'admin',
        branchId: 'main',
        status: 'active',
        createdAt: new Date().toISOString(),
        lastLogin: null
    }];
}

function getDefaultCategories() {
    return [
        { id: uuidv4(), name: 'Vinywaji (Beverages)', description: 'Soda, juisi, maji', status: 'active' },
        { id: uuidv4(), name: 'Nafaka (Grains)', description: 'Mchele, unga, mahindi', status: 'active' },
        { id: uuidv4(), name: 'Mafuta (Oils)', description: 'Mafuta ya kupikia', status: 'active' },
        { id: uuidv4(), name: 'Sukari (Sugar)', description: 'Sukari na asali', status: 'active' },
        { id: uuidv4(), name: 'Chumvi na Viungo', description: 'Chumvi, pilipili, viungo', status: 'active' },
        { id: uuidv4(), name: 'Maziwa (Dairy)', description: 'Maziwa na bidhaa zake', status: 'active' },
        { id: uuidv4(), name: 'Vyakula vya Makopo', description: 'Samaki, nyama, mboga za makopo', status: 'active' },
        { id: uuidv4(), name: 'Biskuti na Snacks', description: 'Biskuti, chips, karanga', status: 'active' }
    ];
}

function getDefaultBranches() {
    return [{
        id: 'main',
        name: 'Tawi Kuu (Main Branch)',
        address: 'Dar es Salaam, Tanzania',
        phone: '+255712345678',
        email: 'main@haslimgroup.co.tz',
        status: 'active',
        createdAt: new Date().toISOString()
    }];
}

function getDefaultSettings() {
    return {
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
}

// Reset all test data
function resetAllData() {
    console.log('\n🔄 Starting data reset...\n');

    // Reset transactional data (always reset these)
    const transactionalData = {
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

    console.log('📊 Resetting transactional data...');
    Object.keys(transactionalData).forEach(key => {
        if (dbFiles[key]) {
            writeJSON(dbFiles[key], transactionalData[key]);
            console.log(`  ✓ Reset ${key}`);
        }
    });

    // Conditionally reset structure data
    if (resetAll) {
        console.log('\n🏗️  Resetting structure data (--reset-all mode)...');
        
        writeJSON(dbFiles.users, getDefaultUsers());
        console.log('  ✓ Reset users (admin user created)');
        
        writeJSON(dbFiles.categories, getDefaultCategories());
        console.log('  ✓ Reset categories');
        
        writeJSON(dbFiles.branches, getDefaultBranches());
        console.log('  ✓ Reset branches');
        
        writeJSON(dbFiles.settings, getDefaultSettings());
        console.log('  ✓ Reset settings');
    } else if (resetUsers) {
        console.log('\n👥 Resetting users only (--reset-users mode)...');
        writeJSON(dbFiles.users, getDefaultUsers());
        console.log('  ✓ Reset users (admin user created)');
    } else {
        console.log('\nℹ️  Keeping structure data (users, categories, branches, settings)');
        console.log('   Use --reset-users to reset users, or --reset-all to reset everything');
    }

    console.log('\n✅ Data reset completed successfully!');
    console.log('\n📝 Next steps:');
    console.log('   1. Start the server: npm start');
    console.log('   2. Login with: admin / admin123');
    console.log('   3. Change the admin password immediately');
    if (!resetAll) {
        console.log('   4. Verify your users, categories, and branches');
    }
    console.log('   5. Add real products, suppliers, and customers');
    console.log('');
}

// Main execution
function main() {
    console.log('═══════════════════════════════════════════════════════');
    console.log('   HASLIM GROUP - Data Reset Script');
    console.log('═══════════════════════════════════════════════════════\n');

    // Check if data directory exists
    if (!fs.existsSync(DB_PATH)) {
        console.error('❌ Error: Data directory does not exist!');
        process.exit(1);
    }

    // Ask for confirmation (in production, you might want to add readline confirmation)
    console.log('⚠️  WARNING: This will reset all test data!');
    console.log(`   Mode: ${resetAll ? 'Full Reset (--reset-all)' : resetUsers ? 'Reset Users (--reset-users)' : 'Transactional Data Only'}`);
    console.log(`   Backup: ${createBackup ? 'Yes' : 'No'}\n`);

    // Create backup first
    const backupDir = createDataBackup();

    // Reset data
    resetAllData();

    if (backupDir) {
        console.log(`💾 Backup saved to: ${backupDir}`);
    }

    console.log('═══════════════════════════════════════════════════════\n');
}

// Run the script
main();
