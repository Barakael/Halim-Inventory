<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sales', function (Blueprint $table) {
            $table->string('client_sale_id')->nullable()->after('legacy_id');
            $table->unique(['shop_id', 'client_sale_id']);
        });
    }

    public function down(): void
    {
        Schema::table('sales', function (Blueprint $table) {
            $table->dropUnique(['shop_id', 'client_sale_id']);
            $table->dropColumn('client_sale_id');
        });
    }
};
