<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customer_debts', function (Blueprint $table) {
            $table->foreignId('sale_id')
                ->nullable()
                ->after('customer_id')
                ->constrained('sales')
                ->nullOnDelete();
            $table->unique('sale_id');
        });
    }

    public function down(): void
    {
        Schema::table('customer_debts', function (Blueprint $table) {
            $table->dropUnique(['sale_id']);
            $table->dropConstrainedForeignId('sale_id');
        });
    }
};
