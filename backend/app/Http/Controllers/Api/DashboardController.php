<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Purchase;
use App\Models\PurchasePayment;
use App\Models\Sale;
use App\Models\Supplier;
use App\Support\ShopRole;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $shopId = $user->shop_id;
        $today = Carbon::today();
        $cashierId = strtolower(trim((string) $user->role)) === 'cashier'
            ? $user->id
            : null;

        $salesQuery = function () use ($shopId, $cashierId) {
            $q = Sale::forShop($shopId);
            if ($cashierId !== null) {
                $q->where('cashier_id', $cashierId);
            }

            return $q;
        };

        $todaySales = $salesQuery()
            ->whereDate('created_at', $today)
            ->get(['total']);

        $products = Product::forShop($shopId)->get(['stock', 'low_stock_threshold']);
        $lowStock = $products->filter(fn ($p) => (int) $p->stock <= (int) $p->low_stock_threshold)->count();

        $weekly = [];
        for ($i = 6; $i >= 0; $i--) {
            $day = Carbon::today()->subDays($i);
            $row = $salesQuery()
                ->whereDate('created_at', $day)
                ->selectRaw('COUNT(*) as transactions, COALESCE(SUM(total),0) as total')
                ->first();
            $weekly[] = [
                'date' => $day->format('Y-m-d'),
                'transactions' => (int) ($row->transactions ?? 0),
                'total' => (float) ($row->total ?? 0),
            ];
        }

        return response()->json([
            'today_transactions' => $todaySales->count(),
            'today_total' => round((float) $todaySales->sum('total'), 2),
            'total_products' => $products->count(),
            'low_stock_count' => $lowStock,
            'weekly_sales' => $weekly,
        ]);
    }

    public function superAdmin(Request $request)
    {
        $user = $request->user();
        if (! ShopRole::isSuperAdmin($user->role)) {
            return response()->json(['message' => 'Super admin only.'], 403);
        }

        $shopId = $user->shop_id;
        $today = Carbon::today();

        $todaySales = Sale::forShop($shopId)
            ->whereDate('created_at', $today)
            ->get(['payment_method', 'total']);

        $paymentSplit = [];
        foreach ($todaySales as $sale) {
            $method = strtolower(trim((string) ($sale->payment_method ?: 'cash')));
            if ($method === '') {
                $method = 'cash';
            }
            $paymentSplit[$method] = round(($paymentSplit[$method] ?? 0) + (float) $sale->total, 2);
        }

        $purchaseAgg = Purchase::forShop($shopId)
            ->where('status', '!=', 'cancelled')
            ->whereNotNull('supplier_id')
            ->select(
                'supplier_id',
                DB::raw('COUNT(*) as purchases_count'),
                DB::raw('COALESCE(SUM(subtotal),0) as purchases_total')
            )
            ->groupBy('supplier_id')
            ->get()
            ->keyBy('supplier_id');

        $todayPurchaseAgg = Purchase::forShop($shopId)
            ->where('status', '!=', 'cancelled')
            ->whereNotNull('supplier_id')
            ->whereDate('purchased_at', $today)
            ->select(
                'supplier_id',
                DB::raw('COUNT(*) as purchases_count'),
                DB::raw('COALESCE(SUM(subtotal),0) as purchases_total')
            )
            ->groupBy('supplier_id')
            ->get()
            ->keyBy('supplier_id');

        $paymentAgg = PurchasePayment::forShop($shopId)
            ->whereNotNull('supplier_id')
            ->select(
                'supplier_id',
                DB::raw('COALESCE(SUM(amount),0) as payments_total')
            )
            ->groupBy('supplier_id')
            ->get()
            ->keyBy('supplier_id');

        $suppliers = Supplier::forShop($shopId)->orderBy('name')->get()->map(function (Supplier $s) use ($purchaseAgg, $todayPurchaseAgg, $paymentAgg) {
            $p = $purchaseAgg->get($s->id);
            $todayP = $todayPurchaseAgg->get($s->id);
            $pay = $paymentAgg->get($s->id);
            $brought = (float) ($p->purchases_total ?? 0);
            $paid = (float) ($pay->payments_total ?? 0);

            return [
                'id' => $s->id,
                'name' => $s->name,
                'phone' => $s->phone,
                'purchases_count' => (int) ($p->purchases_count ?? 0),
                'today_purchases_count' => (int) ($todayP->purchases_count ?? 0),
                'today_purchases_total' => round((float) ($todayP->purchases_total ?? 0), 2),
                'brought_in' => round($brought, 2),
                'paid' => round($paid, 2),
                'open_debt' => max(0, round($brought - $paid, 2)),
            ];
        })->values();

        $supplierDebts = $suppliers
            ->filter(fn (array $row) => $row['open_debt'] > 0)
            ->sortByDesc('open_debt')
            ->values();

        $salesDebts = Customer::forShop($shopId)
            ->where('open_debt_balance', '>', 0)
            ->orderByDesc('open_debt_balance')
            ->limit(50)
            ->get()
            ->map(fn (Customer $c) => [
                'id' => $c->id,
                'name' => $c->name,
                'phone' => $c->phone,
                'open_debt' => round((float) $c->open_debt_balance, 2),
            ])
            ->values();

        return response()->json([
            'data' => [
                'sales_today' => [
                    'count' => $todaySales->count(),
                    'total' => round((float) $todaySales->sum('total'), 2),
                    'payment_split' => $paymentSplit,
                ],
                'suppliers' => $suppliers,
                'supplier_debts' => $supplierDebts,
                'sales_debts' => $salesDebts,
                'sales_debt_total' => round((float) $salesDebts->sum('open_debt'), 2),
                'supplier_debt_total' => round((float) $supplierDebts->sum('open_debt'), 2),
                'statements' => [
                    'title' => 'Supplier statements',
                    'description' => 'Each supplier statement is the buying record. A delivery line shows who brought the goods, their phone, which products, the quantity, and the total. A payment line shows what was paid and when. The running balance is the deni.',
                ],
            ],
        ]);
    }
}
