<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Supplier;
use Illuminate\Http\Request;

class SupplierController extends Controller
{
    public function index(Request $request)
    {
        $query = Supplier::forShop($request->user()->shop_id)->orderBy('name');

        if ($request->filled('search')) {
            $s = '%'.$request->search.'%';
            $query->where(function ($q) use ($s) {
                $q->where('name', 'like', $s)
                    ->orWhere('phone', 'like', $s)
                    ->orWhere('email', 'like', $s);
            });
        }

        return response()->json([
            'data' => $query->get()->map->toApiArray(),
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'phone' => 'nullable|string|max:50',
            'email' => 'nullable|string|max:255',
            'address' => 'nullable|string|max:500',
            'notes' => 'nullable|string',
        ]);

        $supplier = Supplier::create([
            ...$data,
            'shop_id' => $request->user()->shop_id,
        ]);

        return response()->json($supplier->toApiArray(), 201);
    }

    public function update(Request $request, string $id)
    {
        $supplier = Supplier::forShop($request->user()->shop_id)->where('id', $id)->firstOrFail();
        $data = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'phone' => 'nullable|string|max:50',
            'email' => 'nullable|string|max:255',
            'address' => 'nullable|string|max:500',
            'notes' => 'nullable|string',
        ]);
        $supplier->fill($data)->save();

        return response()->json($supplier->toApiArray());
    }

    public function destroy(Request $request, string $id)
    {
        $supplier = Supplier::forShop($request->user()->shop_id)->where('id', $id)->firstOrFail();
        $supplier->delete();

        return response()->json(['message' => 'Deleted']);
    }
}
