<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Purchase;
use App\Models\PurchasePayment;
use App\Services\PurchasePaymentService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class PurchasePaymentController extends Controller
{
    public function __construct(private PurchasePaymentService $payments) {}

    public function index(Request $request, string $id)
    {
        $purchase = Purchase::forShop($request->user()->shop_id)->where('id', $id)->firstOrFail();

        $rows = PurchasePayment::forShop($request->user()->shop_id)
            ->with('creator')
            ->where('purchase_id', $purchase->id)
            ->orderByDesc('paid_at')
            ->get()
            ->map->toApiArray();

        return response()->json([
            'data' => $rows,
            'purchase' => $purchase->load(['items', 'supplier'])->toApiArray(),
        ]);
    }

    public function store(Request $request, string $id)
    {
        $purchase = Purchase::forShop($request->user()->shop_id)
            ->with(['items', 'supplier'])
            ->where('id', $id)
            ->firstOrFail();

        if ($purchase->status === 'cancelled') {
            return response()->json(['message' => 'Cancelled purchases cannot accept payments.'], 422);
        }

        $data = $request->validate([
            'amount' => 'required|numeric|min:0.01',
            'paid_at' => 'nullable|date',
            'payment_method' => 'nullable|string|max:100',
            'reference' => 'nullable|string|max:255',
            'notes' => 'nullable|string',
            'receipt' => 'nullable|file|mimes:jpg,jpeg,png,webp,pdf|max:10240',
            'receipt_base64' => 'nullable|string',
            'receipt_filename' => 'nullable|string|max:255',
        ]);

        $remaining = $this->payments->remaining($purchase);
        $amount = round((float) $data['amount'], 2);
        if ($amount > $remaining + 0.009) {
            return response()->json([
                'message' => 'Amount exceeds remaining balance.',
                'remaining' => $remaining,
            ], 422);
        }

        $payment = DB::transaction(function () use ($request, $purchase, $data, $amount) {
            $path = null;
            if ($request->hasFile('receipt')) {
                $path = $request->file('receipt')->store(
                    'purchase-payments/'.$purchase->shop_id,
                    'public'
                );
            } elseif (! empty($data['receipt_base64'])) {
                $raw = $data['receipt_base64'];
                if (str_contains($raw, ',')) {
                    $raw = explode(',', $raw, 2)[1];
                }
                $bytes = base64_decode($raw, true);
                if ($bytes !== false && strlen($bytes) > 0 && strlen($bytes) <= 10 * 1024 * 1024) {
                    $name = $data['receipt_filename'] ?? ('receipt-'.uniqid().'.jpg');
                    $name = basename(preg_replace('/[^a-zA-Z0-9._-]/', '_', $name));
                    $path = 'purchase-payments/'.$purchase->shop_id.'/'.$name;
                    Storage::disk('public')->put($path, $bytes);
                }
            }

            $payment = PurchasePayment::create([
                'shop_id' => $purchase->shop_id,
                'purchase_id' => $purchase->id,
                'supplier_id' => $purchase->supplier_id,
                'amount' => $amount,
                'paid_at' => $data['paid_at'] ?? now(),
                'payment_method' => $data['payment_method'] ?? 'cash',
                'reference' => $data['reference'] ?? null,
                'notes' => $data['notes'] ?? null,
                'receipt_path' => $path,
                'created_by' => $request->user()->id,
            ]);

            $this->payments->recalculate($purchase);

            return $payment->load('creator');
        });

        return response()->json([
            'data' => $payment->toApiArray(),
            'purchase' => $purchase->fresh(['items', 'supplier', 'creator', 'payments'])->toApiArray(),
        ], 201);
    }
}
