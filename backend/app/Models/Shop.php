<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Shop extends Model
{
    use HasFactory;

    protected $fillable = [
        'name', 'address', 'phone', 'email', 'tax_rate', 'currency',
        'tin', 'vrn', 'mobile', 'location', 'tax_office', 'serial_prefix',
        'receipt_footer', 'status', 'legacy_id',
    ];

    protected function casts(): array
    {
        return [
            'tax_rate' => 'float',
        ];
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function branches(): HasMany
    {
        return $this->hasMany(Branch::class);
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function toApiArray(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'address' => $this->address,
            'phone' => $this->phone,
            'email' => $this->email,
            'tax_rate' => (float) $this->tax_rate,
            'currency' => $this->currency,
            'tin' => $this->tin,
            'vrn' => $this->vrn,
            'mobile' => $this->mobile,
            'location' => $this->location,
            'tax_office' => $this->tax_office,
            'serial_prefix' => $this->serial_prefix,
            'status' => $this->status,
            'branches_count' => $this->branches()->count(),
            'staff_count' => $this->users()->count(),
        ];
    }
}
