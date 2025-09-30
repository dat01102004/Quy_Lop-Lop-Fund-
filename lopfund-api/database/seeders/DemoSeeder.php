<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use App\Models\{User,Classroom,ClassMember,FundAccount,FeeCycle,Invoice};

class DemoSeeder extends Seeder
{
  public function run(): void
  {
    $owner = User::firstOrCreate(
      ['email'=>'owner@example.com'],
      ['name'=>'Owner','password'=>Hash::make('password'),'role'=>'owner']
    );
    $m1 = User::firstOrCreate(['email'=>'sv1@example.com'],['name'=>'SV1','password'=>Hash::make('password'),'role'=>'member']);
    $m2 = User::firstOrCreate(['email'=>'sv2@example.com'],['name'=>'SV2','password'=>Hash::make('password'),'role'=>'member']);

    $class = Classroom::create([
      'name'=>'CNTT K45','year'=>'2025-2026','owner_id'=>$owner->id,'join_code'=>'ABC123'
    ]);

    ClassMember::create(['class_id'=>$class->id,'user_id'=>$owner->id,'role'=>'owner','status'=>'active','joined_at'=>now()]);
    $cm1 = ClassMember::create(['class_id'=>$class->id,'user_id'=>$m1->id,'role'=>'member','status'=>'active','joined_at'=>now()]);
    $cm2 = ClassMember::create(['class_id'=>$class->id,'user_id'=>$m2->id,'role'=>'member','status'=>'active','joined_at'=>now()]);

    FundAccount::create(['class_id'=>$class->id,'name'=>'TK Lớp','bank_name'=>'VCB','account_no'=>'00112233','account_holder'=>'CNTT K45']);

    $cycle = FeeCycle::create(['class_id'=>$class->id,'name'=>'Quỹ HK1/2025','term'=>'HK1 2025','amount_per_member'=>200000,'status'=>'active']);
    foreach ([$cm1,$cm2] as $cm) {
      Invoice::create(['fee_cycle_id'=>$cycle->id,'member_id'=>$cm->id,'amount'=>200000,'status'=>'unpaid']);
    }
  }
}
