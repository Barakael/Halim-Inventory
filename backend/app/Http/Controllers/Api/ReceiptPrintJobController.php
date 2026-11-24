<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ReceiptPrintJob;
use App\Models\Sale;
use App\Support\ShopRole;
use Illuminate\Http\Request;

class ReceiptPrintJobController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        if (! ShopRole::canViewReceipts($user->role)) {
            return response()->json(['message' => 'Only admin and super admin can view receipts.'], 403);
        }

        $canPrint = ShopRole::canPrintReceipts($user->role);
        $query = ReceiptPrintJob::forShop($user->shop_id)
            ->with(['cashier', 'printedBy'])
            ->orderByDesc('created_at');

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        $jobs = $query->limit(200)->get();

        return response()->json([
            'can_print' => $canPrint,
            'data' => $jobs->map(fn (ReceiptPrintJob $job) => $job->toApiArray($canPrint))->values(),
        ]);
    }

    public function show(Request $request, string $id)
    {
        $user = $request->user();
        if (! ShopRole::canViewReceipts($user->role)) {
            return response()->json(['message' => 'Only admin and super admin can view receipts.'], 403);
        }

        $job = $this->findJob($user->shop_id, $id);
        $sale = Sale::forShop($user->shop_id)
            ->with(['items', 'shop', 'cashier'])
            ->where('id', $job->sale_id)
            ->firstOrFail();

        $canPrint = ShopRole::canPrintReceipts($user->role);

        return response()->json([
            'data' => [
                'can_print' => $canPrint,
                'job' => $job->toApiArray($canPrint),
                'sale' => $sale->toApiArray(),
            ],
        ]);
    }

    public function markPrinted(Request $request, string $id)
    {
        $user = $request->user();
        if (! ShopRole::canPrintReceipts($user->role)) {
            return response()->json(['message' => 'Only admin can print receipts.'], 403);
        }

        $job = $this->findJob($user->shop_id, $id);
        $job->status = 'printed';
        $job->printed_at = now();
        $job->printed_by = $user->id;
        $job->save();
        $job->load(['cashier', 'printedBy']);

        return response()->json([
            'data' => $job->toApiArray(true),
        ]);
    }

    private function findJob(int $shopId, string $id): ReceiptPrintJob
    {
        return ReceiptPrintJob::forShop($shopId)
            ->with(['cashier', 'printedBy'])
            ->where('id', $id)
            ->firstOrFail();
    }
}
