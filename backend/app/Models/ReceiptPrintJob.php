<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ReceiptPrintJob extends Model
{
    protected $fillable = [
        'shop_id', 'sale_id', 'serial_number', 'cashier_id', 'customer_name',
        'payment_method', 'amount', 'status', 'printed_at', 'printed_by',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'float',
            'printed_at' => 'datetime',
        ];
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function cashier(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cashier_id');
    }

    public function printedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'printed_by');
    }

    public function scopeForShop(Builder $query, int $shopId): Builder
    {
        return $query->where('shop_id', $shopId);
    }

    public function toApiArray(bool $canPrint = false): array
    {
        return [
            'id' => $this->id,
            'sale_id' => $this->sale_id,
            'serial_number' => $this->serial_number,
            'cashier_id' => $this->cashier_id,
            'cashier_name' => $this->relationLoaded('cashier') && $this->cashier
                ? $this->cashier->name
                : null,
            'customer_name' => $this->customer_name,
            'payment_method' => $this->payment_method,
            'amount' => (float) $this->amount,
            'status' => $this->status,
            'printed_at' => optional($this->printed_at)?->toISOString(),
            'printed_by' => $this->printed_by,
            'printed_by_name' => $this->relationLoaded('printedBy') && $this->printedBy
                ? $this->printedBy->name
                : null,
            'can_print' => $canPrint,
            'created_at' => optional($this->created_at)?->toISOString(),
        ];
    }
}
