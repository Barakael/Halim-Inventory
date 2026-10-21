<?php

namespace App\Services;

use App\Models\Purchase;
use App\Models\PurchasePayment;

class PurchasePaymentService
{
    public function recalculate(Purchase $purchase): Purchase
    {
        $paid = (float) PurchasePayment::query()
            ->where('purchase_id', $purchase->id)
            ->sum('amount');

        $subtotal = (float) $purchase->subtotal;
        $paid = min($paid, max(0, $subtotal));
        $remaining = max(0, $subtotal - $paid);

        if ($remaining <= 0.00001 && $subtotal > 0) {
            $status = 'paid';
            $paid = $subtotal;
        } elseif ($paid > 0) {
            $status = 'partial';
        } else {
            $status = 'unpaid';
        }

        $purchase->amount_paid = round($paid, 2);
        $purchase->payment_status = $status;

        // Keep payment_type coherent with how it was settled
        if ($status === 'paid' && ($purchase->payment_type === 'credit' || $purchase->payment_type === 'partial')) {
            // leave type as originally recorded
        } elseif ($status === 'paid' && ! $purchase->payment_type) {
            $purchase->payment_type = 'cash';
        }

        $purchase->save();

        return $purchase->fresh(['items', 'supplier', 'creator', 'payments']);
    }

    public function remaining(Purchase $purchase): float
    {
        return max(0, (float) $purchase->subtotal - (float) $purchase->amount_paid);
    }
}
