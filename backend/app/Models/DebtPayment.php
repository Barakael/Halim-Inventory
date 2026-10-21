<?php

namespace App\Models;

use App\Support\MediaUrl;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DebtPayment extends Model
{
    protected $fillable = [
        'shop_id', 'customer_debt_id', 'amount', 'payment_method', 'reference',
        'note', 'receipt_path', 'paid_at', 'created_by',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'float',
            'paid_at' => 'datetime',
        ];
    }

    public function debt(): BelongsTo
    {
        return $this->belongsTo(CustomerDebt::class, 'customer_debt_id');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function receiptUrl(): ?string
    {
        return MediaUrl::fromPublicPath($this->receipt_path);
    }

    public function toApiArray(): array
    {
        return [
            'id' => $this->id,
            'shop_id' => $this->shop_id,
            'customer_debt_id' => $this->customer_debt_id,
            'amount' => (float) $this->amount,
            'payment_method' => $this->payment_method,
            'reference' => $this->reference,
            'note' => $this->note,
            'receipt_path' => $this->receipt_path,
            'receipt_url' => $this->receiptUrl(),
            'paid_at' => optional($this->paid_at ?? $this->created_at)?->toISOString(),
            'created_by' => $this->created_by,
            'creator' => $this->relationLoaded('creator') && $this->creator
                ? ['id' => $this->creator->id, 'name' => $this->creator->name]
                : null,
            'created_at' => optional($this->created_at)?->toISOString(),
        ];
    }
}
