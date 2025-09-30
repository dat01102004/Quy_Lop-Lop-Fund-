<?php

namespace App\Http\Controllers;

use App\Models\Classroom;
use App\Models\Invoice;
use App\Models\Payment;
use App\Models\ClassMember;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use App\Support\ClassAccess;
use Symfony\Component\HttpFoundation\JsonResponse;

class PaymentController extends Controller
{
    // ====================== MEMBER SUBMIT (có thể kèm ảnh) ======================

    public function submit(Request $r, Classroom $class, Invoice $invoice): JsonResponse
    {
        ClassAccess::ensureMember($r->user(), $class);
        abort_unless($invoice->cycle->class_id === $class->id, 404);

        $member = ClassMember::where('class_id', $class->id)
            ->where('user_id', $r->user()->id)->firstOrFail();

        abort_unless($invoice->member_id === $member->id, 403, 'Không phải hóa đơn của bạn');

        $data = $r->validate([
            'amount'   => 'required|integer|min:0',
            'method'   => 'sometimes|in:bank,momo,zalopay,cash',
            'txn_ref'  => 'nullable|string|max:100',
            // ảnh có thể gửi luôn trong submit
            'image'    => 'nullable|image|max:4096',
            'proof'    => 'nullable|image|max:4096',
        ]);

        $data['invoice_id'] = $invoice->id;
        $data['payer_id']   = $member->id;
        $data['status']     = 'submitted';
        $data['method']     = $data['method'] ?? 'bank';

        $pay = Payment::create($data);

        // nếu kèm ảnh -> lưu ngay
        $file = $r->file('image') ?: $r->file('proof');
        if ($file) {
            $path = $file->store('proofs', 'public');          // proofs/xxx.jpg
            $pay->proof_path = asset('storage/'.$path);        // http(s)://.../storage/proofs/xxx.jpg
            $pay->save();
        }

        if ($invoice->status === 'unpaid') {
            $invoice->update(['status' => 'submitted']);
        }

        return response()->json(['payment' => $pay], 201);
    }

    // ====================== MEMBER UPLOAD PROOF (multipart) ======================

    public function uploadProof(Request $r, Classroom $class, Payment $payment): JsonResponse
    {
        ClassAccess::ensureMember($r->user(), $class);

        $member = ClassMember::where('class_id', $class->id)
            ->where('user_id', $r->user()->id)->firstOrFail();

        abort_unless($payment->payer_id === $member->id, 403, 'Không phải phiếu của bạn');

        $r->validate([
            'image' => 'nullable|image|max:4096',
            'proof' => 'nullable|image|max:4096',
        ]);

        $file = $r->file('image') ?: $r->file('proof');
        if (!$file) {
            return response()->json(['message' => 'Chưa chọn file'], 422);
        }

        $path = $file->store('proofs', 'public');
        $payment->proof_path = asset('storage/'.$path);        // /storage/proofs/xxx.jpg
        $payment->save();

        return response()->json(['payment' => $payment]);
    }

    // ====================== TREASURER/OWNER: LIST ======================

    // GET /classes/{class}/payments?status=submitted&group=cycle
    public function index(Request $r, Classroom $class): JsonResponse
    {
        ClassAccess::ensureTreasurerLike($r->user(), $class);

        $status = $r->query('status', 'submitted');
        $group  = $r->query('group'); // 'cycle' | null

        $q = DB::table('payments as p')
            ->join('invoices as i', 'i.id', '=', 'p.invoice_id')
            ->join('fee_cycles as fc', 'fc.id', '=', 'i.fee_cycle_id')
            ->join('class_members as cm', 'cm.id', '=', 'p.payer_id')
            ->join('users as u', 'u.id', '=', 'cm.user_id')
            ->where('fc.class_id', $class->id)
            ->when($status, fn ($q) => $q->where('p.status', $status))
            ->orderByDesc('p.created_at')
            ->select([
                'p.id',
                'p.invoice_id',
                'p.amount',
                'p.status',
                'p.method',
                'p.txn_ref',
                'p.proof_path',
                'p.created_at',
                'u.name as payer_name',
                'u.email as payer_email',
                'i.amount as invoice_amount',
                'fc.id as cycle_id',
                'fc.name as cycle_name',
            ]);

        if ($group === 'cycle') {
            $rows = $q->get();
            $grouped = $rows->groupBy('cycle_id')->map(function ($items, $cycleId) {
                $first = $items->first();
                return [
                    'cycle_id'   => (int) $cycleId,
                    'cycle_name' => $first->cycle_name,
                    'payments'   => $items->map(fn ($x) => [
                        'id'           => (int) $x->id,
                        'invoice_id'   => (int) $x->invoice_id,
                        'amount'       => (int) $x->amount,
                        'status'       => $x->status,
                        'method'       => $x->method,
                        'payer_name'   => $x->payer_name,
                        'payer_email'  => $x->payer_email,
                        'proof_path'   => $x->proof_path,
                        'created_at'   => $x->created_at,
                    ])->values(),
                ];
            })->values();

            return response()->json(['cycles' => $grouped]);
        }

        return response()->json(['payments' => $q->get()]);
    }

    // ====================== TREASURER/OWNER: DETAIL ======================

    // GET /classes/{class}/payments/{payment}
    public function show(Request $r, Classroom $class, Payment $payment): JsonResponse
    {
        ClassAccess::ensureTreasurerLike($r->user(), $class);

        $ok = DB::table('payments as p')
            ->join('invoices as i', 'i.id', '=', 'p.invoice_id')
            ->join('fee_cycles as fc', 'fc.id', '=', 'i.fee_cycle_id')
            ->where('p.id', $payment->id)
            ->where('fc.class_id', $class->id)
            ->exists();

        if (!$ok) {
            return response()->json(['message' => 'Payment không thuộc lớp này'], 404);
        }

        $row = DB::table('payments as p')
            ->join('invoices as i', 'i.id', '=', 'p.invoice_id')
            ->join('fee_cycles as fc', 'fc.id', '=', 'i.fee_cycle_id')
            ->join('class_members as cm', 'cm.id', '=', 'p.payer_id')
            ->join('users as u', 'u.id', '=', 'cm.user_id')
            ->leftJoin('users as v', 'v.id', '=', 'p.verified_by')
            ->where('p.id', $payment->id)
            ->select([
                'p.id','p.invoice_id','p.amount','p.status','p.method','p.txn_ref',
                'p.proof_path','p.created_at','p.verified_at',
                'u.name as payer_name','u.email as payer_email',
                'i.amount as invoice_amount','i.status as invoice_status',
                'fc.name as cycle_name',
                'v.name as verified_by_name',
            ])
            ->first();

        return response()->json(['payment' => $row]);
    }

    // ====================== TREASURER/OWNER: VERIFY ======================

    // POST /classes/{class}/payments/{payment}/verify  { action: approve|reject }
    public function verify(Request $r, Classroom $class, Payment $payment): JsonResponse
    {
        ClassAccess::ensureTreasurerLike($r->user(), $class);

        $data = $r->validate([
            'action' => 'required|in:approve,reject',
            // 'note' => 'nullable|string', // nếu sau này có cột note
        ]);

        // đảm bảo phiếu thuộc lớp
        $ok = DB::table('payments as p')
            ->join('invoices as i', 'i.id', '=', 'p.invoice_id')
            ->join('fee_cycles as fc', 'fc.id', '=', 'i.fee_cycle_id')
            ->where('p.id', $payment->id)
            ->where('fc.class_id', $class->id)
            ->exists();

        if (!$ok) {
            return response()->json(['message' => 'Payment không thuộc lớp này'], 404);
        }

        if ($payment->status !== 'submitted') {
            return response()->json(['message' => 'Payment không ở trạng thái chờ duyệt'], 422);
        }

        if ($data['action'] === 'approve') {
            $payment->update([
                'status'      => 'verified',
                'verified_by' => $r->user()->id,
                'verified_at' => now(),
            ]);

            // đồng bộ invoice -> verified khi đủ số tiền
            $invoice = $payment->invoice()->with('payments')->first();
            $sumVerified = $invoice->payments->where('status', 'verified')->sum('amount');
            if ($sumVerified >= $invoice->amount && $invoice->status !== 'paid') {
                $invoice->update(['status' => 'verified']);
            }
        } else {
            // reject
            $payment->update([
                'status'      => 'rejected',
                'verified_by' => $r->user()->id,
                'verified_at' => now(),
            ]);
        }

        return response()->json(['message' => 'Cập nhật thành công', 'status' => $payment->status]);
    }
    public function approvedList(Request $r, Classroom $class): JsonResponse
    {
        ClassAccess::ensureMember($r->user(), $class);

        $feeCycleId = $r->query('fee_cycle_id');
        $from       = $r->query('from');
        $to         = $r->query('to');
        $group      = $r->query('group'); // 'cycle' | null

        // xác định role người gọi
        $me = ClassMember::where('class_id', $class->id)
            ->where('user_id', $r->user()->id)->firstOrFail();
        $isTreasurerLike = in_array($me->role, ['owner', 'treasurer'], true);

        // lọc theo người nộp nếu được yêu cầu
        $filterMemberId = null;
        if ($r->filled('member_id')) {
            $filterMemberId = (int) $r->query('member_id');
        } elseif ($r->filled('user_id')) {
            $u = ClassMember::where('class_id', $class->id)
                ->where('user_id', (int) $r->query('user_id'))->first();
            $filterMemberId = $u?->id;
        }

        // nếu member thường cố xem người khác -> chặn
        if (!$isTreasurerLike && $filterMemberId !== null && $filterMemberId !== $me->id) {
            return response()->json(['message' => 'Bạn không có quyền xem người khác'], 403);
        }

        // nếu member thường không chỉ định ai -> mặc định chỉ xem chính mình
        if (!$isTreasurerLike && $filterMemberId === null) {
            $filterMemberId = $me->id;
        }

        $approvedStatuses = ['verified', 'paid'];
        $dateCol = Schema::hasColumn('payments', 'approved_at') ? 'approved_at' : 'created_at';

        $q = DB::table('payments as p')
            ->join('invoices as i', 'i.id', '=', 'p.invoice_id')
            ->join('fee_cycles as fc', 'fc.id', '=', 'i.fee_cycle_id')
            ->join('class_members as cm', 'cm.id', '=', 'p.payer_id')
            ->join('users as u', 'u.id', '=', 'cm.user_id')
            ->leftJoin('users as v', 'v.id', '=', 'p.verified_by')
            ->where('fc.class_id', $class->id)
            ->whereIn('p.status', $approvedStatuses)
            ->when($feeCycleId, fn($q) => $q->where('i.fee_cycle_id', $feeCycleId))
            ->when($filterMemberId, fn($q) => $q->where('p.payer_id', $filterMemberId))
            ->when($from, fn($q) => $q->whereDate("p.$dateCol", '>=', $from))
            ->when($to,   fn($q) => $q->whereDate("p.$dateCol", '<=', $to))
            ->orderByDesc("p.$dateCol")
            ->select([
                'p.id',
                'p.invoice_id',
                'p.amount',
                'p.status',
                'p.method',
                'p.txn_ref',
                'p.proof_path',
                "p.$dateCol as approved_at",
                'u.name as payer_name',
                'u.email as payer_email',
                'i.amount as invoice_amount',
                'i.status as invoice_status',
                'fc.id as cycle_id',
                'fc.name as cycle_name',
                'v.name as verified_by_name',
            ]);

        if ($group === 'cycle') {
            $rows = $q->get();
            $grouped = $rows->groupBy('cycle_id')->map(function ($items, $cycleId) {
                $first = $items->first();
                return [
                    'cycle_id'   => (int) $cycleId,
                    'cycle_name' => $first->cycle_name,
                    'payments'   => $items->map(function ($x) {
                        return [
                            'id'                => (int) $x->id,
                            'invoice_id'        => (int) $x->invoice_id,
                            'amount'            => (int) $x->amount,
                            'method'            => $x->method,
                            'status'            => $x->status,
                            'txn_ref'           => $x->txn_ref,
                            'proof_path'        => $x->proof_path,
                            'approved_at'       => $x->approved_at,
                            'payer_name'        => $x->payer_name,
                            'payer_email'       => $x->payer_email,
                            'invoice_amount'    => (int) $x->invoice_amount,
                            'invoice_status'    => $x->invoice_status,
                            'verified_by_name'  => $x->verified_by_name,
                        ];
                    })->values(),
                ];
            })->values();

            return response()->json(['cycles' => $grouped]);
        }
            return response()->json(['payments' => $q->get()]);
    }

}
