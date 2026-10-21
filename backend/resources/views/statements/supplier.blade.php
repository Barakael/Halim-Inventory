<!DOCTYPE html>
<html lang="sw">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Taarifa — {{ $supplier['name'] ?? 'Msambazaji' }}</title>
    <style>
        /* Page size + margins (print engine uses these; body padding is for screen only) */
        @page {
            size: A4 landscape;
            margin: 14mm 12mm 16mm 12mm;

            @bottom-left {
                content: "{{ $shop['name'] ?? 'Shop' }} · {{ $supplier['name'] ?? '' }}";
                font-size: 8pt;
                color: #555;
                font-family: "Segoe UI", Tahoma, sans-serif;
            }

            @bottom-center {
                content: "Ukurasa " counter(page) " / " counter(pages);
                font-size: 8pt;
                color: #333;
                font-family: "Segoe UI", Tahoma, sans-serif;
            }

            @bottom-right {
                content: "{{ $from }} — {{ $to }}";
                font-size: 8pt;
                color: #555;
                font-family: "Segoe UI", Tahoma, sans-serif;
            }
        }

        * { box-sizing: border-box; }

        html, body {
            height: auto;
        }

        body {
            margin: 0;
            padding: 12px 16px 20px;
            color: #111;
            background: #fff;
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
            font-size: 10px;
            line-height: 1.3;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
        }

        .no-print {
            margin-bottom: 12px;
            display: flex;
            gap: 8px;
            align-items: center;
            flex-wrap: wrap;
        }

        .no-print button {
            border: 1px solid #1a3a5c;
            background: #1a3a5c;
            color: #fff;
            padding: 8px 16px;
            font-size: 13px;
            border-radius: 4px;
            cursor: pointer;
        }

        .no-print button.secondary {
            background: #fff;
            color: #1a3a5c;
        }

        .no-print .hint {
            color: #666;
            font-size: 12px;
        }

        .sheet {
            width: 100%;
        }

        /* Keep header block together on first page */
        .page-header {
            page-break-inside: avoid;
            break-inside: avoid;
            margin-bottom: 10px;
        }

        .letterhead {
            display: flex;
            justify-content: space-between;
            gap: 20px;
            align-items: flex-start;
            border-bottom: 2px solid #1a3a5c;
            padding-bottom: 8px;
            margin-bottom: 8px;
        }

        .brand-name {
            font-size: 16px;
            font-weight: 700;
            color: #1a3a5c;
            margin: 0 0 2px;
            letter-spacing: 0.02em;
        }

        .brand-meta {
            color: #444;
            font-size: 9.5px;
            line-height: 1.4;
        }

        .doc-block {
            text-align: right;
            min-width: 220px;
        }

        .doc-title {
            margin: 0 0 4px;
            font-size: 12px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: #1a3a5c;
        }

        .doc-line {
            margin: 1px 0;
            color: #222;
            font-size: 9.5px;
        }

        .doc-line span {
            color: #666;
        }

        .summary-bar {
            display: flex;
            border: 1px solid #c5d0dc;
            border-radius: 3px;
            overflow: hidden;
            page-break-inside: avoid;
            break-inside: avoid;
        }

        .summary-item {
            flex: 1;
            padding: 6px 10px;
            border-right: 1px solid #c5d0dc;
            background: #f4f7fa;
        }

        .summary-item:last-child {
            border-right: none;
        }

        .summary-item .lbl {
            display: block;
            font-size: 8px;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            color: #556677;
            margin-bottom: 1px;
        }

        .summary-item .val {
            font-size: 11px;
            font-weight: 700;
            font-variant-numeric: tabular-nums;
        }

        .summary-item.danger .val {
            color: #a33;
        }

        table.ledger {
            width: 100%;
            border-collapse: collapse;
            table-layout: fixed;
            margin-top: 8px;
        }

        /* Repeat column headers on every printed page */
        table.ledger thead {
            display: table-header-group;
        }

        table.ledger tfoot {
            display: table-footer-group;
        }

        table.ledger tbody {
            display: table-row-group;
        }

        table.ledger th {
            background: #1a3a5c;
            color: #fff;
            font-size: 8px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.03em;
            padding: 5px 4px;
            text-align: left;
            border: none;
        }

        table.ledger th.num {
            text-align: right;
        }

        table.ledger td {
            padding: 4px 4px;
            border-bottom: 1px solid #dde3ea;
            vertical-align: top;
            word-wrap: break-word;
            overflow-wrap: anywhere;
        }

        /* Avoid splitting a data row across pages */
        table.ledger tbody tr {
            page-break-inside: avoid;
            break-inside: avoid;
        }

        table.ledger td.num {
            text-align: right;
            font-variant-numeric: tabular-nums;
            white-space: nowrap;
            font-weight: 500;
        }

        table.ledger tbody tr:nth-child(even) td {
            background: #f8fafc;
        }

        table.ledger tbody tr.row-payment td {
            background: #eef8f1;
        }

        table.ledger tbody tr.row-payment:nth-child(even) td {
            background: #e6f4ea;
        }

        table.ledger .muted {
            color: #888;
        }

        table.ledger .deni {
            font-weight: 700;
        }

        .col-date { width: 8%; }
        .col-person { width: 12%; }
        .col-phone { width: 11%; }
        .col-products { width: 23%; }
        .col-qty { width: 6%; }
        .col-jumla { width: 12%; }
        .col-malipo { width: 12%; }
        .col-deni { width: 12%; }

        .totals-wrap {
            margin-top: 12px;
            display: flex;
            justify-content: flex-end;
            page-break-inside: avoid;
            break-inside: avoid;
        }

        .totals-box {
            width: 260px;
            border: 1.5px solid #1a3a5c;
            border-radius: 3px;
            overflow: hidden;
        }

        .totals-box .row {
            display: flex;
            justify-content: space-between;
            padding: 5px 10px;
            border-bottom: 1px solid #d0d8e0;
            font-variant-numeric: tabular-nums;
            font-size: 10px;
        }

        .totals-box .row:last-child {
            border-bottom: none;
            background: #1a3a5c;
            color: #fff;
            font-weight: 700;
        }

        .totals-box .row span:last-child {
            font-weight: 700;
        }

        /* Screen-only footer; print uses @page margin boxes */
        .screen-footer {
            margin-top: 14px;
            padding-top: 6px;
            border-top: 1px solid #ccc;
            display: flex;
            justify-content: space-between;
            color: #666;
            font-size: 9px;
        }

        .empty {
            text-align: center;
            color: #666;
            padding: 20px 8px;
        }

        @media print {
            body {
                padding: 0;
                font-size: 9pt;
            }

            .no-print,
            .screen-footer {
                display: none !important;
            }

            .page-header {
                margin-bottom: 6px;
            }

            table.ledger tbody tr:nth-child(even) td,
            table.ledger tbody tr.row-payment td,
            table.ledger tbody tr.row-payment:nth-child(even) td,
            .summary-item,
            table.ledger th,
            .totals-box .row:last-child {
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }
        }

        /* Screen preview: mimic A4 landscape page frame */
        @media screen {
            body {
                background: #e8ecf0;
            }

            .sheet {
                background: #fff;
                max-width: 297mm;
                min-height: 180mm;
                margin: 0 auto;
                padding: 14mm 12mm 16mm;
                box-shadow: 0 2px 12px rgba(0, 0, 0, 0.12);
            }

            .no-print {
                max-width: 297mm;
                margin-left: auto;
                margin-right: auto;
            }
        }
    </style>
</head>
<body>
    <div class="no-print">
        <button type="button" onclick="window.print()">Chapisha / Hifadhi PDF</button>
        <button type="button" class="secondary" onclick="window.close()">Funga</button>
        <span class="hint">A4 mlalo · ukurasa hupaginate kiotomatiki · tumia Save as PDF</span>
    </div>

    <div class="sheet">
        <div class="page-header">
            <header class="letterhead">
                <div>
                    <h1 class="brand-name">{{ $shop['name'] ?? 'Shop' }}</h1>
                    <div class="brand-meta">
                        @if(!empty($shop['address']))
                            <div>{{ $shop['address'] }}</div>
                        @endif
                        @if(!empty($shop['phone']))
                            <div>Simu: {{ $shop['phone'] }}</div>
                        @endif
                    </div>
                </div>
                <div class="doc-block">
                    <h2 class="doc-title">Taarifa ya Msambazaji</h2>
                    <div class="doc-line"><span>Msambazaji:</span> <strong>{{ $supplier['name'] ?? '' }}</strong></div>
                    @if(!empty($supplier['phone']))
                        <div class="doc-line"><span>Simu:</span> {{ $supplier['phone'] }}</div>
                    @endif
                    <div class="doc-line"><span>Kipindi:</span> {{ $from }} — {{ $to }}</div>
                    <div class="doc-line"><span>Imechapishwa:</span> {{ \Carbon\Carbon::parse($printed_at)->timezone(config('app.timezone'))->format('d/m/Y H:i') }}</div>
                </div>
            </header>

            <div class="summary-bar">
                <div class="summary-item">
                    <span class="lbl">Salio la mwanzo</span>
                    <span class="val">{{ number_format($opening_balance, 0) }} TZS</span>
                </div>
                <div class="summary-item">
                    <span class="lbl">Uwasilishaji</span>
                    <span class="val">{{ number_format($totals['deliveries'], 0) }} TZS</span>
                </div>
                <div class="summary-item">
                    <span class="lbl">Malipo</span>
                    <span class="val">{{ number_format($totals['paid'], 0) }} TZS</span>
                </div>
                <div class="summary-item danger">
                    <span class="lbl">Deni lililobaki</span>
                    <span class="val">{{ number_format($totals['remaining'], 0) }} TZS</span>
                </div>
            </div>
        </div>

        <table class="ledger">
            <thead>
                <tr>
                    <th class="col-date">Tarehe</th>
                    <th class="col-person">Aliyeleta</th>
                    <th class="col-phone">Simu</th>
                    <th class="col-products">Bidhaa</th>
                    <th class="num col-qty">Idadi</th>
                    <th class="num col-jumla">Jumla</th>
                    <th class="num col-malipo">Malipo</th>
                    <th class="num col-deni">Deni</th>
                </tr>
            </thead>
            <tbody>
                @forelse($rows as $row)
                    @php
                        $jumla = (float) ($row['jumla'] ?? $row['debit'] ?? 0);
                        $malipo = (float) ($row['malipo'] ?? $row['credit'] ?? 0);
                        $qty = $row['quantity'] ?? null;
                        $deni = (float) ($row['deni'] ?? $row['balance'] ?? 0);
                        $isPayment = ($row['type'] ?? '') === 'payment';
                        $dateLabel = !empty($row['date'])
                            ? \Carbon\Carbon::parse($row['date'])->format('d/m/Y')
                            : '—';
                    @endphp
                    <tr class="{{ $isPayment ? 'row-payment' : 'row-delivery' }}">
                        <td>{{ $dateLabel }}</td>
                        <td>{{ $row['delivered_by_name'] ?: '—' }}</td>
                        <td>{{ $row['delivered_by_phone'] ?: '—' }}</td>
                        <td>
                            @if(!empty($row['products']))
                                {{ $row['products'] }}
                            @elseif($isPayment)
                                <span class="muted">{{ $row['description'] ?? 'Malipo' }}</span>
                            @else
                                —
                            @endif
                        </td>
                        <td class="num">{{ ($qty !== null && (int) $qty > 0) ? number_format((int) $qty) : '—' }}</td>
                        <td class="num">{{ $jumla > 0 ? number_format($jumla, 0).' TZS' : '—' }}</td>
                        <td class="num">{{ $malipo > 0 ? number_format($malipo, 0).' TZS' : '—' }}</td>
                        <td class="num deni">{{ number_format($deni, 0) }} TZS</td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="8" class="empty">Hakuna miamala katika kipindi hiki</td>
                    </tr>
                @endforelse
            </tbody>
        </table>

        <div class="totals-wrap">
            <div class="totals-box">
                <div class="row">
                    <span>Jumla ya uwasilishaji</span>
                    <span>{{ number_format($totals['deliveries'], 0) }} TZS</span>
                </div>
                <div class="row">
                    <span>Jumla ya malipo</span>
                    <span>{{ number_format($totals['paid'], 0) }} TZS</span>
                </div>
                <div class="row">
                    <span>Deni lililobaki</span>
                    <span>{{ number_format($totals['remaining'], 0) }} TZS</span>
                </div>
            </div>
        </div>

        <div class="screen-footer">
            <div>{{ $shop['name'] ?? 'Shop' }} · Taarifa ya msambazaji</div>
            <div>{{ \Carbon\Carbon::parse($printed_at)->timezone(config('app.timezone'))->format('d/m/Y H:i') }}</div>
        </div>
    </div>
</body>
</html>
