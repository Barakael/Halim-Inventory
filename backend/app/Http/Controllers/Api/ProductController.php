<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $shopId = $request->user()->shop_id;
        $query = Product::forShop($shopId)->with('category');

        if ($request->filled('barcode')) {
            $product = (clone $query)
                ->where(function ($q) use ($request) {
                    $q->where('barcode', $request->barcode)
                        ->orWhere('sku', $request->barcode);
                })
                ->first();

            return response()->json($product?->toApiArray());
        }

        $products = $query->orderBy('name')->get()->map->toApiArray();

        return response()->json(['data' => $products]);
    }

    public function show(Request $request, string $id)
    {
        return response()->json($this->findProduct($request, $id)->toApiArray());
    }

    public function store(Request $request)
    {
        $data = $this->validatedProduct($request);
        $shopId = $request->user()->shop_id;
        $categoryId = $this->resolveCategoryId($shopId, $data);

        $product = Product::create([
            'shop_id' => $shopId,
            'category_id' => $categoryId,
            'name' => $data['name'],
            'description' => $data['description'] ?? null,
            'price' => $data['price'] ?? 0,
            'cost_price' => $data['cost_price'] ?? $data['cost'] ?? 0,
            'barcode' => $data['barcode'] ?? null,
            'sku' => $data['sku'] ?? $data['barcode'] ?? null,
            'unit' => $data['unit'] ?? 'pcs',
            'stock' => (int) ($data['stock'] ?? 0),
            'low_stock_threshold' => (int) ($data['low_stock_threshold'] ?? $data['lowStockThreshold'] ?? 10),
            'status' => $data['status'] ?? 'active',
        ]);

        return response()->json($product->load('category')->toApiArray(), 201);
    }

    public function update(Request $request, string $id)
    {
        $product = $this->findProduct($request, $id);
        $data = $this->validatedProduct($request, updating: true);
        $shopId = $request->user()->shop_id;

        if (array_key_exists('category', $data) || array_key_exists('category_id', $data)) {
            $product->category_id = $this->resolveCategoryId($shopId, $data);
        }

        foreach ([
            'name', 'description', 'price', 'barcode', 'sku', 'unit', 'status',
        ] as $field) {
            if (array_key_exists($field, $data)) {
                $product->{$field} = $data[$field];
            }
        }

        if (array_key_exists('cost_price', $data) || array_key_exists('cost', $data)) {
            $product->cost_price = $data['cost_price'] ?? $data['cost'];
        }
        if (array_key_exists('stock', $data)) {
            $product->stock = (int) $data['stock'];
        }
        if (array_key_exists('low_stock_threshold', $data) || array_key_exists('lowStockThreshold', $data)) {
            $product->low_stock_threshold = (int) ($data['low_stock_threshold'] ?? $data['lowStockThreshold']);
        }

        $product->save();

        return response()->json($product->load('category')->toApiArray());
    }

    public function destroy(Request $request, string $id)
    {
        $product = $this->findProduct($request, $id);
        $product->delete();

        return response()->json(['message' => 'Deleted']);
    }

    public function uploadImage(Request $request, string $id)
    {
        $product = $this->findProduct($request, $id);
        $request->validate([
            'image' => 'required|image|max:5120',
        ]);

        $path = $request->file('image')->store('products/'.$request->user()->shop_id, 'public');
        $url = Storage::disk('public')->url($path);
        $product->image_url = $url;
        $product->save();

        return response()->json($product->load('category')->toApiArray());
    }

    private function findProduct(Request $request, string $id): Product
    {
        return Product::forShop($request->user()->shop_id)
            ->with('category')
            ->where(function ($q) use ($id) {
                $q->where('id', $id)->orWhere('legacy_id', $id);
            })
            ->firstOrFail();
    }

    private function validatedProduct(Request $request, bool $updating = false): array
    {
        return $request->validate([
            'name' => ($updating ? 'sometimes|' : '').'required|string|max:255',
            'description' => 'nullable|string',
            'price' => 'nullable|numeric|min:0',
            'cost_price' => 'nullable|numeric|min:0',
            'cost' => 'nullable|numeric|min:0',
            'barcode' => 'nullable|string|max:100',
            'sku' => 'nullable|string|max:100',
            'unit' => 'nullable|string|max:50',
            'stock' => 'nullable|integer|min:0',
            'low_stock_threshold' => 'nullable|integer|min:0',
            'lowStockThreshold' => 'nullable|integer|min:0',
            'category' => 'nullable|string|max:255',
            'category_id' => 'nullable|integer',
            'status' => 'nullable|string|max:50',
        ]);
    }

    private function resolveCategoryId(int $shopId, array $data): ?int
    {
        if (! empty($data['category_id'])) {
            $cat = Category::where('shop_id', $shopId)->where('id', $data['category_id'])->first();

            return $cat?->id;
        }

        $name = trim((string) ($data['category'] ?? ''));
        if ($name === '') {
            return null;
        }

        $cat = Category::firstOrCreate(
            ['shop_id' => $shopId, 'name' => $name],
            ['parent_id' => null]
        );

        return $cat->id;
    }
}
