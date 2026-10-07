<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\StockMovement;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SaleController extends Controller
{
    public function index(Request $request)
    {
        $query = Sale::forShop($request->user()->shop_id)
            ->with(['items', 'shop', 'cashier'])
            ->orderByDesc('created_at');

        if ($request->filled('date')) {
            $query->whereDate('created_at', $request->date);
        }
        if ($request->filled('from')) {
            $query->whereDate('created_at', '>=', $request->from);
        }
        if ($request->filled('to')) {
            $query->whereDate('created_at', '<=', $request->to);
        }

        $limit = min(500, max(1, (int) $request->input('per_page', 200)));

        return response()->json([
            'data' => $query->limit($limit)->get()->map->toApiArray(),
        ]);
    }

    public function show(Request $request, string $id)
    {
        $sale = Sale::forShop($request->user()->shop_id)
            ->with(['items', 'shop', 'cashier'])
            ->where(function ($q) use ($id) {
                $q->where('id', $id)->orWhere('legacy_id', $id);
            })
            ->firstOrFail();

        return response()->json($sale->toApiArray());
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required',
            'items.*.quantity' => 'required|integer|min:1',
            'items.*.price' => 'nullable|numeric|min:0',
            'subtotal' => 'nullable|numeric|min:0',
            'tax' => 'nullable|numeric|min:0',
            'discount' => 'nullable|numeric|min:0',
            'total' => 'nullable|numeric|min:0',
            'payment_method' => 'nullable|string|max:50',
            'amount_tendered' => 'nullable|numeric|min:0',
            'cashier_id' => 'nullable',
            'shop_customer_id' => 'nullable',
            'customer_name' => 'nullable|string|max:255',
            'customer_phone' => 'nullable|string|max:50',
            'customer_address' => 'nullable|string|max:500',
            'customer_id_type' => 'nullable|string|max:50',
            'customer_id' => 'nullable|string|max:100',
            'discount_mode' => 'nullable|string|max:50',
            'manual_discount_percent' => 'nullable|numeric',
            'manual_discount_amount' => 'nullable|numeric',
            'apply_loyalty_discount' => 'nullable|boolean',
            'client_sale_id' => 'nullable|string|max:100',
        ]);

        $user = $request->user();
        $shopId = $user->shop_id;

        $clientSaleId = $request->header('Idempotency-Key')
            ?: ($data['client_sale_id'] ?? null);
        if (is_string($clientSaleId)) {
            $clientSaleId = trim($clientSaleId);
            if ($clientSaleId === '') {
                $clientSaleId = null;
            }
        } else {
            $clientSaleId = null;
        }
        $data['client_sale_id'] = $clientSaleId;

        if ($clientSaleId) {
            $existing = Sale::forShop($shopId)
                ->where('client_sale_id', $clientSaleId)
                ->with(['items', 'shop', 'cashier'])
                ->first();
            if ($existing) {
                return response()->json($existing->toApiArray(), 200);
            }
        }

        try {
            $sale = DB::transaction(function () use ($data, $user, $shopId, $clientSaleId) {
                if ($clientSaleId) {
                    $existing = Sale::forShop($shopId)
                        ->where('client_sale_id', $clientSaleId)
                        ->lockForUpdate()
                        ->with(['items', 'shop', 'cashier'])
                        ->first();
                    if ($existing) {
                        return $existing;
                    }
                }

                $lineRows = [];
                $computedSubtotal = 0;

                foreach ($data['items'] as $item) {
                    $product = Product::forShop($shopId)
                        ->where(function ($q) use ($item) {
                            $q->where('id', $item['product_id'])
                                ->orWhere('legacy_id', (string) $item['product_id']);
                        })
                        ->lockForUpdate()
                        ->first();

                    if (! $product) {
                        abort(422, 'Product not found: '.$item['product_id']);
                    }

                    $qty = (int) $item['quantity'];
                    if ($product->stock < $qty) {
                        abort(422, "Insufficient stock for {$product->name}. Available: {$product->stock}");
                    }

                    $unitPrice = isset($item['price'])
                        ? (float) $item['price']
                        : (float) $product->price;
                    $lineTotal = $unitPrice * $qty;
                    $computedSubtotal += $lineTotal;

                    $lineRows[] = compact('product', 'qty', 'unitPrice', 'lineTotal');
                }

                $subtotal = isset($data['subtotal']) ? (float) $data['subtotal'] : $computedSubtotal;
                $tax = (float) ($data['tax'] ?? 0);
                $discount = (float) ($data['discount'] ?? 0);
                $total = isset($data['total']) ? (float) $data['total'] : max(0, $subtotal + $tax - $discount);
                $tendered = isset($data['amount_tendered']) ? (float) $data['amount_tendered'] : null;
                $change = $tendered !== null ? max(0, $tendered - $total) : null;

                $customerId = null;
                if (! empty($data['shop_customer_id'])) {
                    $customer = Customer::forShop($shopId)
                        ->where(function ($q) use ($data) {
                            $q->where('id', $data['shop_customer_id'])
                                ->orWhere('legacy_id', (string) $data['shop_customer_id']);
                        })
                        ->first();
                    $customerId = $customer?->id;
                }

                $serial = 'SN-'.now()->format('YmdHis').'-'.random_int(100, 999);

                $sale = Sale::create([
                    'shop_id' => $shopId,
                    'cashier_id' => $user->id,
                    'customer_id' => $customerId,
                    'serial_number' => $serial,
                    'client_sale_id' => $clientSaleId,
                    'payment_method' => $data['payment_method'] ?? 'cash',
                    'subtotal' => $subtotal,
                    'tax' => $tax,
                    'discount' => $discount,
                    'total' => $total,
                    'amount_tendered' => $tendered,
                    'change_amount' => $change,
                    'customer_name' => $data['customer_name'] ?? null,
                    'customer_phone' => $data['customer_phone'] ?? null,
                    'customer_address' => $data['customer_address'] ?? null,
                    'customer_id_type' => $data['customer_id_type'] ?? null,
                    'customer_id_number' => $data['customer_id'] ?? null,
                    'discount_mode' => $data['discount_mode'] ?? null,
                    'manual_discount_percent' => $data['manual_discount_percent'] ?? null,
                    'manual_discount_amount' => $data['manual_discount_amount'] ?? null,
                    'apply_loyalty_discount' => (bool) ($data['apply_loyalty_discount'] ?? false),
                    'status' => 'completed',
                ]);

                foreach ($lineRows as $row) {
                    /** @var Product $product */
                    $product = $row['product'];
                    SaleItem::create([
                        'sale_id' => $sale->id,
                        'product_id' => $product->id,
                        'product_name' => $product->name,
                        'quantity' => $row['qty'],
                        'unit_price' => $row['unitPrice'],
                        'line_total' => $row['lineTotal'],
                    ]);

                    $product->decrement('stock', $row['qty']);

                    StockMovement::create([
                        'shop_id' => $shopId,
                        'product_id' => $product->id,
                        'branch_id' => $user->branch_id,
                        'quantity' => -$row['qty'],
                        'type' => 'out',
                        'cost_price' => $product->cost_price,
                        'notes' => 'POS sale '.$serial,
                        'created_by' => $user->id,
                    ]);
                }

                if ($customerId) {
                    $customer = Customer::where('id', $customerId)->lockForUpdate()->first();
                    if ($customer) {
                        $customer->purchase_count = (int) $customer->purchase_count + 1;
                        $customer->total_spent = (float) $customer->total_spent + $total;
                        $customer->save();
                    }
                }

                return $sale->load(['items', 'shop', 'cashier']);
            });
        } catch (\Illuminate\Database\UniqueConstraintViolationException $e) {
            if ($clientSaleId) {
                $existing = Sale::forShop($shopId)
                    ->where('client_sale_id', $clientSaleId)
                    ->with(['items', 'shop', 'cashier'])
                    ->first();
                if ($existing) {
                    return response()->json($existing->toApiArray(), 200);
                }
            }
            throw $e;
        }

        return response()->json($sale->toApiArray(), 201);
    }
}
