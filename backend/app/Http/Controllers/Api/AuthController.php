<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $data = $request->validate([
            'username' => 'nullable|string',
            'email' => 'nullable|string',
            'password' => 'required|string',
        ]);

        $identifier = trim((string) ($data['username'] ?? $data['email'] ?? ''));
        if ($identifier === '') {
            throw ValidationException::withMessages([
                'username' => ['Username is required.'],
            ]);
        }

        $key = 'login:'.$request->ip().':'.strtolower($identifier);
        if (RateLimiter::tooManyAttempts($key, 8)) {
            $seconds = RateLimiter::availableIn($key);

            return response()->json([
                'message' => "Too many login attempts. Try again in {$seconds} seconds.",
            ], 429);
        }

        $user = User::with('shop')
            ->where(function ($q) use ($identifier) {
                $q->where('username', $identifier)
                    ->orWhere('email', $identifier);
            })
            ->first();

        $passwordOk = false;
        if ($user) {
            // Prefer PHP password_verify for bcryptjs ($2a$) hashes from Express JSON.
            if (is_string($user->password) && str_starts_with($user->password, '$2')) {
                $passwordOk = password_verify($data['password'], $user->password);
            }
            if (! $passwordOk) {
                try {
                    $passwordOk = Hash::check($data['password'], $user->password);
                } catch (\Throwable) {
                    $passwordOk = false;
                }
            }
        }

        if (! $passwordOk) {
            RateLimiter::hit($key, 900);

            throw ValidationException::withMessages([
                'username' => ['Invalid credentials.'],
            ]);
        }

        RateLimiter::clear($key);

        if ($user->status !== 'active' || ! $user->shop || $user->shop->status !== 'active') {
            return response()->json(['message' => 'Account or shop is inactive'], 403);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => $user->toApiArray(),
        ]);
    }

    public function me(Request $request)
    {
        $user = $request->user()->load('shop');

        return response()->json($user->toApiArray());
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json(['message' => 'Logged out']);
    }
}
