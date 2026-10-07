<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Branch;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class StaffController extends Controller
{
    public function index(Request $request)
    {
        $staff = User::where('shop_id', $request->user()->shop_id)
            ->with('branch')
            ->whereIn('role', ['cashier', 'storekeeper', 'owner', 'admin'])
            ->orderBy('name')
            ->get()
            ->map(fn (User $u) => $this->toApi($u));

        return response()->json(['data' => $staff]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255',
            'password' => 'required|string|min:6',
            'branch_id' => 'nullable|integer',
            'phone' => 'nullable|string|max:50',
            'role' => 'nullable|string|max:50',
        ]);

        $shopId = $request->user()->shop_id;
        $branchId = $this->resolveBranch($shopId, $data['branch_id'] ?? null);
        $username = $this->uniqueUsername(Str::before($data['email'], '@') ?: 'staff');

        $user = User::create([
            'shop_id' => $shopId,
            'branch_id' => $branchId,
            'name' => $data['name'],
            'username' => $username,
            'email' => $data['email'],
            'phone' => $data['phone'] ?? null,
            'password' => $data['password'],
            'role' => $data['role'] ?? 'cashier',
            'status' => 'active',
        ]);

        return response()->json($this->toApi($user->load('branch')), 201);
    }

    public function update(Request $request, string $id)
    {
        $user = User::where('shop_id', $request->user()->shop_id)->where('id', $id)->firstOrFail();
        $data = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'email' => 'sometimes|required|email|max:255',
            'password' => 'nullable|string|min:6',
            'branch_id' => 'nullable|integer',
            'phone' => 'nullable|string|max:50',
            'role' => 'nullable|string|max:50',
            'status' => 'nullable|string|max:50',
        ]);

        if (array_key_exists('branch_id', $data)) {
            $user->branch_id = $this->resolveBranch($request->user()->shop_id, $data['branch_id']);
        }
        foreach (['name', 'email', 'phone', 'role', 'status'] as $field) {
            if (array_key_exists($field, $data)) {
                $user->{$field} = $data[$field];
            }
        }
        if (! empty($data['password'])) {
            $user->password = $data['password'];
        }
        $user->save();

        return response()->json($this->toApi($user->load('branch')));
    }

    public function destroy(Request $request, string $id)
    {
        $user = User::where('shop_id', $request->user()->shop_id)->where('id', $id)->firstOrFail();
        if ($user->id === $request->user()->id) {
            return response()->json(['message' => 'Cannot delete yourself.'], 422);
        }
        $user->tokens()->delete();
        $user->delete();

        return response()->json(['message' => 'Deleted']);
    }

    private function resolveBranch(int $shopId, mixed $id): ?int
    {
        if ($id === null || $id === '') {
            return null;
        }

        return Branch::where('shop_id', $shopId)->where('id', $id)->value('id');
    }

    private function uniqueUsername(string $base): string
    {
        $base = preg_replace('/[^a-zA-Z0-9._-]/', '', $base) ?: 'staff';
        $candidate = $base;
        $i = 1;
        while (User::where('username', $candidate)->exists()) {
            $candidate = $base.$i;
            $i++;
        }

        return $candidate;
    }

    private function toApi(User $u): array
    {
        return [
            'id' => $u->id,
            'name' => $u->name,
            'email' => $u->email,
            'phone' => $u->phone,
            'role' => $u->role,
            'role_name' => $u->role,
            'branch_id' => $u->branch_id,
            'branch' => $u->relationLoaded('branch') && $u->branch
                ? ['id' => $u->branch->id, 'name' => $u->branch->name]
                : null,
            'branch_name' => $u->branch?->name,
            'shop_id' => $u->shop_id,
            'created_at' => optional($u->created_at)?->toISOString(),
            'updated_at' => optional($u->updated_at)?->toISOString(),
        ];
    }
}
