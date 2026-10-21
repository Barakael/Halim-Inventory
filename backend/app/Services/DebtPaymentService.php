<?php

namespace App\Services;

use App\Models\CustomerDebt;
use App\Models\DebtPayment;

class DebtPaymentService
{
    public function recalculate(CustomerDebt $debt): CustomerDebt
    {
        $paid = (float) DebtPayment::query()
            ->where('customer_debt_id', $debt->id)
            ->sum('amount');

        $amount = (float) $debt->amount;
        $paid = min($paid, max(0, $amount));

        $debt->amount_paid = round($paid, 2);
        if ($paid >= $amount - 0.0001 && $amount > 0) {
            $debt->status = 'paid';
            $debt->amount_paid = $amount;
        } elseif ($debt->status === 'written_off') {
            // leave written_off
        } else {
            $debt->status = 'open';
        }
        $debt->save();

        if ($debt->relationLoaded('customer') || $debt->customer) {
            CustomerDebt::recomputeOpenBalance($debt->customer);
        } else {
            CustomerDebt::recomputeOpenBalance($debt->customer()->first());
        }

        return $debt->fresh(['customer']);
    }
}
