<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('debt_payments', function (Blueprint $table) {
            $table->string('payment_method')->nullable()->after('amount');
            $table->string('reference')->nullable()->after('payment_method');
            $table->string('receipt_path')->nullable()->after('note');
            $table->dateTime('paid_at')->nullable()->after('receipt_path');
            $table->foreignId('shop_id')->nullable()->after('id')->constrained()->nullOnDelete();
        });

        // Backfill paid_at and shop_id from parent debt
        if (Schema::hasTable('debt_payments') && Schema::hasTable('customer_debts')) {
            \Illuminate\Support\Facades\DB::statement(
                'UPDATE debt_payments dp
                 INNER JOIN customer_debts cd ON cd.id = dp.customer_debt_id
                 SET dp.paid_at = COALESCE(dp.paid_at, dp.created_at),
                     dp.shop_id = COALESCE(dp.shop_id, cd.shop_id)'
            );
        }
    }

    public function down(): void
    {
        Schema::table('debt_payments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('shop_id');
            $table->dropColumn(['payment_method', 'reference', 'receipt_path', 'paid_at']);
        });
    }
};
