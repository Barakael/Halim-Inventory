<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    public function index(Request $request)
    {
        $shopId = $request->user()->shop_id;
        $query = Customer::forShop($shopId)->where('is_active', true);

        if ($request->filled('search')) {
            $s = '%'.$request->search.'%';
            $query->where(function ($q) use ($s) {
                $q->where('name', 'like', $s)
                    ->orWhere('phone', 'like', $s)
                    ->orWhere('email', 'like', $s);
            });
        }

        if ($request->boolean('top_customers')) {
            $query->orderByDesc('total_spent')->limit(20);
        } else {
            $query->orderBy('name');
        }

        return response()->json([
            'data' => $query->with('debts')->get()->map->toApiArray(),
        ]);
    }

    public function show(Request $request, string $id)
    {
        $customer = Customer::forShop($request->user()->shop_id)
            ->with('debts')
            ->where(function ($q) use ($id) {
                $q->where('id', $id)->orWhere('legacy_id', $id);
            })
            ->firstOrFail();

        return response()->json($customer->toApiArray());
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'phone' => 'nullable|string|max:50',
            'email' => 'nullable|email|max:255',
            'address' => 'nullable|string|max:500',
            'discount_percent' => 'nullable|numeric|min:0|max:100',
            'loyalty_tier' => 'nullable|string|max:50',
            'notes' => 'nullable|string',
        ]);

        $customer = Customer::create([
            ...$data,
            'shop_id' => $request->user()->shop_id,
            'is_active' => true,
        ]);

        return response()->json($customer->toApiArray(), 201);
    }

    public function update(Request $request, string $id)
    {
        $customer = Customer::forShop($request->user()->shop_id)
            ->where(function ($q) use ($id) {
                $q->where('id', $id)->orWhere('legacy_id', $id);
            })
            ->firstOrFail();

        $data = $request->validate([
            'name' => 'sometimes|string|max:255',
            'phone' => 'nullable|string|max:50',
            'email' => 'nullable|email|max:255',
            'address' => 'nullable|string|max:500',
            'discount_percent' => 'nullable|numeric|min:0|max:100',
            'loyalty_tier' => 'nullable|string|max:50',
            'notes' => 'nullable|string',
            'is_active' => 'sometimes|boolean',
        ]);

        $customer->update($data);

        return response()->json($customer->fresh()->load('debts')->toApiArray());
    }

    public function destroy(Request $request, string $id)
    {
        $customer = Customer::forShop($request->user()->shop_id)
            ->where(function ($q) use ($id) {
                $q->where('id', $id)->orWhere('legacy_id', $id);
            })
            ->firstOrFail();

        $customer->is_active = false;
        $customer->save();

        return response()->json(['message' => 'Deleted']);
    }

    public function refreshLoyalty(Request $request, string $id)
    {
        $customer = Customer::forShop($request->user()->shop_id)
            ->where(function ($q) use ($id) {
                $q->where('id', $id)->orWhere('legacy_id', $id);
            })
            ->firstOrFail();

        // Stub: return current customer; loyalty rules can be added later.
        return response()->json($customer->load('debts')->toApiArray());
    }
}
