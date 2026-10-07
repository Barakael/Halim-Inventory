# Data Reset Script - Usage Guide

## Overview
This script helps you reset all test data to start fresh for production use. It can create backups and selectively reset different types of data.

## Usage

### Basic Usage (Reset Transactional Data Only)
This will reset all sales, purchases, products, stock, etc., but **keeps** users, categories, branches, and settings:
```bash
node reset-data.js
```

### Reset Users Only
This will reset users to default (creates admin user with password `admin123`), but keeps categories, branches, and settings:
```bash
node reset-data.js --reset-users
```

### Full Reset (Everything)
This will reset EVERYTHING including users, categories, branches, and settings:
```bash
node reset-data.js --reset-all
```

### Skip Backup
If you don't want to create a backup (not recommended):
```bash
node reset-data.js --no-backup
```

### Combined Options
```bash
# Full reset without backup (USE WITH CAUTION!)
node reset-data.js --reset-all --no-backup

# Reset users with backup (default)
node reset-data.js --reset-users
```

## What Gets Reset

### Always Reset (Transactional Data):
- ✅ Products
- ✅ Stock
- ✅ Sales
- ✅ Purchases
- ✅ Suppliers
- ✅ Customers
- ✅ Expenses
- ✅ Payments
- ✅ Activity Logs
- ✅ Notifications
- ✅ Stock Transfers
- ✅ Credit Sales
- ✅ Supplier Payments

### Conditionally Reset (Structure Data):
- 👥 **Users** (only with `--reset-users` or `--reset-all`)
- 📁 **Categories** (only with `--reset-all`)
- 🏢 **Branches** (only with `--reset-all`)
- ⚙️ **Settings** (only with `--reset-all`)

## Default Admin User
After reset with `--reset-users` or `--reset-all`, you can login with:
- **Username:** `admin`
- **Password:** `admin123`

⚠️ **IMPORTANT:** Change the admin password immediately after first login!

## Backup Location
Backups are saved to: `backups/backup-YYYY-MM-DDTHH-MM-SS/`

Each backup contains all data files at the time of reset.

## Recommended Workflow

1. **Create a backup first (automatic by default):**
   ```bash
   node reset-data.js
   ```

2. **Verify the backup was created:**
   ```bash
   ls -la backups/
   ```

3. **Start the server:**
   ```bash
   npm start
   ```

4. **Login and change admin password:**
   - Username: `admin`
   - Password: `admin123`
   - Go to Settings → Change Password

5. **Verify your data:**
   - Check users (if you kept them)
   - Check categories (if you kept them)
   - Check branches (if you kept them)
   - Check settings (if you kept them)

6. **Add real data:**
   - Add real products
   - Add real suppliers
   - Add real customers
   - Add real users (if you reset users)

## Safety Notes

- ⚠️ This operation **CANNOT BE UNDONE** (unless you restore from backup)
- 💾 Backups are created automatically (unless `--no-backup` is used)
- 🔒 The script only resets JSON files in the `data/` directory
- 📝 Sessions and uploaded files are NOT affected by this script
- ✅ Always test in a development environment first

## Troubleshooting

### Error: "Data directory does not exist"
Make sure you're running the script from the project root directory.

### Error: "Permission denied"
Make sure you have write permissions to the `data/` and `backups/` directories.

### Want to restore from backup?
Simply copy the files from the backup directory back to the `data/` directory:
```bash
cp backups/backup-YYYY-MM-DDTHH-MM-SS/*.json data/
```
