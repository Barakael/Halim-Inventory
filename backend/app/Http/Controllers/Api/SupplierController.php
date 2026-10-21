<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Purchase;
use App\Models\PurchasePayment;
use App\Models\Supplier;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SupplierController extends Controller
{
    public function index(Request $request)
    {
        $shopId = $request->user()->shop_id;
        $query = Supplier::forShop($shopId)->orderBy('name');

        if ($request->filled('search')) {
            $s = '%'.$request->search.'%';
            $query->where(function ($q) use ($s) {
                $q->where('name', 'like', $s)
                    ->orWhere('phone', 'like', $s)
                    ->orWhere('email', 'like', $s)
                    ->orWhere('notes', 'like', $s)
                    ->orWhere('address', 'like', $s);
            });
        }

        $suppliers = $query->get();

        $purchaseAgg = Purchase::forShop($shopId)
            ->where('status', '!=', 'cancelled')
            ->whereNotNull('supplier_id')
            ->select(
                'supplier_id',
                DB::raw('COUNT(*) as purchases_count'),
                DB::raw('COALESCE(SUM(subtotal),0) as purchases_total'),
                DB::raw('MAX(purchased_at) as last_purchased_at')
            )
            ->groupBy('supplier_id')
            ->get()
            ->keyBy('supplier_id');

        $paymentAgg = PurchasePayment::forShop($shopId)
            ->whereNotNull('supplier_id')
            ->select(
                'supplier_id',
                DB::raw('COALESCE(SUM(amount),0) as payments_total'),
                DB::raw('MAX(paid_at) as last_paid_at')
            )
            ->groupBy('supplier_id')
            ->get()
            ->keyBy('supplier_id');

        $data = $suppliers->map(function (Supplier $s) use ($purchaseAgg, $paymentAgg) {
            $p = $purchaseAgg->get($s->id);
            $pay = $paymentAgg->get($s->id);
            $jumla = (float) ($p->purchases_total ?? 0);
            $paid = (float) ($pay->payments_total ?? 0);
            $deni = max(0, round($jumla - $paid, 2));
            $base = $s->toApiArray();

            return array_merge($base, [
                'purchases_count' => (int) ($p->purchases_count ?? 0),
                'purchases_total' => round($jumla, 2),
                'payments_total' => round($paid, 2),
                'open_debt' => $deni,
                'last_purchased_at' => $p->last_purchased_at ?? null,
                'last_paid_at' => $pay->last_paid_at ?? null,
                'maelezo' => $s->address ?: $s->notes,
            ]);
        });

        return response()->json(['data' => $data]);
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
