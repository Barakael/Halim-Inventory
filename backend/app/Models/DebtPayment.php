<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DebtPayment extends Model
{
    protected $fillable = [
        'customer_debt_id', 'amount', 'note', 'created_by',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'float',
        ];
    }

    public function debt(): BelongsTo
    {
        return $this->belongsTo(CustomerDebt::class, 'customer_debt_id');
    }
}
