<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

class MediaController extends Controller
{
    /**
     * Stream public-disk files via authenticated API (avoids broken /storage URLs
     * when Express/haslim fronts Laravel).
     *
     * Paths:
     * - /api/media/products/{shopId}/{filename}
     * - /api/media/products/{filename}  (scoped to caller's shop)
     * - /api/media/purchase-payments/{shopId}/{filename}
     * - /api/media/debt-payments/{shopId}/{filename}
     */
    public function show(Request $request, string $folder, string $a, ?string $b = null): StreamedResponse
    {
        $shopId = (int) $request->user()->shop_id;
        [$diskPath, $downloadName] = $this->resolvePath($folder, $a, $b, $shopId);

        if (! Storage::disk('public')->exists($diskPath)) {
            abort(404, 'File not found');
        }

        $mime = Storage::disk('public')->mimeType($diskPath) ?: 'application/octet-stream';

        return Storage::disk('public')->response($diskPath, $downloadName, [
            'Content-Type' => $mime,
            'Content-Disposition' => 'inline; filename="'.$downloadName.'"',
        ]);
    }

    /** @return array{0: string, 1: string} */
    private function resolvePath(string $folder, string $a, ?string $b, int $userShopId): array
    {
        $allowed = ['products', 'purchase-payments', 'debt-payments'];
        if (! in_array($folder, $allowed, true)) {
            abort(404);
        }

        if ($b !== null) {
            $pathShopId = (int) $a;
            $filename = basename($b);
            if ($pathShopId !== $userShopId) {
                abort(403, 'Forbidden');
            }
            $diskPath = $folder.'/'.$pathShopId.'/'.$filename;

            return [$diskPath, $filename];
        }

        // Single segment: products/{filename} under caller's shop folder
        $filename = basename($a);
        if ($folder === 'products') {
            $diskPath = 'products/'.$userShopId.'/'.$filename;

            return [$diskPath, $filename];
        }

        abort(404);
    }
}
