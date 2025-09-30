<?php

namespace App\Http\Controllers;

use App\Models\Classroom;
use App\Models\FundAccount;
use App\Support\ClassAccess;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;          // <-- THÊM DÒNG NÀY
use Symfony\Component\HttpFoundation\JsonResponse;

class FundAccountController extends Controller
{
    // GET /classes/{class}/fund-account
    public function show(Request $r, Classroom $class): JsonResponse
    {
        ClassAccess::ensureMember($r->user(), $class);

        $row = FundAccount::where('class_id', $class->id)->first();

        return response()->json([
            'fund_account' => $row ? [
                'bank_code'      => $row->bank_code,
                'account_number' => $row->account_number,
                'account_name'   => $row->account_name,
            ] : null,
        ], 200);
    }

    // PUT /classes/{class}/fund-account
    public function upsert(Request $r, Classroom $class): JsonResponse
    {
        ClassAccess::ensureTreasurerLike($r->user(), $class);

        $data = $r->validate([
            'bank_code'      => 'required|string|max:20',
            'account_number' => 'required|string|max:50',
            'account_name'   => 'required|string|max:120',
        ]);

        $row = FundAccount::updateOrCreate(
            ['class_id' => $class->id],
            [
                'bank_code'      => strtoupper($data['bank_code']),
                'account_number' => $data['account_number'],
                'account_name'   => mb_strtoupper($data['account_name']),
            ],
        );

        return response()->json([
            'fund_account' => [
                'bank_code'      => $row->bank_code,
                'account_number' => $row->account_number,
                'account_name'   => $row->account_name,
            ],
            'updated' => true,
        ], 200);
    }

    // ✅ GET /classes/{class}/fund-account/summary
    // Tổng hợp theo lớp: tổng thu (payments đã xác nhận), tổng chi (expenses), số dư
    public function summary(Request $r, Classroom $class): JsonResponse
    {
        ClassAccess::ensureMember($r->user(), $class);

        $feeCycleId = $r->query('fee_cycle_id');   // optional
        $from       = $r->query('from');           // YYYY-MM-DD (optional)
        $to         = $r->query('to');             // YYYY-MM-DD (optional)

        // ✅ THU: join invoices → fee_cycles để lọc theo class
        $income = DB::table('payments as p')
            ->join('invoices as i', 'i.id', '=', 'p.invoice_id')
            ->join('fee_cycles as fc', 'fc.id', '=', 'i.fee_cycle_id')
            ->where('fc.class_id', $class->id)
            ->where('p.status', 'verified')                       // chỉ tính đã duyệt
            ->when($feeCycleId, fn($q) => $q->where('i.fee_cycle_id', $feeCycleId))
            ->when($from,      fn($q) => $q->whereDate('p.created_at', '>=', $from))
            ->when($to,        fn($q) => $q->whereDate('p.created_at', '<=', $to))
            ->sum('p.amount');

        // CHI: bảng expenses đã có class_id nên giữ nguyên
        $expense = DB::table('expenses as e')
            ->where('e.class_id', $class->id)
            ->when($feeCycleId, fn($q) => $q->where('e.fee_cycle_id', $feeCycleId))
            ->when($from,      fn($q) => $q->whereDate('e.created_at', '>=', $from))
            ->when($to,        fn($q) => $q->whereDate('e.created_at', '<=', $to))
            ->sum('e.amount');

        return response()->json([
            'total_income'  => (int) $income,
            'total_expense' => (int) $expense,
            'balance'       => (int) $income - (int) $expense,
            'status'        => 200,
        ], 200);
}

}
