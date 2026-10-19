<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Shop;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SettingsController extends Controller
{
    public function show(Request $request)
    {
        $shop = $request->user()->shop()->firstOrFail();

        return response()->json($shop->toApiArray());
    }

    public function update(Request $request)
    {
        $shop = $request->user()->shop()->firstOrFail();

        $data = $request->validate([
            'name' => 'sometimes|string|max:255',
            'address' => 'nullable|string|max:500',
            'phone' => 'nullable|string|max:50',
            'email' => 'nullable|email|max:255',
            'tax_rate' => 'nullable|numeric|min:0|max:100',
            'currency' => 'nullable|string|max:10',
            'tin' => 'nullable|string|max:100',
            'vrn' => 'nullable|string|max:100',
            'mobile' => 'nullable|string|max:50',
            'location' => 'nullable|string|max:255',
            'tax_office' => 'nullable|string|max:255',
            'theme_id' => [
                'sometimes',
                'string',
                Rule::in(['classic', 'coral', 'indigo', 'warm', 'grove']),
            ],
        ]);

        if (array_key_exists('theme_id', $data)) {
            $data['theme_id'] = Shop::normalizeThemeId($data['theme_id']);
        }

        $shop->update($data);

        return response()->json($shop->fresh()->toApiArray());
    }
}
