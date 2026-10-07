<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Product;
use Illuminate\Http\Request;

class CategoryController extends Controller
{
    public function index(Request $request)
    {
        $shopId = $request->user()->shop_id;

        $categories = Category::query()
            ->where('shop_id', $shopId)
            ->orderBy('name')
            ->get()
            ->map(fn (Category $c) => $c->toApiArray())
            ->values();

        return response()->json(['data' => $categories]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'parent_id' => 'nullable|integer',
        ]);

        $shopId = $request->user()->shop_id;
        $parentId = null;
        if (! empty($data['parent_id'])) {
            $parent = Category::where('shop_id', $shopId)->where('id', $data['parent_id'])->first();
            $parentId = $parent?->id;
        }

        $cat = Category::create([
            'shop_id' => $shopId,
            'name' => $data['name'],
            'parent_id' => $parentId,
        ]);

        return response()->json($cat->toApiArray(), 201);
    }

    public function destroy(Request $request, string $id)
    {
        $shopId = $request->user()->shop_id;
        $cat = Category::where('shop_id', $shopId)->where('id', $id)->firstOrFail();

        if (Product::forShop($shopId)->where('category_id', $cat->id)->exists()) {
            return response()->json([
                'message' => 'Cannot delete category while products still use it.',
            ], 422);
        }

        if (Category::where('shop_id', $shopId)->where('parent_id', $cat->id)->exists()) {
            return response()->json([
                'message' => 'Delete subcategories first.',
            ], 422);
        }

        $cat->delete();

        return response()->json(['message' => 'Deleted']);
    }
}
