<?php

namespace App\Models;

use App\Support\MediaUrl;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PurchasePayment extends Model
{
    protected $fillable = [
        'shop_id', 'purchase_id', 'supplier_id', 'amount', 'paid_at',
        'payment_method', 'reference', 'notes', 'receipt_path', 'created_by',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'float',
            'paid_at' => 'datetime',
        ];
    }

    public function shop(): BelongsTo
    {
        return $this->belongsTo(Shop::class);
    }

    public function purchase(): BelongsTo
    {
        return $this->belongsTo(Purchase::class);
    }

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function scopeForShop(Builder $query, int $shopId): Builder
    {
        return $query->where('shop_id', $shopId);
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
            'purchase_id' => $this->purchase_id,
            'supplier_id' => $this->supplier_id,
            'amount' => (float) $this->amount,
            'paid_at' => optional($this->paid_at)?->toISOString(),
            'payment_method' => $this->payment_method,
            'reference' => $this->reference,
            'notes' => $this->notes,
            'receipt_path' => $this->receipt_path,
            'receipt_url' => $this->receiptUrl(),
            'created_by' => $this->created_by,
            'creator' => $this->relationLoaded('creator') && $this->creator
                ? ['id' => $this->creator->id, 'name' => $this->creator->name]
                : null,
            'created_at' => optional($this->created_at)?->toISOString(),
        ];
    }
}
