<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\StockMovement;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class StockController extends Controller
{
    public function index(Request $request)
    {
        $products = Product::forShop($request->user()->shop_id)
            ->orderBy('name')
            ->get();

        $data = $products->map(fn (Product $p) => [
            'id' => $p->id,
            'productId' => $p->id,
            'product_id' => $p->id,
            'productName' => $p->name,
            'product_name' => $p->name,
            'quantity' => (int) $p->stock,
            'type' => 'in',
            'unit' => $p->unit,
            'minStock' => (int) $p->low_stock_threshold,
            'costPrice' => (float) $p->cost_price,
            'barcode' => $p->barcode,
        ]);

        return response()->json(['data' => $data]);
    }

    public function stockIn(Request $request)
    {
        $data = $request->validate([
            'product_id' => 'required',
            'quantity' => 'required|integer|min:1',
            'cost_price' => 'nullable|numeric|min:0',
            'notes' => 'nullable|string',
            'batch_number' => 'nullable|string|max:100',
            'expiry_date' => 'nullable|date',
        ]);

        $user = $request->user();
        $shopId = $user->shop_id;

        $product = DB::transaction(function () use ($data, $user, $shopId) {
            $product = Product::forShop($shopId)
                ->where(function ($q) use ($data) {
                    $q->where('id', $data['product_id'])
                        ->orWhere('legacy_id', (string) $data['product_id']);
                })
                ->lockForUpdate()
                ->firstOrFail();

            $qty = (int) $data['quantity'];
            $product->increment('stock', $qty);
            if (isset($data['cost_price'])) {
                $product->cost_price = $data['cost_price'];
                $product->save();
            }

            StockMovement::create([
                'shop_id' => $shopId,
                'product_id' => $product->id,
                'branch_id' => $user->branch_id,
                'quantity' => $qty,
                'type' => 'in',
                'cost_price' => $data['cost_price'] ?? $product->cost_price,
                'batch_number' => $data['batch_number'] ?? null,
                'expiry_date' => $data['expiry_date'] ?? null,
                'notes' => $data['notes'] ?? 'Stock in',
                'created_by' => $user->id,
            ]);

            return $product->fresh();
        });

        return response()->json([
            'data' => [
                'product_id' => $product->id,
                'quantity' => (int) $product->stock,
                'product' => $product->toApiArray(),
            ],
        ], 201);
    }

    public function adjust(Request $request)
    {
        $data = $request->validate([
            'product_id' => 'required',
            'quantity' => 'required|integer',
            'notes' => 'nullable|string',
        ]);

        $user = $request->user();
        $shopId = $user->shop_id;

        $product = DB::transaction(function () use ($data, $user, $shopId) {
            $product = Product::forShop($shopId)
                ->where(function ($q) use ($data) {
                    $q->where('id', $data['product_id'])
                        ->orWhere('legacy_id', (string) $data['product_id']);
                })
                ->lockForUpdate()
                ->firstOrFail();

            $newQty = max(0, (int) $data['quantity']);
            $delta = $newQty - (int) $product->stock;
            $product->stock = $newQty;
            $product->save();

            if ($delta !== 0) {
                StockMovement::create([
                    'shop_id' => $shopId,
                    'product_id' => $product->id,
                    'branch_id' => $user->branch_id,
                    'quantity' => $delta,
                    'type' => 'adjustment',
                    'cost_price' => $product->cost_price,
                    'notes' => $data['notes'] ?? 'Stock adjust',
                    'created_by' => $user->id,
                ]);
            }

            return $product->fresh();
        });

        return response()->json([
            'data' => [
                'product_id' => $product->id,
                'quantity' => (int) $product->stock,
                'product' => $product->toApiArray(),
            ],
        ]);
    }
}
