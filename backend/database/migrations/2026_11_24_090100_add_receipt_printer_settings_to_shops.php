<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shops', function (Blueprint $table) {
            $table->unsignedSmallInteger('receipt_paper_mm')->default(58)->after('receipt_footer');
            $table->boolean('skip_builtin_printer')->default(false)->after('receipt_paper_mm');
        });
    }

    public function down(): void
    {
        Schema::table('shops', function (Blueprint $table) {
            $table->dropColumn(['receipt_paper_mm', 'skip_builtin_printer']);
        });
    }
};
