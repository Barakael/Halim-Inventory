<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Branch;
use App\Models\User;
use Illuminate\Http\Request;

class BranchController extends Controller
{
    public function index(Request $request)
    {
        $branches = Branch::where('shop_id', $request->user()->shop_id)
            ->orderBy('name')
            ->get()
            ->map(fn (Branch $b) => $this->toApi($b));

        return response()->json(['data' => $branches]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'address' => 'nullable|string|max:500',
            'phone' => 'nullable|string|max:50',
        ]);

        $branch = Branch::create([
            'shop_id' => $request->user()->shop_id,
            'name' => $data['name'],
            'address' => $data['address'] ?? null,
            'phone' => $data['phone'] ?? null,
            'status' => 'active',
        ]);

        return response()->json($this->toApi($branch), 201);
    }

    public function update(Request $request, string $id)
    {
        $branch = Branch::where('shop_id', $request->user()->shop_id)->where('id', $id)->firstOrFail();
        $data = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'address' => 'nullable|string|max:500',
            'phone' => 'nullable|string|max:50',
            'status' => 'nullable|string|max:50',
        ]);
        $branch->fill($data)->save();

        return response()->json($this->toApi($branch));
    }

    public function destroy(Request $request, string $id)
    {
        $branch = Branch::where('shop_id', $request->user()->shop_id)->where('id', $id)->firstOrFail();

        if (User::where('shop_id', $request->user()->shop_id)->where('branch_id', $branch->id)->exists()) {
            return response()->json(['message' => 'Cannot delete branch with assigned staff.'], 422);
        }

        $branch->delete();

        return response()->json(['message' => 'Deleted']);
    }

    private function toApi(Branch $b): array
    {
        return [
            'id' => $b->id,
            'name' => $b->name,
            'address' => $b->address,
            'phone' => $b->phone,
            'status' => $b->status,
            'shop_id' => $b->shop_id,
            'created_at' => optional($b->created_at)?->toISOString(),
        ];
    }
}
