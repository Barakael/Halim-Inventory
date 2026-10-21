<?php

namespace App\Console\Commands;

use App\Models\Purchase;
use App\Services\PurchasePaymentService;
use Illuminate\Console\Command;

class RecalculatePurchasePayments extends Command
{
    protected $signature = 'purchases:recalculate-payments {--shop= : Limit to shop id}';

    protected $description = 'Recompute amount_paid and payment_status from purchase_payments';

    public function handle(PurchasePaymentService $service): int
    {
        $query = Purchase::query();
        if ($this->option('shop')) {
            $query->where('shop_id', (int) $this->option('shop'));
        }

        $count = 0;
        $query->orderBy('id')->chunkById(100, function ($purchases) use ($service, &$count) {
            foreach ($purchases as $purchase) {
                $service->recalculate($purchase);
                $count++;
            }
        });

        $this->info("Recalculated {$count} purchases.");

        return self::SUCCESS;
    }
}
