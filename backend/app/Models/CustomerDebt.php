<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CustomerDebt extends Model
{
    protected $fillable = [
        'shop_id', 'customer_id', 'amount', 'amount_paid', 'status', 'note', 'due_date', 'legacy_id',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'float',
            'amount_paid' => 'float',
            'due_date' => 'date',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(DebtPayment::class);
    }

    public function scopeForShop(Builder $query, int $shopId): Builder
    {
        return $query->where('shop_id', $shopId);
    }

    public function balance(): float
    {
        return max(0, (float) $this->amount - (float) $this->amount_paid);
    }

    public function toApiArray(): array
    {
        return [
            'id' => $this->id,
            'customer_id' => $this->customer_id,
            'customer' => $this->relationLoaded('customer') && $this->customer
                ? [
                    'id' => $this->customer->id,
                    'name' => $this->customer->name,
                    'phone' => $this->customer->phone,
                ]
                : null,
            'amount' => (float) $this->amount,
            'amount_paid' => (float) $this->amount_paid,
            'balance' => $this->balance(),
            'status' => $this->status,
            'note' => $this->note,
            'due_date' => optional($this->due_date)?->format('Y-m-d'),
            'created_at' => optional($this->created_at)?->toISOString(),
            'shop_id' => $this->shop_id,
        ];
    }
}
