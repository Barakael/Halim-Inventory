<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\CustomerDebt;
use App\Models\DebtPayment;
use App\Services\DebtPaymentService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class DebtController extends Controller
{
    public function __construct(private DebtPaymentService $payments) {}

    public function index(Request $request)
    {
        $query = CustomerDebt::forShop($request->user()->shop_id)
            ->with('customer')
            ->orderByDesc('created_at');

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }
        if ($request->filled('customer_id')) {
            $query->where('customer_id', $request->customer_id);
        }

        return response()->json([
            'data' => $query->limit(200)->get()->map->toApiArray(),
        ]);
    }

    public function summary(Request $request)
    {
        $shopId = $request->user()->shop_id;
        $open = CustomerDebt::forShop($shopId)->where('status', 'open')->get();

        $top = Customer::forShop($shopId)
            ->where('open_debt_balance', '>', 0)
            ->orderByDesc('open_debt_balance')
            ->limit(10)
            ->get()
            ->map->toApiArray();

        $collected = DebtPayment::query()
            ->whereHas('debt', fn ($q) => $q->where('shop_id', $shopId))
            ->sum('amount');

        return response()->json([
            'open_count' => $open->count(),
            'open_balance' => round($open->sum(fn (CustomerDebt $d) => $d->balance()), 2),
            'collected_total' => round((float) $collected, 2),
            'top_debtors' => $top,
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'customer_id' => 'nullable',
            'customer_name' => 'nullable|string|max:255',
            'customer_phone' => 'nullable|string|max:50',
            'amount' => 'required|numeric|min:0.01',
            'note' => 'nullable|string',
            'due_date' => 'nullable|date',
        ]);

        $shopId = $request->user()->shop_id;

        $debt = DB::transaction(function () use ($data, $shopId) {
            $customer = null;
            if (! empty($data['customer_id'])) {
                $customer = Customer::forShop($shopId)
                    ->where(function ($q) use ($data) {
                        $q->where('id', $data['customer_id'])
                            ->orWhere('legacy_id', (string) $data['customer_id']);
                    })
                    ->first();
            }

            if (! $customer && ! empty($data['customer_name'])) {
                $customer = Customer::create([
                    'shop_id' => $shopId,
                    'name' => $data['customer_name'],
                    'phone' => $data['customer_phone'] ?? null,
                    'is_active' => true,
                ]);
            }

            if (! $customer) {
                abort(422, 'Customer is required.');
            }

            $debt = CustomerDebt::create([
                'shop_id' => $shopId,
                'customer_id' => $customer->id,
                'amount' => $data['amount'],
                'amount_paid' => 0,
                'status' => 'open',
                'note' => $data['note'] ?? null,
                'due_date' => $data['due_date'] ?? null,
            ]);

            CustomerDebt::recomputeOpenBalance($customer);

            return $debt->load('customer');
        });

        return response()->json($debt->toApiArray(), 201);
    }

    public function payments(Request $request, string $id)
    {
        $debt = CustomerDebt::forShop($request->user()->shop_id)
            ->with('customer')
            ->where('id', $id)
            ->firstOrFail();

        $rows = DebtPayment::query()
            ->with('creator')
            ->where('customer_debt_id', $debt->id)
            ->orderByDesc('paid_at')
            ->orderByDesc('id')
            ->get()
            ->map->toApiArray();

        return response()->json([
            'data' => $rows,
            'debt' => $debt->toApiArray(),
        ]);
    }

    public function pay(Request $request, string $id)
    {
        $data = $request->validate([
            'amount' => 'required|numeric|min:0.01',
            'note' => 'nullable|string',
            'payment_method' => 'nullable|string|max:100',
            'reference' => 'nullable|string|max:255',
            'paid_at' => 'nullable|date',
            'receipt' => 'nullable|file|mimes:jpg,jpeg,png,webp,pdf|max:10240',
            'receipt_base64' => 'nullable|string',
            'receipt_filename' => 'nullable|string|max:255',
        ]);

        $debt = CustomerDebt::forShop($request->user()->shop_id)
            ->with('customer')
            ->where('id', $id)
            ->firstOrFail();

        if ($debt->status !== 'open') {
            return response()->json(['message' => 'Debt is not open.'], 422);
        }

        $result = DB::transaction(function () use ($debt, $data, $request) {
            $pay = min((float) $data['amount'], $debt->balance());
            $path = $this->storeReceipt($request, $data, $debt->shop_id);

            $payment = DebtPayment::create([
                'shop_id' => $debt->shop_id,
                'customer_debt_id' => $debt->id,
                'amount' => $pay,
                'payment_method' => $data['payment_method'] ?? 'cash',
                'reference' => $data['reference'] ?? null,
                'note' => $data['note'] ?? null,
                'receipt_path' => $path,
                'paid_at' => $data['paid_at'] ?? now(),
                'created_by' => $request->user()->id,
            ]);

            $debt = $this->payments->recalculate($debt);

            return [$payment->load('creator'), $debt];
        });

        return response()->json([
            'data' => $result[0]->toApiArray(),
            'debt' => $result[1]->toApiArray(),
        ]);
    }

    public function updatePayment(Request $request, string $id, string $paymentId)
    {
        $debt = CustomerDebt::forShop($request->user()->shop_id)
            ->with('customer')
            ->where('id', $id)
            ->firstOrFail();

        $payment = DebtPayment::query()
            ->where('customer_debt_id', $debt->id)
            ->where('id', $paymentId)
            ->firstOrFail();

        $data = $request->validate([
            'amount' => 'sometimes|required|numeric|min:0.01',
            'note' => 'nullable|string',
            'payment_method' => 'nullable|string|max:100',
            'reference' => 'nullable|string|max:255',
            'paid_at' => 'nullable|date',
            'receipt' => 'nullable|file|mimes:jpg,jpeg,png,webp,pdf|max:10240',
            'receipt_base64' => 'nullable|string',
            'receipt_filename' => 'nullable|string|max:255',
        ]);

        $result = DB::transaction(function () use ($debt, $payment, $data, $request) {
            if (array_key_exists('amount', $data)) {
                $payment->amount = (float) $data['amount'];
            }
            if (array_key_exists('note', $data)) {
                $payment->note = $data['note'];
            }
            if (array_key_exists('payment_method', $data)) {
                $payment->payment_method = $data['payment_method'];
            }
            if (array_key_exists('reference', $data)) {
                $payment->reference = $data['reference'];
            }
            if (array_key_exists('paid_at', $data)) {
                $payment->paid_at = $data['paid_at'];
            }

            $newPath = $this->storeReceipt($request, $data, $debt->shop_id);
            if ($newPath) {
                if ($payment->receipt_path) {
                    Storage::disk('public')->delete($payment->receipt_path);
                }
                $payment->receipt_path = $newPath;
            }

            $payment->save();

            // Temporarily mark open so recalc can set paid/open correctly
            if ($debt->status === 'paid') {
                $debt->status = 'open';
                $debt->save();
            }

            $debt = $this->payments->recalculate($debt->fresh('customer'));

            // Cap amount if payments exceed debt
            $sum = (float) DebtPayment::where('customer_debt_id', $debt->id)->sum('amount');
            if ($sum > (float) $debt->amount + 0.009) {
                abort(422, 'Total payments would exceed debt amount.');
            }

            return [$payment->fresh('creator'), $debt];
        });

        return response()->json([
            'data' => $result[0]->toApiArray(),
            'debt' => $result[1]->toApiArray(),
        ]);
    }

    public function writeOff(Request $request, string $id)
    {
        $debt = CustomerDebt::forShop($request->user()->shop_id)
            ->with('customer')
            ->where('id', $id)
            ->firstOrFail();

        $debt->status = 'written_off';
        $debt->save();
        CustomerDebt::recomputeOpenBalance($debt->customer);

        return response()->json($debt->fresh('customer')->toApiArray());
    }

    private function storeReceipt(Request $request, array $data, int $shopId): ?string
    {
        if ($request->hasFile('receipt')) {
            return $request->file('receipt')->store('debt-payments/'.$shopId, 'public');
        }
        if (! empty($data['receipt_base64'])) {
            $raw = $data['receipt_base64'];
            if (str_contains($raw, ',')) {
                $raw = explode(',', $raw, 2)[1];
            }
            $bytes = base64_decode($raw, true);
            if ($bytes !== false && strlen($bytes) > 0 && strlen($bytes) <= 10 * 1024 * 1024) {
                $name = $data['receipt_filename'] ?? ('receipt-'.uniqid().'.jpg');
                $name = basename(preg_replace('/[^a-zA-Z0-9._-]/', '_', $name));
                $path = 'debt-payments/'.$shopId.'/'.$name;
                Storage::disk('public')->put($path, $bytes);

                return $path;
            }
        }

        return null;
    }
}
