<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Purchase extends Model
{
    protected $fillable = [
        'shop_id', 'supplier_id', 'created_by', 'status', 'payment_type',
        'reference', 'notes', 'delivered_by_name', 'delivered_by_phone',
        'subtotal', 'amount_paid', 'payment_status', 'purchased_at', 'received_at', 'legacy_id',
    ];

    protected function casts(): array
    {
        return [
            'subtotal' => 'float',
            'amount_paid' => 'float',
            'purchased_at' => 'date',
            'received_at' => 'datetime',
        ];
    }

    public function shop(): BelongsTo
    {
        return $this->belongsTo(Shop::class);
    }

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function items(): HasMany
    {
        return $this->hasMany(PurchaseItem::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(PurchasePayment::class)->orderByDesc('paid_at');
    }

    public function scopeForShop(Builder $query, int $shopId): Builder
    {
        return $query->where('shop_id', $shopId);
    }

    public function remaining(): float
    {
        return max(0, (float) $this->subtotal - (float) $this->amount_paid);
    }

    public function toApiArray(): array
    {
        $items = $this->relationLoaded('items') ? $this->items : collect();
        $productNames = $items->pluck('product_name')->filter()->values()->all();
        $totalQty = (int) $items->sum('quantity');

        return [
            'id' => $this->id,
            'status' => $this->status,
            'payment_type' => $this->payment_type ?? 'credit',
            'payment_status' => $this->payment_status ?? 'unpaid',
            'subtotal' => (float) $this->subtotal,
            'amount_paid' => (float) ($this->amount_paid ?? 0),
            'remaining' => $this->remaining(),
            'supplier_id' => $this->supplier_id,
            'supplier' => $this->relationLoaded('supplier') && $this->supplier
                ? $this->supplier->toApiArray()
                : null,
            'supplier_name' => $this->supplier?->name,
            'reference' => $this->reference,
            'notes' => $this->notes,
            'delivered_by_name' => $this->delivered_by_name,
            'delivered_by_phone' => $this->delivered_by_phone,
            'purchased_at' => optional($this->purchased_at)?->format('Y-m-d'),
            'received_at' => optional($this->received_at)?->toISOString(),
            'product_names' => $productNames,
            'total_qty' => $totalQty,
            'creator' => $this->relationLoaded('creator') && $this->creator
                ? ['id' => $this->creator->id, 'name' => $this->creator->name]
                : null,
            'items' => $this->relationLoaded('items')
                ? $this->items->map->toApiArray()->values()->all()
                : [],
            'payments' => $this->relationLoaded('payments')
                ? $this->payments->map->toApiArray()->values()->all()
                : [],
            'shop_id' => $this->shop_id,
        ];
    }
}
