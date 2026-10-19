<?php

namespace App\Console\Commands;

use App\Models\Customer;
use App\Models\CustomerDebt;
use App\Models\Sale;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class SyncCreditSaleDebts extends Command
{
    protected $signature = 'debts:sync-credit-sales';

    protected $description = 'Create customer_debts rows for credit sales that are missing them';

    public function handle(): int
    {
        $created = 0;
        $skipped = 0;

        Sale::query()
            ->whereRaw('LOWER(payment_method) = ?', ['credit'])
            ->orderBy('id')
            ->chunkById(100, function ($sales) use (&$created, &$skipped) {
                foreach ($sales as $sale) {
                    if (CustomerDebt::where('sale_id', $sale->id)->exists()) {
                        $skipped++;
                        continue;
                    }

                    DB::transaction(function () use ($sale, &$created, &$skipped) {
                        $customer = null;
                        if ($sale->customer_id) {
                            $customer = Customer::find($sale->customer_id);
                        }

                        if (! $customer) {
                            $name = trim((string) ($sale->customer_name ?? ''));
                            $phone = trim((string) ($sale->customer_phone ?? ''));
                            if ($name === '' && $phone === '') {
                                $skipped++;

                                return;
                            }
                            if ($name === '') {
                                $name = $phone;
                            }
                            $customer = Customer::create([
                                'shop_id' => $sale->shop_id,
                                'name' => $name,
                                'phone' => $phone !== '' ? $phone : null,
                                'is_active' => true,
                            ]);
                            $sale->customer_id = $customer->id;
                            $sale->save();
                        }

                        $amount = (float) $sale->total;
                        if ($amount <= 0) {
                            $skipped++;

                            return;
                        }

                        CustomerDebt::create([
                            'shop_id' => $sale->shop_id,
                            'customer_id' => $customer->id,
                            'sale_id' => $sale->id,
                            'amount' => $amount,
                            'amount_paid' => 0,
                            'status' => 'open',
                            'note' => 'POS sale '.($sale->serial_number ?? $sale->id),
                            'created_at' => $sale->created_at,
                            'updated_at' => $sale->updated_at,
                        ]);
                        CustomerDebt::recomputeOpenBalance($customer->fresh());
                        $created++;
                    });
                }
            });

        $this->info("Created {$created} debt(s); skipped {$skipped}.");

        return self::SUCCESS;
    }
}
