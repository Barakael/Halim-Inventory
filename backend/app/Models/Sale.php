<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Sale extends Model
{
    protected $fillable = [
        'shop_id', 'cashier_id', 'customer_id', 'serial_number', 'payment_method',
        'subtotal', 'tax', 'discount', 'total', 'amount_tendered', 'change_amount',
        'customer_name', 'customer_phone', 'customer_address', 'customer_id_type',
        'customer_id_number', 'discount_mode', 'manual_discount_percent',
        'manual_discount_amount', 'apply_loyalty_discount', 'status', 'legacy_id',
        'client_sale_id',
    ];

    protected function casts(): array
    {
        return [
            'subtotal' => 'float',
            'tax' => 'float',
            'discount' => 'float',
            'total' => 'float',
            'amount_tendered' => 'float',
            'change_amount' => 'float',
            'manual_discount_percent' => 'float',
            'manual_discount_amount' => 'float',
            'apply_loyalty_discount' => 'boolean',
        ];
    }

    public function shop(): BelongsTo
    {
        return $this->belongsTo(Shop::class);
    }

    public function cashier(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cashier_id');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(SaleItem::class);
    }

    public function scopeForShop(Builder $query, int $shopId): Builder
    {
        return $query->where('shop_id', $shopId);
    }

    public function toApiArray(): array
    {
        return [
            'id' => $this->id,
            'serial_number' => $this->serial_number,
            'payment_method' => $this->payment_method,
            'subtotal' => (float) $this->subtotal,
            'total' => (float) $this->total,
            'tax' => (float) $this->tax,
            'total_tax' => (float) $this->tax,
            'discount' => (float) $this->discount,
            'amount_tendered' => $this->amount_tendered !== null ? (float) $this->amount_tendered : null,
            'change' => $this->change_amount !== null ? (float) $this->change_amount : null,
            'shop_customer_id' => $this->customer_id,
            'customer_name' => $this->customer_name,
            'customer_phone' => $this->customer_phone,
            'customer_address' => $this->customer_address,
            'cashier_id' => $this->cashier_id,
            'cashier_name' => $this->relationLoaded('cashier') && $this->cashier
                ? $this->cashier->name
                : null,
            'shop_id' => $this->shop_id,
            'shop' => $this->relationLoaded('shop') && $this->shop
                ? $this->shop->toApiArray()
                : null,
            'items' => $this->relationLoaded('items')
                ? $this->items->map(fn (SaleItem $i) => $i->toApiArray())->values()->all()
                : [],
            'created_at' => optional($this->created_at)?->toISOString(),
        ];
    }
}
