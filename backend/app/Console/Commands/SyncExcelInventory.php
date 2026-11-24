<?php

namespace App\Console\Commands;

use App\Models\Product;
use App\Models\StockMovement;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class SyncExcelInventory extends Command
{
    protected $signature = 'inventory:sync-excel
        {path : Path to Excel inventory JSON (array of {name, qty})}
        {--shop=1 : Shop ID}
        {--apply : Persist changes (default is dry-run)}';

    protected $description = 'Sync physical stock count from Excel JSON: overwrite matched stock+name (keep prices), add new products';

    /** Explicit false positives that must never auto-match. */
    private array $excludePairs = [
        'nice one king|nice one 180g',
        'afiya berries ml 300|afya berries 400mls mix',
        'afiya berries 300|afya berries 400mls mix',
    ];

    /** Manual aliases: normalized excel key => preferred production name substring/exact. */
    private array $manualAliases = [
        'tomato ml 900' => 'tomato 900 ml',
        'tomato 900 ml' => 'tomato 900 ml',
        'tomato ml 250' => 'tomato 250 ml',
        'tomato 250 ml' => 'tomato 250 ml',
        'tomato l5' => 'tomato 5 l',
        'tomato 5 l' => 'tomato 5 l',
        'afya l13' => 'afya 13 l',
        'afya 1 6 l' => 'afya 1.6 l',
        'afya 1 l' => 'afya 1 l',
        'afya ml 500' => 'afya 500 ml',
        'sembe kg 5' => 'sembe 5kg',
        'sembe 5 kg' => 'sembe 5kg',
        'sembe kg 10' => 'sembe 10kg',
        'sembe kg 25' => 'sembe 25kg',
        'dona kg 25' => 'dona 25kg',
        'dona 5 kg' => 'dona 5kg',
        'kande kg 25' => 'makande 25kg',
        'sukari kg 50' => 'sukari 50kg',
        'ndoo l20' => 'ndoo 20 l',
        'ndoo 20 l' => 'ndoo 20 l',
        'sunsan 1 8 l' => 'sunsan maji 1.8 l',
        'sunsan 15 l' => 'sunsan 15 l',
        'softcare m12' => 'softcare m12 ctn mix',
        'softcare l 40' => 'softcare l40 ctn',
        'softcare l40' => 'softcare l40 ctn',
        'g boost' => 'g boost juice',
        'skala 200g' => 'skala 200g ctn',
        'skala 100g' => 'skala 100g ctn',
        'skala 25g' => 'skala 25g ctn',
        'bodyluxe 200g' => 'bodyluxe 200g ctn',
        'afrocare 200g ctn' => 'afrocare 200g ctn',
        'afrocare 100g ctn' => 'afrocare 100g ctn',
        'afrocare 50g ctn' => 'afrocare 50g ctn',
        'cocoabutter 200g ctn' => 'cocoabutter 200g ctn',
        'whitedent 40g' => 'whitedent 40g ctn',
        'whitedent 20g' => 'whitedent 20g ctn',
        'whitedent 70g' => 'whitedent 70g and 80g ctn',
        'whitedent 80g' => 'whitedent 70g and 80g ctn',
        'whitedent miswaki' => 'miswak whitedent ctn',
        'doff 180g' => 'doff 160g',
        'nice one 180g' => 'nice one 180g',
        'kleesoft kg 3' => 'kleesoft 3kg',
        'kleesoft 3 kg' => 'kleesoft 3kg',
        'king limau kg 15' => 'king limau 15kg',
        'king limau 15 kg' => 'king limau 15kg',
        'hit ml850' => 'hit 850 ml',
        'hit ml400' => 'hit 400 ml',
        'hit 850 ml' => 'hit 850 ml',
        'hit 400 ml' => 'hit 400 ml',
        'rungu spray ml 850' => 'rungu spray 850 ml',
        'rungu spray ml 400' => 'rungu spray 400 ml',
        'fumo gum ctn' => 'fumo ctn',
        'shenk vidonge ctn' => 'shenke vidonge ctn',
        'femo ml 100 ctn' => 'femo 100 ml ctn',
        'asas milk ml 500' => 'asas maziwa',
        'azam energy can ml 250' => 'azam energy can',
        'sayona tunda ndogo ml 300' => 'tunda ndogo',
        'sayona tunda kubwa ml 600' => 'tunda kubwa',
        'santa lucia box' => 'tambi santa lucia',
        'mo tambi box' => 'mo tambi',
        'azam nazi box' => 'azam nazi',
        'gsm 1 l' => 'gsm maji 1 l',
        'singida l5 pc' => 'singida 5 l pc',
        'singida l3 pc' => 'singida 3 l pc',
        'min cup chocolate pc' => 'min cup choco ctn',
        'softcare wipes ctn' => 'softcare wipes ctn',
        'softcare pady' => 'softcare pady 10 ctn',
        'imperial soap kubwa ctn' => 'imperial kubwa ctn',
        'imperial soap ndogo ctn' => 'imperial ndogo ctn',
        'big boss ctn' => 'big boss and gomba',
        'baby cheeky kubwa' => 'baby cheeky ctn',
        'baby cheeky ndogo pc' => 'baby cheeky ctn',
        'azam punch ml 300 ctn' => 'azam apple punch 300 ml',
        'afya berries ml 400' => 'afya berries 400 ml mix',
        'afya berries ml 300' => 'afya berries 300 ml mix',
        'mo beauty soap ctn' => 'mo beauty soap ctn',
        'green label 3g ctn' => 'green label 3g ctn',
        'green label 50g ctn' => 'green label 50g ctn',
        'vestiline herbal 200g ctn' => 'vestiline herbal 200g ctn',
        'vestiline herbal 100g ctn' => 'vestiline herbal 100g ctn',
        'vestiline herbal 50g ctn' => 'vestiline herbal 50g ctn',
        'vestiline herbal 25g ctn' => 'vestiline herbal 25g ctn',
        'prestige 250g ctn' => 'prestige 250g ctn',
        'doff 400g' => 'doff 400g',
        'kangaroo ctn' => 'kangaroo kiwi ctn',
        'chemi cola ctn' => 'chemi cola ndogo ctn',
        'ngano ssb' => 'ssb ngano 25kg',
        'nanakia pady' => 'nanakia classic pady',
        'tiger ndogo ctn' => 'tiger battery ndogo ctn',
        'king limau kg 3' => 'king limau 3kg',
        'king limau 3 kg' => 'king limau 3kg',
        'nice one kg 3' => 'nice one 3kg',
        'nice one 3 kg' => 'nice one 3kg',
        'baby powder 100g' => 'powder 100g ctn',
        'vestrine garlic 100g' => 'garlic 100g ctn',
        'whitedent 125g' => 'whitedent 110g and 125g ctn',
        'chama pc' => 'chama',
        'ivory box' => 'ivory',
        'freestyle ndogo box' => 'freestyle ndogo',
        'mabuyuzi pc' => 'mabuyuzi ctn',
        'ashers 25g' => 'ashers 25g ctn',
        'san sum 1 8 l' => 'sunsan maji 1.8 l',
        'sunsan 1 8 l' => 'sunsan maji 1.8 l',
        'sunsan 15 l' => 'sunsan 15 l',
        'afiya 1 6 l' => 'afya 1.6 l',
        'afiya 1 l' => 'afya 1 l',
        'gsm 1l' => 'gsm maji 1 l',
    ];

    public function handle(): int
    {
        $path = $this->argument('path');
        if (! is_file($path)) {
            $this->error("File not found: {$path}");

            return self::FAILURE;
        }

        $excel = json_decode(file_get_contents($path), true);
        if (! is_array($excel)) {
            $this->error('Invalid JSON');

            return self::FAILURE;
        }

        $shopId = (int) $this->option('shop');
        $apply = (bool) $this->option('apply');

        $products = Product::query()->where('shop_id', $shopId)->get();
        $indexed = $products->map(function (Product $p) {
            $toks = $this->tokens($p->name);
            $sizes = $this->sizes($toks);

            return [
                'model' => $p,
                'toks' => $toks,
                'sizes' => $sizes,
                'brand' => $this->brandish($toks, $sizes),
                'n' => implode(' ', $toks),
            ];
        })->all();

        $used = [];
        $matches = [];
        $news = [];

        foreach ($excel as $row) {
            $name = trim((string) ($row['name'] ?? ''));
            $qty = (int) ($row['qty'] ?? 0);
            if ($name === '') {
                continue;
            }

            $et = $this->tokens($name);
            $es = $this->sizes($et);
            $eb = $this->brandish($et, $es);
            $en = implode(' ', $et);
            $aliasRaw = $this->manualAliases[$en] ?? null;
            $aliasTarget = $aliasRaw !== null ? implode(' ', $this->tokens($aliasRaw)) : null;

            $best = null;
            $bestScore = 0.0;

            foreach ($indexed as $p) {
                $id = $p['model']->id;
                if (isset($used[$id])) {
                    continue;
                }

                if ($this->isExcluded($en, $p['n'])) {
                    continue;
                }

                // Manual alias exact normalized name hit
                if ($aliasTarget !== null && $p['n'] === $aliasTarget) {
                    $best = $p;
                    $bestScore = 1.0;
                    break;
                }

                if (! $this->sizesCompatible($es, $p['sizes'])) {
                    continue;
                }

                $r = $this->similarity($en, $p['n']);
                $bt = $eb;
                $pt = $p['brand'];
                $ov = (count($bt) || count($pt))
                    ? count(array_intersect($bt, $pt)) / max(1, count(array_unique(array_merge($bt, $pt))))
                    : 0.0;
                $score = 0.5 * $r + 0.5 * $ov;

                if ($aliasTarget !== null && str_contains($p['n'], $aliasTarget)) {
                    $score = max($score, 0.95);
                }
                if ($es && $es == $p['sizes'] && $bt && $bt == $pt) {
                    $score = 1.0;
                } elseif ($es && $es == $p['sizes'] && $ov >= 0.5) {
                    $score = max($score, 0.85);
                }

                // Prefer alias substring matches
                if ($aliasTarget !== null && $this->similarity($aliasTarget, $p['n']) >= 0.9) {
                    $score = max($score, 0.96);
                }

                if ($score > $bestScore) {
                    $bestScore = $score;
                    $best = $p;
                }
            }

            // Second pass: if alias target set but not found exact, pick best alias similarity among unused
            if ($aliasTarget !== null && ($best === null || $bestScore < 0.9)) {
                foreach ($indexed as $p) {
                    $id = $p['model']->id;
                    if (isset($used[$id])) {
                        continue;
                    }
                    if ($this->isExcluded($en, $p['n'])) {
                        continue;
                    }
                    $s = $this->similarity($aliasTarget, $p['n']);
                    if ($s >= 0.88 && $s > $bestScore) {
                        $best = $p;
                        $bestScore = max($s, 0.93);
                    }
                }
            }

            $includeReview = $bestScore >= 0.70;
            $safe = $bestScore >= 0.92
                || ($es && $best && $es == $best['sizes'] && $this->brandOverlap($eb, $best['brand']) >= 0.66 && $bestScore >= 0.75)
                || ($aliasTarget !== null && $bestScore >= 0.90);

            if ($best && ($safe || $includeReview) && ! $this->isExcluded($en, $best['n'])) {
                // Final veto for known bad pairs already handled; also veto size mismatch when both have sizes
                if ($es && $best['sizes'] && ! $this->sizesCompatible($es, $best['sizes'])) {
                    $news[] = ['excel' => $name, 'qty' => $qty, 'closest' => $best['model']->name, 'score' => $bestScore];
                    continue;
                }
                // Veto Nice one King / berries 300 vs 400 already in exclude
                $used[$best['model']->id] = true;
                $matches[] = [
                    'excel' => $name,
                    'qty' => $qty,
                    'product' => $best['model'],
                    'sys' => $best['model']->name,
                    'old_stock' => (int) $best['model']->stock,
                    'price' => (float) $best['model']->price,
                    'cost' => (float) $best['model']->cost_price,
                    'score' => round($bestScore, 3),
                ];
            } else {
                $news[] = [
                    'excel' => $name,
                    'qty' => $qty,
                    'closest' => $best['model']->name ?? null,
                    'score' => $best ? round($bestScore, 3) : 0,
                ];
            }
        }

        $this->info('Matches: '.count($matches));
        $this->info('New: '.count($news));
        $this->table(
            ['Score', 'Excel', 'Qty', 'System', 'OldStock', 'Price'],
            array_map(fn ($m) => [
                $m['score'],
                mb_substr($m['excel'], 0, 36),
                $m['qty'],
                mb_substr($m['sys'], 0, 36),
                $m['old_stock'],
                $m['price'],
            ], $matches)
        );

        if ($news) {
            $this->warn('New products to add (price=0):');
            foreach (array_slice($news, 0, 80) as $n) {
                $hint = $n['closest'] ? " closest={$n['closest']}@{$n['score']}" : '';
                $this->line("  + {$n['excel']} qty={$n['qty']}{$hint}");
            }
            if (count($news) > 80) {
                $this->line('  ... +'.(count($news) - 80).' more');
            }
        }

        if (! $apply) {
            $this->comment('Dry-run only. Re-run with --apply to persist.');

            return self::SUCCESS;
        }

        $admin = User::query()->where('shop_id', $shopId)->orderBy('id')->first();
        $createdBy = $admin?->id;

        $branchId = $createdBy ? User::query()->find($createdBy)?->branch_id : null;

        DB::transaction(function () use ($matches, $news, $shopId, $createdBy, $branchId) {
            foreach ($matches as $m) {
                /** @var Product $product */
                $product = Product::query()->where('shop_id', $shopId)->lockForUpdate()->findOrFail($m['product']->id);
                $old = (int) $product->stock;
                $newQty = max(0, (int) $m['qty']);
                $delta = $newQty - $old;

                $product->name = $m['excel'];
                $product->stock = $newQty;
                // prices intentionally untouched
                $product->save();

                if ($delta !== 0) {
                    StockMovement::create([
                        'shop_id' => $shopId,
                        'product_id' => $product->id,
                        'branch_id' => $branchId,
                        'quantity' => $delta,
                        'type' => 'adjustment',
                        'cost_price' => $product->cost_price,
                        'notes' => 'Excel physical count sync '.date('Y-m-d'),
                        'created_by' => $createdBy,
                    ]);
                }
            }

            foreach ($news as $n) {
                Product::create([
                    'shop_id' => $shopId,
                    'category_id' => null,
                    'name' => $n['excel'],
                    'description' => null,
                    'price' => 0,
                    'cost_price' => 0,
                    'barcode' => null,
                    'sku' => null,
                    'unit' => 'pcs',
                    'stock' => max(0, (int) $n['qty']),
                    'low_stock_threshold' => 10,
                    'status' => 'active',
                ]);
            }
        });

        $this->info('Applied: '.count($matches).' overwrites, '.count($news).' new products.');

        return self::SUCCESS;
    }

    private function isExcluded(string $excelNorm, string $sysNorm): bool
    {
        $pair = $excelNorm.'|'.$sysNorm;
        foreach ($this->excludePairs as $ex) {
            if ($pair === $ex) {
                return true;
            }
        }
        // also soft-exclude berries 300 vs 400
        if (str_contains($excelNorm, 'berries') && str_contains($excelNorm, '300')
            && str_contains($sysNorm, 'berries') && str_contains($sysNorm, '400')) {
            return true;
        }
        if ($excelNorm === 'nice one king' && str_contains($sysNorm, '180')) {
            return true;
        }

        return false;
    }

    private function tokens(string $s): array
    {
        $s = strtolower($s);
        $s = str_replace(["'", '"'], '', $s);
        $s = preg_replace('/[^a-z0-9.]+/', ' ', $s) ?? $s;
        $s = preg_replace('/\s+/', ' ', trim($s)) ?? $s;

        $spell = [
            'afiya' => 'afya',
            'san' => 'san',
            'sum' => 'sum',
            'sansum' => 'sunsan',
            'sunsan' => 'sunsan',
            'paineple' => 'pineapple',
            'passioni' => 'passion',
            'limao' => 'limau',
            'doffy' => 'doff',
            'prestage' => 'prestige',
            'prestige' => 'prestige',
            'vestline' => 'vestiline',
            'vestiline' => 'vestiline',
            'lebel' => 'label',
            'label' => 'label',
            'beuty' => 'beauty',
            'beauty' => 'beauty',
            'caton' => 'ctn',
            'carton' => 'ctn',
            'mls' => 'ml',
            'lt' => 'l',
            'pcs' => 'pc',
            'skalla' => 'skala',
            'skala' => 'skala',
            'lux' => 'luxe',
            'luxe' => 'luxe',
            'spry' => 'spray',
            'wips' => 'wipes',
            'cheeck' => 'cheeky',
            'cheeky' => 'cheeky',
            'impirial' => 'imperial',
            'imperial' => 'imperial',
            'ndg' => 'ndogo',
            'betri' => 'battery',
        ];

        $parts = [];
        foreach (explode(' ', $s) as $t) {
            if ($t === '') {
                continue;
            }
            $parts[] = $spell[$t] ?? $t;
        }

        // merge "san sum" -> sunsan
        $out = [];
        for ($i = 0; $i < count($parts); $i++) {
            if ($parts[$i] === 'san' && ($parts[$i + 1] ?? null) === 'sum') {
                $out[] = 'sunsan';
                $i++;
                continue;
            }
            if ($parts[$i] === 'white' && ($parts[$i + 1] ?? null) === 'dent') {
                $out[] = 'whitedent';
                $i++;
                continue;
            }
            if ($parts[$i] === 'soft' && ($parts[$i + 1] ?? null) === 'care') {
                $out[] = 'softcare';
                $i++;
                continue;
            }
            if ($parts[$i] === 'afro' && ($parts[$i + 1] ?? null) === 'care') {
                $out[] = 'afrocare';
                $i++;
                continue;
            }
            if ($parts[$i] === 'body' && in_array($parts[$i + 1] ?? '', ['lux', 'luxe'], true)) {
                $out[] = 'bodyluxe';
                $i++;
                continue;
            }
            if ($parts[$i] === 'cocoa' && ($parts[$i + 1] ?? null) === 'butter') {
                $out[] = 'cocoabutter';
                $i++;
                continue;
            }
            if ($parts[$i] === 'cocoabutter') {
                $out[] = 'cocoabutter';
                continue;
            }
            $out[] = $parts[$i];
        }

        return $out;
    }

    private function sizes(array $toks): array
    {
        $text = implode(' ', $toks);
        $out = [];

        // number then unit: 400 g, 1.6 l, 300 ml
        if (preg_match_all('/(\d+(?:\.\d+)?)\s*(kg|g|ml|l)\b/', $text, $m, PREG_SET_ORDER)) {
            foreach ($m as $hit) {
                $out[$hit[1].$hit[2]] = true;
            }
        }
        // unit then number: ml 300, l 13, kg 5
        if (preg_match_all('/\b(kg|g|ml|l)\s*(\d+(?:\.\d+)?)\b/', $text, $m, PREG_SET_ORDER)) {
            foreach ($m as $hit) {
                $out[$hit[2].$hit[1]] = true;
            }
        }
        // glued tokens 400g / 1.6l / 300mls
        foreach ($toks as $t) {
            if (preg_match('/^(\d+(?:\.\d+)?)(kg|g|ml|l|mls|lt)$/', $t, $hit)) {
                $u = $hit[2];
                if ($u === 'mls') {
                    $u = 'ml';
                }
                if ($u === 'lt') {
                    $u = 'l';
                }
                $out[$hit[1].$u] = true;
            }
        }

        // bare L13 / L5 style already split as l 13 via tokens? handle afya l13 as tokens afya l13
        // token like l13
        foreach ($toks as $t) {
            if (preg_match('/^l(\d+(?:\.\d+)?)$/', $t, $hit)) {
                $out[$hit[1].'l'] = true;
            }
        }

        return array_keys($out);
    }

    private function brandish(array $toks, array $sizes): array
    {
        $ignore = array_flip(array_merge($sizes, ['ctn', 'box', 'outer', 'mix', 'and', 'the', 'pc', 'can', 'maji', 'aut a', 'auta']));
        $brand = [];
        foreach ($toks as $t) {
            if (preg_match('/^\d+(?:\.\d+)?(kg|g|ml|l|mls|lt)?$/', $t)) {
                continue;
            }
            if (isset($ignore[$t])) {
                continue;
            }
            $brand[] = $t;
        }

        return $brand;
    }

    private function brandOverlap(array $a, array $b): float
    {
        if (! $a && ! $b) {
            return 0.0;
        }
        $inter = count(array_intersect($a, $b));
        $union = count(array_unique(array_merge($a, $b)));

        return $union ? $inter / $union : 0.0;
    }

    private function sizesCompatible(array $excelSizes, array $prodSizes): bool
    {
        if (! $excelSizes) {
            return true;
        }
        if (! $prodSizes) {
            return false;
        }
        $es = array_values($excelSizes);
        $ps = array_values($prodSizes);
        $inter = array_intersect($es, $ps);
        if (! $inter) {
            return false;
        }

        // allow excel ⊆ prod or prod ⊆ excel (combo packs like 110g and 125g)
        return empty(array_diff($es, $ps)) || empty(array_diff($ps, $es));
    }

    private function similarity(string $a, string $b): float
    {
        similar_text($a, $b, $pct);

        return $pct / 100.0;
    }
}
