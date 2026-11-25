<?php

use App\Support\ShopRole;
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('shop.{shopId}.receipts', function ($user, int $shopId) {
    if ((int) $user->shop_id !== $shopId) {
        return false;
    }

    return ShopRole::canPrintReceipts($user->role);
});
