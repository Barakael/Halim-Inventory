<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\CustomerDebt;
use App\Models\DebtPayment;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DebtController extends Controller
{
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

        return response()->json([
            'open_count' => $open->count(),
            'open_balance' => round($open->sum(fn (CustomerDebt $d) => $d->balance()), 2),
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

            $this->recomputeCustomerDebt($customer);

            return $debt->load('customer');
        });

        return response()->json($debt->toApiArray(), 201);
    }

    public function pay(Request $request, string $id)
    {
        $data = $request->validate([
            'amount' => 'required|numeric|min:0.01',
            'note' => 'nullable|string',
        ]);

        $debt = CustomerDebt::forShop($request->user()->shop_id)
            ->with('customer')
            ->where('id', $id)
            ->firstOrFail();

        if ($debt->status !== 'open') {
            return response()->json(['message' => 'Debt is not open.'], 422);
        }

        $debt = DB::transaction(function () use ($debt, $data, $request) {
            $pay = min((float) $data['amount'], $debt->balance());
            DebtPayment::create([
                'customer_debt_id' => $debt->id,
                'amount' => $pay,
                'note' => $data['note'] ?? null,
                'created_by' => $request->user()->id,
            ]);
            $debt->amount_paid = (float) $debt->amount_paid + $pay;
            if ($debt->balance() <= 0.0001) {
                $debt->status = 'paid';
                $debt->amount_paid = (float) $debt->amount;
            }
            $debt->save();
            $this->recomputeCustomerDebt($debt->customer);

            return $debt->fresh('customer');
        });

        return response()->json($debt->toApiArray());
    }

    public function writeOff(Request $request, string $id)
    {
        $debt = CustomerDebt::forShop($request->user()->shop_id)
            ->with('customer')
            ->where('id', $id)
            ->firstOrFail();

        $debt->status = 'written_off';
        $debt->save();
        $this->recomputeCustomerDebt($debt->customer);

        return response()->json($debt->fresh('customer')->toApiArray());
    }

    private function recomputeCustomerDebt(?Customer $customer): void
    {
        if (! $customer) {
            return;
        }
        $open = CustomerDebt::where('customer_id', $customer->id)
            ->where('status', 'open')
            ->get()
            ->sum(fn (CustomerDebt $d) => $d->balance());
        $customer->open_debt_balance = $open;
        $customer->save();
    }
}
