<?php

namespace App\Support;

/**
 * Build API media paths for files stored on the public disk.
 * Always relative so Express/haslim can proxy /api/media without APP_URL mismatch.
 */
class MediaUrl
{
    public static function fromPublicPath(?string $diskPath): ?string
    {
        if (! is_string($diskPath) || $diskPath === '') {
            return null;
        }

        $path = ltrim(str_replace('\\', '/', $diskPath), '/');
        // Strip accidental storage/ prefix
        if (str_starts_with($path, 'storage/')) {
            $path = substr($path, strlen('storage/'));
        }

        return '/api/media/'.$path;
    }
}
