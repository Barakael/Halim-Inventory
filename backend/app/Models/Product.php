<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Product extends Model
{
    protected $fillable = [
        'shop_id', 'category_id', 'name', 'description', 'price', 'cost_price',
        'barcode', 'sku', 'unit', 'stock', 'low_stock_threshold', 'image_url',
        'status', 'legacy_id',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'float',
            'cost_price' => 'float',
            'stock' => 'integer',
            'low_stock_threshold' => 'integer',
        ];
    }

    public function shop(): BelongsTo
    {
        return $this->belongsTo(Shop::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function scopeForShop(Builder $query, int $shopId): Builder
    {
        return $query->where('shop_id', $shopId);
    }

    public function toApiArray(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'description' => $this->description,
            'price' => (float) $this->price,
            'cost_price' => (float) $this->cost_price,
            'barcode' => $this->barcode,
            'sku' => $this->sku,
            'stock' => (int) $this->stock,
            'low_stock_threshold' => (int) $this->low_stock_threshold,
            'category' => $this->category?->name,
            'category_id' => $this->category_id,
            'shop_id' => $this->shop_id,
            'unit' => $this->unit,
            'image_url' => $this->image_url,
            'image' => $this->image_url,
            'status' => $this->status,
        ];
    }
}
