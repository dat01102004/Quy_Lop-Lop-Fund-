<?php

namespace App\Jobs;

use App\Models\Payment;
use App\Services\AiOcrService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class ProcessPaymentProof implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(public int $paymentId) {}

    public function handle(AiOcrService $ocr): void
    {
        $payment = Payment::with(['invoice.payments'])->find($this->paymentId);
        if (!$payment || !$payment->proof_path) {
            return;
        }

        // Convert public URL -> absolute path (tuỳ bạn để đúng storage)
        $rel = preg_replace('#^/storage/#', 'storage/', $payment->proof_path);
        $abs = public_path($rel);

        $res = $ocr->extract($abs);

        DB::transaction(function () use ($payment, $res) {
            $ok = false;

            $invoiceAmt = (int)($payment->invoice->amount ?? 0);
            $ocrAmt     = (int)($res['amount'] ?? 0);
            $tolerance  = 1000; // lệch 1k coi như khớp

            if ($ocrAmt > 0 && abs($invoiceAmt - $ocrAmt) <= $tolerance) {
                $ok = true;
            }

            if ($ok) {
                $payment->status      = 'verified';
                $payment->verified_by = $payment->verified_by ?: Auth::id();
                $payment->verified_at = now();
                $payment->save();

                // Đồng bộ invoice
                $invoice = $payment->invoice()->with('payments')->first();
                $sumVerified = $invoice->payments->where('status', 'verified')->sum('amount');
                if ($sumVerified >= $invoice->amount && $invoice->status !== 'paid') {
                    $invoice->status = 'verified';
                    $invoice->save();
                }
            } else {
                // Không auto-verify: để submitted, chờ thủ quỹ duyệt tay
                if ($payment->status !== 'verified') {
                    $payment->status = 'submitted';
                    $payment->save();
                }
            }
        });
    }
}
