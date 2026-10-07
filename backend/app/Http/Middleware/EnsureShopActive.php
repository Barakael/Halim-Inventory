<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureShopActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        if (! $user) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        $shop = $user->shop;
        if (! $shop || $shop->status !== 'active') {
            return response()->json(['message' => 'Shop is inactive or missing'], 403);
        }

        if ($user->status !== 'active') {
            return response()->json(['message' => 'User is inactive'], 403);
        }

        return $next($request);
    }
}
