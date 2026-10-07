<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'shop_id', 'branch_id', 'name', 'username', 'email', 'password', 'phone',
        'avatar_url', 'role', 'status', 'legacy_id', 'email_verified_at',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function shop(): BelongsTo
    {
        return $this->belongsTo(Shop::class);
    }

    public function branch(): BelongsTo
    {
        return $this->belongsTo(Branch::class);
    }

    public function toApiArray(): array
    {
        $parts = preg_split('/\s+/', trim($this->name), 2);

        return [
            'id' => $this->id,
            'name' => $this->name,
            'username' => $this->username,
            'first_name' => $parts[0] ?? '',
            'last_name' => $parts[1] ?? '',
            'email' => $this->email,
            'phone' => $this->phone,
            'avatar_url' => $this->avatar_url,
            'email_verified_at' => optional($this->email_verified_at)?->toISOString(),
            'role' => $this->role,
            'shop_id' => $this->shop_id,
            'branch_id' => $this->branch_id,
            'shop' => $this->relationLoaded('shop') && $this->shop
                ? $this->shop->toApiArray()
                : null,
        ];
    }
}
