<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Purchase extends Model
{
    protected $fillable = [
        'shop_id', 'supplier_id', 'created_by', 'status', 'reference', 'notes',
        'subtotal', 'purchased_at', 'received_at', 'legacy_id',
    ];

    protected function casts(): array
    {
        return [
            'subtotal' => 'float',
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

    public function scopeForShop(Builder $query, int $shopId): Builder
    {
        return $query->where('shop_id', $shopId);
    }

    public function toApiArray(): array
    {
        return [
            'id' => $this->id,
            'status' => $this->status,
            'subtotal' => (float) $this->subtotal,
            'supplier_id' => $this->supplier_id,
            'supplier' => $this->relationLoaded('supplier') && $this->supplier
                ? $this->supplier->toApiArray()
                : null,
            'supplier_name' => $this->supplier?->name,
            'reference' => $this->reference,
            'notes' => $this->notes,
            'purchased_at' => optional($this->purchased_at)?->format('Y-m-d'),
            'received_at' => optional($this->received_at)?->toISOString(),
            'creator' => $this->relationLoaded('creator') && $this->creator
                ? ['id' => $this->creator->id, 'name' => $this->creator->name]
                : null,
            'items' => $this->relationLoaded('items')
                ? $this->items->map->toApiArray()->values()->all()
                : [],
            'shop_id' => $this->shop_id,
        ];
    }
}
