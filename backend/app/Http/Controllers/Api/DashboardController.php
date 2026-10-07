<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Sale;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function index(Request $request)
    {
        $shopId = $request->user()->shop_id;
        $today = Carbon::today();

        $todaySales = Sale::forShop($shopId)
            ->whereDate('created_at', $today)
            ->get(['total']);

        $products = Product::forShop($shopId)->get(['stock', 'low_stock_threshold']);
        $lowStock = $products->filter(fn ($p) => (int) $p->stock <= (int) $p->low_stock_threshold)->count();

        $weekly = [];
        for ($i = 6; $i >= 0; $i--) {
            $day = Carbon::today()->subDays($i);
            $row = Sale::forShop($shopId)
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
}
