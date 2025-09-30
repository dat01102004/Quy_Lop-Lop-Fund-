<?php

// database/migrations/2025_09_25_000001_add_ocr_fields_to_payments_table.php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::table('payments', function (Blueprint $table) {
            $table->longText('proof_ocr_text')->nullable()->after('proof_path');
            $table->json('proof_ocr_json')->nullable()->after('proof_ocr_text');
            $table->unsignedTinyInteger('proof_ocr_confidence')->nullable()->after('proof_ocr_json'); // 0..100
            $table->string('txn_ref')->nullable()->change();   // nếu chưa có, bạn thêm riêng
            $table->string('method')->nullable()->change();    // bank/momo/cash/...
        });
    }
    public function down(): void {
        Schema::table('payments', function (Blueprint $table) {
            $table->dropColumn(['proof_ocr_text','proof_ocr_json','proof_ocr_confidence']);
        });
    }
};
