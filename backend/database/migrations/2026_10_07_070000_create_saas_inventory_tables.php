<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('categories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shop_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->unsignedBigInteger('parent_id')->nullable();
            $table->string('legacy_id')->nullable()->index();
            $table->timestamps();
        });

        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shop_id')->constrained()->cascadeOnDelete();
            $table->foreignId('category_id')->nullable()->constrained()->nullOnDelete();
            $table->string('name');
            $table->text('description')->nullable();
            $table->decimal('price', 15, 2)->default(0);
            $table->decimal('cost_price', 15, 2)->default(0);
            $table->string('barcode')->nullable()->index();
            $table->string('sku')->nullable();
            $table->string('unit')->default('pcs');
            $table->integer('stock')->default(0);
            $table->integer('low_stock_threshold')->default(10);
            $table->string('image_url')->nullable();
            $table->string('status')->default('active');
            $table->string('legacy_id')->nullable()->index();
            $table->timestamps();
        });

        Schema::create('stock_movements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shop_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_id')->constrained()->cascadeOnDelete();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->integer('quantity');
            $table->string('type')->default('in'); // in, out, adjustment
            $table->string('batch_number')->nullable();
            $table->date('expiry_date')->nullable();
            $table->decimal('cost_price', 15, 2)->default(0);
            $table->string('supplier_legacy_id')->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('legacy_id')->nullable()->index();
            $table->timestamps();
        });

        Schema::create('customers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shop_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('email')->nullable();
            $table->string('phone')->nullable();
            $table->string('address')->nullable();
            $table->text('notes')->nullable();
            $table->decimal('discount_percent', 8, 2)->default(0);
            $table->string('loyalty_tier')->nullable();
            $table->unsignedInteger('purchase_count')->default(0);
            $table->decimal('total_spent', 15, 2)->default(0);
            $table->decimal('open_debt_balance', 15, 2)->default(0);
            $table->boolean('is_active')->default(true);
            $table->string('legacy_id')->nullable()->index();
            $table->timestamps();
        });

        Schema::create('sales', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shop_id')->constrained()->cascadeOnDelete();
            $table->foreignId('cashier_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('customer_id')->nullable()->constrained()->nullOnDelete();
            $table->string('serial_number')->nullable()->index();
            $table->string('payment_method')->default('cash');
            $table->decimal('subtotal', 15, 2)->default(0);
            $table->decimal('tax', 15, 2)->default(0);
            $table->decimal('discount', 15, 2)->default(0);
            $table->decimal('total', 15, 2)->default(0);
            $table->decimal('amount_tendered', 15, 2)->nullable();
            $table->decimal('change_amount', 15, 2)->nullable();
            $table->string('customer_name')->nullable();
            $table->string('customer_phone')->nullable();
            $table->string('customer_address')->nullable();
            $table->string('customer_id_type')->nullable();
            $table->string('customer_id_number')->nullable();
            $table->string('discount_mode')->nullable();
            $table->decimal('manual_discount_percent', 8, 2)->nullable();
            $table->decimal('manual_discount_amount', 15, 2)->nullable();
            $table->boolean('apply_loyalty_discount')->default(false);
            $table->string('status')->default('completed');
            $table->string('legacy_id')->nullable()->index();
            $table->timestamps();
        });

        Schema::create('sale_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sale_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_id')->nullable()->constrained()->nullOnDelete();
            $table->string('product_name');
            $table->integer('quantity');
            $table->decimal('unit_price', 15, 2);
            $table->decimal('line_total', 15, 2);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sale_items');
        Schema::dropIfExists('sales');
        Schema::dropIfExists('customers');
        Schema::dropIfExists('stock_movements');
        Schema::dropIfExists('products');
        Schema::dropIfExists('categories');
    }
};
