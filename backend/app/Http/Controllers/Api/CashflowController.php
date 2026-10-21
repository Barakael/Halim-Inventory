<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PurchasePayment;
use App\Models\Sale;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CashflowController extends Controller
{
    /**
     * Mapato (cash in from sales) vs Matumizi (purchase payments + optional expenses stub).
     */
    public function summary(Request $request)
    {
        $shopId = $request->user()->shop_id;
        [$from, $to] = $this->period($request);

        $sales = Sale::forShop($shopId)
            ->whereBetween('created_at', [$from, $to])
            ->get(['total', 'amount_tendered', 'payment_method', 'change_amount']);

        $mapato = 0.0;
        foreach ($sales as $sale) {
            $method = strtolower((string) ($sale->payment_method ?? ''));
            if ($method === 'credit' || str_contains($method, 'deni')) {
                // Credit sales: only count amount actually received (tendered)
                $mapato += max(0, (float) ($sale->amount_tendered ?? 0));
            } else {
                $received = $sale->amount_tendered !== null
                    ? (float) $sale->amount_tendered
                    : (float) $sale->total;
                $mapato += max(0, $received);
            }
        }

        // Debt collections are already reflected when amount_tendered / debt payments
        // hit sales; customer debt payments table may add more — include if present.
        if (DB::getSchemaBuilder()->hasTable('debt_payments')) {
            $debtCollections = (float) DB::table('debt_payments')
                ->join('customer_debts', 'customer_debts.id', '=', 'debt_payments.customer_debt_id')
                ->where('customer_debts.shop_id', $shopId)
                ->whereBetween('debt_payments.created_at', [$from, $to])
                ->sum('debt_payments.amount');
            $mapato += $debtCollections;
        }

        $purchaseOut = (float) PurchasePayment::forShop($shopId)
            ->whereBetween('paid_at', [$from, $to])
            ->sum('amount');

        $expenses = 0.0;
        if (DB::getSchemaBuilder()->hasTable('expenses')) {
            $expenses = (float) DB::table('expenses')
                ->where('shop_id', $shopId)
                ->whereBetween('expense_date', [$from->toDateString(), $to->toDateString()])
                ->sum('amount');
        }

        $matumizi = round($purchaseOut + $expenses, 2);
        $mapato = round($mapato, 2);

        return response()->json([
            'from' => $from->format('Y-m-d'),
            'to' => $to->format('Y-m-d'),
            'mapato' => $mapato,
            'matumizi' => $matumizi,
            'matumizi_breakdown' => [
                'purchase_payments' => round($purchaseOut, 2),
                'expenses' => round($expenses, 2),
            ],
            'net' => round($mapato - $matumizi, 2),
        ]);
    }

    /** @return array{0: Carbon, 1: Carbon} */
    private function period(Request $request): array
    {
        $to = $request->filled('to')
            ? Carbon::parse($request->input('to'))->endOfDay()
            : Carbon::today()->endOfDay();
        $from = $request->filled('from')
            ? Carbon::parse($request->input('from'))->startOfDay()
            : Carbon::today()->startOfMonth()->startOfDay();

        return [$from, $to];
    }
}
