<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Customer extends Model
{
    protected $fillable = [
        'shop_id', 'name', 'email', 'phone', 'address', 'notes',
        'discount_percent', 'loyalty_tier', 'purchase_count', 'total_spent',
        'open_debt_balance', 'is_active', 'legacy_id',
    ];

    protected function casts(): array
    {
        return [
            'discount_percent' => 'float',
            'total_spent' => 'float',
            'open_debt_balance' => 'float',
            'is_active' => 'boolean',
            'purchase_count' => 'integer',
        ];
    }

    public function shop(): BelongsTo
    {
        return $this->belongsTo(Shop::class);
    }

    public function debts(): HasMany
    {
        return $this->hasMany(CustomerDebt::class);
    }

    public function scopeForShop(Builder $query, int $shopId): Builder
    {
        return $query->where('shop_id', $shopId);
    }

    public function toApiArray(): array
    {
        $debts = $this->relationLoaded('debts')
            ? $this->debts->map->toApiArray()->values()->all()
            : [];

        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'address' => $this->address,
            'notes' => $this->notes,
            'discount_percent' => (float) $this->discount_percent,
            'loyalty_tier' => $this->loyalty_tier,
            'purchase_count' => (int) $this->purchase_count,
            'total_spent' => (float) $this->total_spent,
            'open_debt_balance' => (float) $this->open_debt_balance,
            'is_active' => (bool) $this->is_active,
            'shop_id' => $this->shop_id,
            'debts' => $debts,
        ];
    }
}
