<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

/**
 * Stub for owner settings Plan tab — empty lists until billing is implemented.
 */
class SubscriptionController extends Controller
{
    public function index(Request $request)
    {
        return response()->json(['data' => []]);
    }

    public function payments(Request $request)
    {
        return response()->json(['data' => []]);
    }
}
