<?php

namespace App\Support;

class ShopRole
{
    public static function normalize(?string $role): string
    {
        return strtolower(trim((string) $role));
    }

    public static function isSuperAdmin(?string $role): bool
    {
        return self::normalize($role) === 'super_admin';
    }

    /** Shop admin (Laravel owner or admin). Super admin is excluded. */
    public static function canPrintReceipts(?string $role): bool
    {
        return in_array(self::normalize($role), ['owner', 'admin'], true);
    }

    public static function canViewReceipts(?string $role): bool
    {
        return self::canPrintReceipts($role) || self::isSuperAdmin($role);
    }
}
