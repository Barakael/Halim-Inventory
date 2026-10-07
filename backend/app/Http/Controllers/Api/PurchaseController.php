<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Purchase;
use App\Models\PurchaseItem;
use App\Models\StockMovement;
use App\Models\Supplier;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PurchaseController extends Controller
{
    public function index(Request $request)
    {
        $query = Purchase::forShop($request->user()->shop_id)
            ->with(['items', 'supplier', 'creator'])
            ->orderByDesc('created_at');

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }
        if ($request->filled('supplier_id')) {
            $query->where('supplier_id', $request->supplier_id);
        }
        if ($request->filled('search')) {
            $s = '%'.$request->search.'%';
            $query->where(function ($q) use ($s) {
                $q->where('reference', 'like', $s)->orWhere('notes', 'like', $s);
            });
        }
        if ($request->filled('from')) {
            $query->whereDate('purchased_at', '>=', $request->from);
        }
        if ($request->filled('to')) {
            $query->whereDate('purchased_at', '<=', $request->to);
        }

        return response()->json([
            'data' => $query->limit(200)->get()->map->toApiArray(),
        ]);
    }

    public function show(Request $request, string $id)
    {
        $purchase = Purchase::forShop($request->user()->shop_id)
            ->with(['items', 'supplier', 'creator'])
            ->where('id', $id)
            ->firstOrFail();

        return response()->json($purchase->toApiArray());
    }

    public function store(Request $request)
    {
        $data = $this->validated($request);
        $user = $request->user();
        $shopId = $user->shop_id;

        $purchase = DB::transaction(function () use ($data, $user, $shopId) {
            $supplierId = $this->resolveSupplierId($shopId, $data['supplier_id'] ?? null);
            [$subtotal, $lines] = $this->buildLines($shopId, $data['items']);

            $purchase = Purchase::create([
                'shop_id' => $shopId,
                'supplier_id' => $supplierId,
                'created_by' => $user->id,
                'status' => ! empty($data['receive_now']) ? 'received' : 'draft',
                'reference' => $data['reference'] ?? null,
                'notes' => $data['notes'] ?? null,
                'subtotal' => $subtotal,
                'purchased_at' => $data['purchased_at'] ?? now()->toDateString(),
                'received_at' => ! empty($data['receive_now']) ? now() : null,
            ]);

            foreach ($lines as $line) {
                PurchaseItem::create([
                    'purchase_id' => $purchase->id,
                    ...$line,
                ]);
            }

            if ($purchase->status === 'received') {
                $this->applyStockIn($purchase->fresh(['items']), $user);
            }

            return $purchase->load(['items', 'supplier', 'creator']);
        });

        return response()->json($purchase->toApiArray(), 201);
    }

    public function update(Request $request, string $id)
    {
        $purchase = Purchase::forShop($request->user()->shop_id)
            ->with('items')
            ->where('id', $id)
            ->firstOrFail();

        if ($purchase->status !== 'draft') {
            return response()->json(['message' => 'Only draft purchases can be edited.'], 422);
        }

        $data = $this->validated($request, updating: true);
        $shopId = $request->user()->shop_id;

        $purchase = DB::transaction(function () use ($purchase, $data, $shopId, $request) {
            if (array_key_exists('supplier_id', $data)) {
                $purchase->supplier_id = $this->resolveSupplierId($shopId, $data['supplier_id']);
            }
            if (array_key_exists('reference', $data)) {
                $purchase->reference = $data['reference'];
            }
            if (array_key_exists('notes', $data)) {
                $purchase->notes = $data['notes'];
            }
            if (array_key_exists('purchased_at', $data)) {
                $purchase->purchased_at = $data['purchased_at'];
            }

            if (! empty($data['items'])) {
                $purchase->items()->delete();
                [$subtotal, $lines] = $this->buildLines($shopId, $data['items']);
                $purchase->subtotal = $subtotal;
                foreach ($lines as $line) {
                    PurchaseItem::create(['purchase_id' => $purchase->id, ...$line]);
                }
            }

            if (! empty($data['receive_now'])) {
                $purchase->status = 'received';
                $purchase->received_at = now();
                $purchase->save();
                $this->applyStockIn($purchase->fresh(['items']), $request->user());
            } else {
                $purchase->save();
            }

            return $purchase->load(['items', 'supplier', 'creator']);
        });

        return response()->json($purchase->toApiArray());
    }

    public function receive(Request $request, string $id)
    {
        $purchase = Purchase::forShop($request->user()->shop_id)
            ->with('items')
            ->where('id', $id)
            ->firstOrFail();

        if ($purchase->status !== 'draft') {
            return response()->json(['message' => 'Only draft purchases can be received.'], 422);
        }

        DB::transaction(function () use ($purchase, $request) {
            $purchase->status = 'received';
            $purchase->received_at = now();
            $purchase->save();
            $this->applyStockIn($purchase, $request->user());
        });

        return response()->json($purchase->fresh(['items', 'supplier', 'creator'])->toApiArray());
    }

    public function cancel(Request $request, string $id)
    {
        $purchase = Purchase::forShop($request->user()->shop_id)->where('id', $id)->firstOrFail();

        if ($purchase->status === 'received') {
            return response()->json(['message' => 'Received purchases cannot be cancelled.'], 422);
        }

        $purchase->status = 'cancelled';
        $purchase->save();

        return response()->json($purchase->load(['items', 'supplier', 'creator'])->toApiArray());
    }

    private function validated(Request $request, bool $updating = false): array
    {
        return $request->validate([
            'supplier_id' => 'nullable',
            'reference' => 'nullable|string|max:255',
            'notes' => 'nullable|string',
            'purchased_at' => 'nullable|date',
            'receive_now' => 'nullable|boolean',
            'items' => ($updating ? 'sometimes|' : '').'required|array|min:1',
            'items.*.product_id' => 'required',
            'items.*.quantity' => 'required|integer|min:1',
            'items.*.unit_cost' => 'nullable|numeric|min:0',
        ]);
    }

    private function resolveSupplierId(int $shopId, mixed $id): ?int
    {
        if ($id === null || $id === '') {
            return null;
        }

        return Supplier::forShop($shopId)->where('id', $id)->value('id');
    }

    /** @return array{0: float, 1: list<array>} */
    private function buildLines(int $shopId, array $items): array
    {
        $subtotal = 0.0;
        $lines = [];

        foreach ($items as $item) {
            $product = Product::forShop($shopId)
                ->where(function ($q) use ($item) {
                    $q->where('id', $item['product_id'])
                        ->orWhere('legacy_id', (string) $item['product_id']);
                })
                ->first();

            if (! $product) {
                abort(422, 'Product not found: '.$item['product_id']);
            }

            $qty = (int) $item['quantity'];
            $unitCost = isset($item['unit_cost']) ? (float) $item['unit_cost'] : (float) $product->cost_price;
            $lineTotal = $qty * $unitCost;
            $subtotal += $lineTotal;

            $lines[] = [
                'product_id' => $product->id,
                'product_name' => $product->name,
                'quantity' => $qty,
                'unit_cost' => $unitCost,
                'line_total' => $lineTotal,
            ];
        }

        return [$subtotal, $lines];
    }

    private function applyStockIn(Purchase $purchase, $user): void
    {
        foreach ($purchase->items as $item) {
            if (! $item->product_id) {
                continue;
            }
            $product = Product::forShop($purchase->shop_id)->where('id', $item->product_id)->lockForUpdate()->first();
            if (! $product) {
                continue;
            }
            $product->increment('stock', $item->quantity);
            if ($item->unit_cost > 0) {
                $product->cost_price = $item->unit_cost;
                $product->save();
            }

            StockMovement::create([
                'shop_id' => $purchase->shop_id,
                'product_id' => $product->id,
                'branch_id' => $user->branch_id,
                'quantity' => $item->quantity,
                'type' => 'in',
                'cost_price' => $item->unit_cost,
                'notes' => 'Purchase #'.$purchase->id.($purchase->reference ? ' '.$purchase->reference : ''),
                'created_by' => $user->id,
            ]);
        }
    }
}
