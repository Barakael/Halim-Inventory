<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('purchases', function (Blueprint $table) {
            $table->string('payment_type')->default('credit')->after('status'); // cash, credit, partial
            $table->decimal('amount_paid', 15, 2)->default(0)->after('subtotal');
            $table->string('payment_status')->default('unpaid')->after('amount_paid'); // unpaid, partial, paid
            $table->string('delivered_by_name')->nullable()->after('notes');
            $table->string('delivered_by_phone')->nullable()->after('delivered_by_name');
        });

        Schema::create('purchase_payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shop_id')->constrained()->cascadeOnDelete();
            $table->foreignId('purchase_id')->constrained()->cascadeOnDelete();
            $table->foreignId('supplier_id')->nullable()->constrained()->nullOnDelete();
            $table->decimal('amount', 15, 2);
            $table->dateTime('paid_at');
            $table->string('payment_method')->nullable();
            $table->string('reference')->nullable();
            $table->text('notes')->nullable();
            $table->string('receipt_path')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['shop_id', 'paid_at']);
            $table->index(['supplier_id', 'paid_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('purchase_payments');

        Schema::table('purchases', function (Blueprint $table) {
            $table->dropColumn([
                'payment_type',
                'amount_paid',
                'payment_status',
                'delivered_by_name',
                'delivered_by_phone',
            ]);
        });
    }
};
