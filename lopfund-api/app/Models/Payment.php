<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Payment extends Model {
    protected $fillable = [
    'invoice_id','payer_id','amount','status','method','txn_ref','proof_path',
    'verified_by','verified_at','note'];
    protected $casts = ['verified_at'=>'datetime'];
    public function invoice(){ return $this->belongsTo(Invoice::class); }
    public function payer(){ return $this->belongsTo(Member::class,'payer_id'); }
    public function verifier(){ return $this->belongsTo(User::class,'verified_by'); }
}
