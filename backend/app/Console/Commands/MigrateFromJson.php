<?php

namespace App\Console\Commands;

use App\Models\Branch;
use App\Models\Category;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\Shop;
use App\Models\StockMovement;
use App\Models\Supplier;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class MigrateFromJson extends Command
{
    protected $signature = 'migrate:from-json
        {path : Path to JSON data folder (e.g. ../frontend/data)}
        {--fresh : Wipe SaaS tables before import}
        {--demo-tenant2 : Also create an empty second shop for isolation tests}';

    protected $description = 'Copy-import Express JSON data into MySQL as Shop 1 (does not modify source files)';

    public function handle(): int
    {
        $path = rtrim($this->argument('path'), DIRECTORY_SEPARATOR);
        if (! is_dir($path)) {
            $this->error("Directory not found: {$path}");

            return self::FAILURE;
        }

        $read = function (string $file) use ($path) {
            $full = $path.DIRECTORY_SEPARATOR.$file;
            if (! is_file($full)) {
                return [];
            }
            $json = json_decode(file_get_contents($full), true);

            return is_array($json) ? $json : [];
        };

        if ($this->option('fresh')) {
            $this->warn('Truncating SaaS tables…');
            DB::statement('SET FOREIGN_KEY_CHECKS=0');
            foreach ([
                'debt_payments', 'customer_debts', 'purchase_items', 'purchases', 'suppliers',
                'sale_items', 'sales', 'stock_movements', 'products', 'categories',
                'customers', 'personal_access_tokens', 'users', 'branches', 'shops',
            ] as $table) {
                DB::table($table)->truncate();
            }
            DB::statement('SET FOREIGN_KEY_CHECKS=1');
        }

        $settings = $read('settings.json');
        if ($settings === [] || ! isset($settings['companyName'])) {
            // settings.json is a single object, not array
            if (! is_file($path.'/settings.json')) {
                $this->error('settings.json missing');

                return self::FAILURE;
            }
            $settings = json_decode(file_get_contents($path.'/settings.json'), true) ?: [];
        }

        $report = [];

        DB::transaction(function () use ($read, $settings, &$report) {
            $shop = Shop::create([
                'name' => $settings['companyName'] ?? 'Imported Shop',
                'address' => $settings['companyAddress'] ?? null,
                'phone' => $settings['companyPhone'] ?? null,
                'email' => $settings['companyEmail'] ?? null,
                'tax_rate' => $settings['taxRate'] ?? 0,
                'currency' => $settings['currency'] ?? 'TZS',
                'receipt_footer' => $settings['receiptFooter'] ?? null,
                'status' => 'active',
                'legacy_id' => 'settings',
            ]);
            $report['shop'] = $shop->name;

            $branchMap = [];
            $branches = $read('branches.json');
            if ($branches === []) {
                $main = Branch::create([
                    'shop_id' => $shop->id,
                    'name' => 'Main',
                    'status' => 'active',
                    'legacy_id' => 'main',
                ]);
                $branchMap['main'] = $main->id;
            } else {
                foreach ($branches as $b) {
                    $branch = Branch::create([
                        'shop_id' => $shop->id,
                        'name' => $b['name'] ?? 'Branch',
                        'address' => $b['address'] ?? null,
                        'phone' => $b['phone'] ?? null,
                        'email' => $b['email'] ?? null,
                        'status' => $b['status'] ?? 'active',
                        'legacy_id' => $b['id'] ?? null,
                    ]);
                    if (! empty($b['id'])) {
                        $branchMap[$b['id']] = $branch->id;
                    }
                }
            }
            $report['branches'] = count($branchMap);

            $roleMap = [
                'admin' => 'owner',
                'cashier' => 'cashier',
                'storekeeper' => 'storekeeper',
                'reception' => 'cashier',
                'store_viewer' => 'cashier',
            ];

            $userMap = [];
            $users = $read('users.json');
            foreach ($users as $u) {
                $username = $u['username'] ?? ('user'.$u['id']);
                $email = ! empty($u['email'])
                    ? $u['email']
                    : strtolower($username).'@local.test';

                // Avoid unique collisions
                $baseEmail = $email;
                $i = 1;
                while (User::where('email', $email)->exists()) {
                    $email = $i.'+'.$baseEmail;
                    $i++;
                }

                // Temporary password; then write Express bcryptjs hash via DB to avoid
                // Laravel's "hashed" cast re-hashing $2a$ strings (Hash::isHashed misses them).
                $baseUsername = preg_replace('/\s+/', '', (string) $username) ?: ('user'.$u['id']);
                $loginUsername = $baseUsername;
                $ui = 1;
                while (User::where('username', $loginUsername)->exists()) {
                    $loginUsername = $baseUsername.$ui;
                    $ui++;
                }

                $user = User::create([
                    'shop_id' => $shop->id,
                    'branch_id' => isset($u['branchId'], $branchMap[$u['branchId']])
                        ? $branchMap[$u['branchId']]
                        : ($branchMap['main'] ?? null),
                    'name' => $u['fullName'] ?? $username,
                    'username' => $loginUsername,
                    'email' => $email,
                    'phone' => $u['phone'] ?? null,
                    'role' => $roleMap[$u['role'] ?? 'cashier'] ?? 'cashier',
                    'status' => ($u['status'] ?? 'active') === 'active' ? 'active' : 'inactive',
                    'legacy_id' => $u['id'] ?? null,
                    'password' => 'ChangeMe123!',
                ]);

                $hash = $u['password'] ?? null;
                if (is_string($hash) && str_starts_with($hash, '$2')) {
                    // Normalize bcryptjs $2a$ → $2y$ (use $$ so preg_replace won't treat $2 as a backref)
                    $normalized = str_starts_with($hash, '$2a$')
                        ? '$2y$'.substr($hash, 4)
                        : $hash;
                    DB::update('UPDATE users SET password = ? WHERE id = ?', [$normalized, $user->id]);
                }

                if (! empty($u['id'])) {
                    $userMap[$u['id']] = $user->id;
                }
            }
            $report['users'] = count($userMap);

            $categoryMap = [];
            foreach ($read('categories.json') as $c) {
                $cat = Category::create([
                    'shop_id' => $shop->id,
                    'name' => $c['name'] ?? 'Category',
                    'legacy_id' => $c['id'] ?? null,
                ]);
                if (! empty($c['id'])) {
                    $categoryMap[$c['id']] = $cat->id;
                }
            }
            $report['categories'] = count($categoryMap);

            $stock = $read('stock.json');
            $stockByProduct = [];
            foreach ($stock as $s) {
                $pid = $s['productId'] ?? null;
                if (! $pid) {
                    continue;
                }
                $stockByProduct[$pid] = ($stockByProduct[$pid] ?? 0) + (int) ($s['quantity'] ?? 0);
            }

            $productMap = [];
            foreach ($read('products.json') as $p) {
                $legacyId = $p['id'] ?? null;
                $product = Product::create([
                    'shop_id' => $shop->id,
                    'category_id' => isset($p['categoryId'], $categoryMap[$p['categoryId']])
                        ? $categoryMap[$p['categoryId']]
                        : null,
                    'name' => $p['name'] ?? 'Product',
                    'description' => $p['description'] ?? null,
                    'price' => $p['retailPrice'] ?? $p['price'] ?? 0,
                    'cost_price' => $p['wholesalePrice'] ?? $p['costPrice'] ?? 0,
                    'barcode' => $p['barcode'] ?? null,
                    'sku' => $p['sku'] ?? null,
                    'unit' => $p['unit'] ?? 'pcs',
                    'stock' => max(0, $stockByProduct[$legacyId] ?? 0),
                    'low_stock_threshold' => $p['minStock'] ?? 10,
                    'status' => $p['status'] ?? 'active',
                    'legacy_id' => $legacyId,
                ]);
                if ($legacyId) {
                    $productMap[$legacyId] = $product->id;
                }
            }
            $report['products'] = count($productMap);

            $movements = 0;
            foreach ($stock as $s) {
                $legacyPid = $s['productId'] ?? null;
                if (! $legacyPid || ! isset($productMap[$legacyPid])) {
                    continue;
                }
                StockMovement::create([
                    'shop_id' => $shop->id,
                    'product_id' => $productMap[$legacyPid],
                    'branch_id' => isset($s['branchId'], $branchMap[$s['branchId']])
                        ? $branchMap[$s['branchId']]
                        : null,
                    'quantity' => (int) ($s['quantity'] ?? 0),
                    'type' => $s['type'] ?? 'in',
                    'batch_number' => $s['batchNumber'] ?? null,
                    'expiry_date' => $s['expiryDate'] ?? null,
                    'cost_price' => $s['costPrice'] ?? 0,
                    'supplier_legacy_id' => $s['supplierId'] ?? null,
                    'notes' => $s['notes'] ?? null,
                    'created_by' => isset($s['createdBy'], $userMap[$s['createdBy']])
                        ? $userMap[$s['createdBy']]
                        : null,
                    'legacy_id' => $s['id'] ?? null,
                    'created_at' => $s['createdAt'] ?? now(),
                    'updated_at' => $s['updatedAt'] ?? now(),
                ]);
                $movements++;
            }
            $report['stock_movements'] = $movements;

            $customerMap = [];
            foreach ($read('customers.json') as $c) {
                $customer = Customer::create([
                    'shop_id' => $shop->id,
                    'name' => $c['name'] ?? 'Customer',
                    'email' => $c['email'] ?? null,
                    'phone' => $c['phone'] ?? null,
                    'address' => $c['address'] ?? null,
                    'notes' => $c['businessName'] ?? null,
                    'is_active' => ($c['status'] ?? 'active') === 'active',
                    'legacy_id' => $c['id'] ?? null,
                ]);
                if (! empty($c['id'])) {
                    $customerMap[$c['id']] = $customer->id;
                }
            }
            $report['customers'] = count($customerMap);

            $supplierMap = [];
            foreach ($read('suppliers.json') as $s) {
                $supplier = Supplier::create([
                    'shop_id' => $shop->id,
                    'name' => $s['name'] ?? 'Supplier',
                    'phone' => $s['phone'] ?? null,
                    'email' => $s['email'] ?? null,
                    'address' => $s['address'] ?? null,
                    'notes' => $s['contactPerson'] ?? ($s['notes'] ?? null),
                    'legacy_id' => $s['id'] ?? null,
                ]);
                if (! empty($s['id'])) {
                    $supplierMap[$s['id']] = $supplier->id;
                }
            }
            $report['suppliers'] = count($supplierMap);

            $salesCount = 0;
            $itemsCount = 0;
            foreach ($read('sales.json') as $sale) {
                $created = Sale::create([
                    'shop_id' => $shop->id,
                    'cashier_id' => isset($sale['createdBy'], $userMap[$sale['createdBy']])
                        ? $userMap[$sale['createdBy']]
                        : null,
                    'customer_id' => isset($sale['customerId'], $customerMap[$sale['customerId']])
                        ? $customerMap[$sale['customerId']]
                        : null,
                    'serial_number' => $sale['receiptNumber'] ?? ('LEG-'.$salesCount),
                    'payment_method' => $sale['paymentMethod'] ?? 'cash',
                    'subtotal' => $sale['subtotal'] ?? $sale['totalAmount'] ?? 0,
                    'tax' => 0,
                    'discount' => $sale['discount'] ?? 0,
                    'total' => $sale['totalAmount'] ?? 0,
                    'customer_name' => $sale['customerName'] ?? null,
                    'status' => $sale['status'] ?? 'completed',
                    'legacy_id' => $sale['id'] ?? null,
                    'created_at' => $sale['createdAt'] ?? now(),
                    'updated_at' => $sale['updatedAt'] ?? now(),
                ]);
                $salesCount++;

                foreach ($sale['items'] ?? [] as $item) {
                    $pid = $item['productId'] ?? null;
                    SaleItem::create([
                        'sale_id' => $created->id,
                        'product_id' => ($pid && isset($productMap[$pid])) ? $productMap[$pid] : null,
                        'product_name' => $item['productName'] ?? 'Item',
                        'quantity' => (int) ($item['quantity'] ?? 0),
                        'unit_price' => (float) ($item['price'] ?? 0),
                        'line_total' => (float) ($item['total'] ?? 0),
                    ]);
                    $itemsCount++;
                }
            }
            $report['sales'] = $salesCount;
            $report['sale_items'] = $itemsCount;
        });

        if ($this->option('demo-tenant2')) {
            $shop2 = Shop::create([
                'name' => 'Demo Shop Two',
                'address' => 'Local Test',
                'phone' => '0700000000',
                'email' => 'shop2@local.test',
                'currency' => 'TZS',
                'status' => 'active',
            ]);
            $branch2 = Branch::create([
                'shop_id' => $shop2->id,
                'name' => 'Main',
                'status' => 'active',
            ]);
            User::create([
                'shop_id' => $shop2->id,
                'branch_id' => $branch2->id,
                'name' => 'Shop Two Owner',
                'username' => 'owner2',
                'email' => 'owner2@local.test',
                'password' => Hash::make('password'),
                'role' => 'owner',
                'status' => 'active',
            ]);
            Product::create([
                'shop_id' => $shop2->id,
                'name' => 'Tenant2 Only Product',
                'price' => 1000,
                'cost_price' => 500,
                'stock' => 50,
                'status' => 'active',
            ]);
            $report['demo_tenant2'] = 'owner2 / password';
        }

        $this->info('Import complete (source JSON untouched).');
        foreach ($report as $k => $v) {
            $this->line("  {$k}: {$v}");
        }

        $this->newLine();
        $this->info('Verification:');
        $this->line('  shops='.Shop::count());
        $this->line('  users='.User::count());
        $this->line('  products='.Product::count());
        $this->line('  stock_sum='.Product::sum('stock'));
        $this->line('  customers='.Customer::count());
        $this->line('  sales='.Sale::count());

        $admin = User::where('role', 'owner')->orderBy('id')->first();
        if ($admin) {
            $this->line('  sample_login_username='.($admin->username ?? $admin->email).' (original password if hash preserved)');
        }

        return self::SUCCESS;
    }
}
