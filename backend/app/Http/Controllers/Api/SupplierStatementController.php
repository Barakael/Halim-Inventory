<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Purchase;
use App\Models\PurchasePayment;
use App\Models\Shop;
use App\Models\Supplier;
use Carbon\Carbon;
use Illuminate\Http\Request;

class SupplierStatementController extends Controller
{
    public function show(Request $request, string $id)
    {
        $payload = $this->buildStatement($request, $id);

        return response()->json($payload);
    }

    public function pdf(Request $request, string $id)
    {
        $payload = $this->buildStatement($request, $id);

        return response()
            ->view('statements.supplier', $payload)
            ->header('Content-Type', 'text/html; charset=UTF-8');
    }

    private function buildStatement(Request $request, string $id): array
    {
        $shopId = $request->user()->shop_id;
        $supplier = Supplier::forShop($shopId)->where('id', $id)->firstOrFail();
        $shop = Shop::find($shopId);

        [$from, $to, $preset] = $this->resolvePeriod($request);

        $purchases = Purchase::forShop($shopId)
            ->with('items')
            ->where('supplier_id', $supplier->id)
            ->where('status', '!=', 'cancelled')
            ->whereDate('purchased_at', '<=', $to)
            ->orderBy('purchased_at')
            ->orderBy('id')
            ->get();

        $payments = PurchasePayment::forShop($shopId)
            ->where('supplier_id', $supplier->id)
            ->whereDate('paid_at', '<=', $to)
            ->orderBy('paid_at')
            ->orderBy('id')
            ->get();

        // Opening balance = deliveries before from − payments before from
        $openingDebit = $purchases
            ->filter(fn ($p) => $p->purchased_at && $p->purchased_at->lt($from))
            ->sum(fn ($p) => (float) $p->subtotal);
        $openingCredit = $payments
            ->filter(fn ($p) => $p->paid_at && $p->paid_at->lt($from))
            ->sum(fn ($p) => (float) $p->amount);
        $openingBalance = round($openingDebit - $openingCredit, 2);

        $periodPurchases = $purchases->filter(
            fn ($p) => $p->purchased_at
                && ! $p->purchased_at->lt($from)
                && ! $p->purchased_at->gt($to)
        );
        $periodPayments = $payments->filter(
            fn ($p) => $p->paid_at
                && ! $p->paid_at->copy()->startOfDay()->lt($from)
                && ! $p->paid_at->copy()->startOfDay()->gt($to)
        );

        $entries = [];
        foreach ($periodPurchases as $p) {
            $itemNames = $p->items->pluck('product_name')->filter()->values();
            $names = $itemNames->implode(', ');
            $qty = (int) $p->items->sum('quantity');
            $name = $p->delivered_by_name ?: null;
            $phone = $p->delivered_by_phone ?: null;
            $descParts = ['Manunuzi #'.$p->id];
            if ($p->reference) {
                $descParts[] = 'Ref '.$p->reference;
            }
            $entries[] = [
                'type' => 'delivery',
                'date' => optional($p->purchased_at)?->format('Y-m-d'),
                'sort_at' => optional($p->purchased_at)?->timestamp ?? 0,
                'description' => implode(' · ', $descParts),
                'delivered_by_name' => $name,
                'delivered_by_phone' => $phone,
                'delivered_by' => trim(($name ?? '').($phone ? ' / '.$phone : '')) ?: null,
                'products' => $names ?: null,
                'quantity' => $qty,
                'jumla' => (float) $p->subtotal,
                'malipo' => 0.0,
                'debit' => (float) $p->subtotal,
                'credit' => 0.0,
                'purchase_id' => $p->id,
                'payment_id' => null,
                'receipt_url' => null,
            ];
        }
        foreach ($periodPayments as $pay) {
            $descParts = ['Malipo'];
            if ($pay->payment_method) {
                $descParts[] = $pay->payment_method;
            }
            if ($pay->reference) {
                $descParts[] = 'Ref '.$pay->reference;
            }
            $entries[] = [
                'type' => 'payment',
                'date' => optional($pay->paid_at)?->format('Y-m-d'),
                'sort_at' => optional($pay->paid_at)?->timestamp ?? 0,
                'description' => implode(' · ', $descParts),
                'delivered_by_name' => null,
                'delivered_by_phone' => null,
                'delivered_by' => null,
                'products' => null,
                'quantity' => null,
                'jumla' => 0.0,
                'malipo' => (float) $pay->amount,
                'debit' => 0.0,
                'credit' => (float) $pay->amount,
                'purchase_id' => $pay->purchase_id,
                'payment_id' => $pay->id,
                'receipt_url' => $pay->receiptUrl(),
            ];
        }

        usort($entries, function ($a, $b) {
            if ($a['sort_at'] === $b['sort_at']) {
                return ($a['type'] === 'delivery' ? 0 : 1) <=> ($b['type'] === 'delivery' ? 0 : 1);
            }

            return $a['sort_at'] <=> $b['sort_at'];
        });

        $balance = $openingBalance;
        $rows = [];
        $totalDebit = 0.0;
        $totalCredit = 0.0;
        foreach ($entries as $e) {
            $balance = round($balance + $e['debit'] - $e['credit'], 2);
            $totalDebit += $e['debit'];
            $totalCredit += $e['credit'];
            $rows[] = [
                'type' => $e['type'],
                'date' => $e['date'],
                'description' => $e['description'],
                'delivered_by_name' => $e['delivered_by_name'],
                'delivered_by_phone' => $e['delivered_by_phone'],
                'delivered_by' => $e['delivered_by'],
                'products' => $e['products'],
                'quantity' => $e['quantity'],
                'jumla' => $e['jumla'],
                'malipo' => $e['malipo'],
                'debit' => $e['debit'],
                'credit' => $e['credit'],
                'balance' => $balance,
                'deni' => $balance,
                'purchase_id' => $e['purchase_id'],
                'payment_id' => $e['payment_id'],
                'receipt_url' => $e['receipt_url'],
            ];
        }

        return [
            'shop' => [
                'id' => $shop?->id,
                'name' => $shop?->name ?? 'Shop',
                'phone' => $shop?->phone ?? null,
                'address' => $shop?->address ?? null,
            ],
            'supplier' => $supplier->toApiArray(),
            'preset' => $preset,
            'from' => $from->format('Y-m-d'),
            'to' => $to->format('Y-m-d'),
            'printed_at' => now()->toISOString(),
            'opening_balance' => $openingBalance,
            'closing_balance' => $balance,
            'totals' => [
                'deliveries' => round($totalDebit, 2),
                'paid' => round($totalCredit, 2),
                'remaining' => round($balance, 2),
            ],
            'rows' => $rows,
        ];
    }

    /** @return array{0: Carbon, 1: Carbon, 2: string} */
    private function resolvePeriod(Request $request): array
    {
        $preset = $request->input('preset', 'month');
        $to = $request->filled('to')
            ? Carbon::parse($request->input('to'))->endOfDay()
            : Carbon::today()->endOfDay();

        if ($request->filled('from') && $request->filled('to')) {
            $from = Carbon::parse($request->input('from'))->startOfDay();
            $to = Carbon::parse($request->input('to'))->endOfDay();

            return [$from, $to, 'custom'];
        }

        $from = match ($preset) {
            'day', 'today' => Carbon::today()->startOfDay(),
            'week' => Carbon::today()->subDays(6)->startOfDay(),
            '3m' => Carbon::today()->subMonths(3)->startOfDay(),
            '6m' => Carbon::today()->subMonths(6)->startOfDay(),
            '12m' => Carbon::today()->subMonths(12)->startOfDay(),
            default => Carbon::today()->startOfMonth()->startOfDay(),
        };

        return [$from, $to, $preset];
    }
}
