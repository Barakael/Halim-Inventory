import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../sales/domain/entities/sale_entity.dart';

/// Builds an A4 sales report PDF for the selected period.
Future<Uint8List> buildSalesReportPdf({
  required AppStrings t,
  required String periodLabel,
  required List<SaleEntity> sales,
  required double revenue,
  required int txCount,
  required double avg,
  required List<({String method, double total})> payments,
}) async {
  final doc = pw.Document();
  final generated = DateFormat('dd MMM yyyy · HH:mm').format(DateTime.now());
  final navy = PdfColor.fromInt(0xFF1E3A5F);
  final teal = PdfColor.fromInt(0xFF00C896);
  final muted = PdfColor.fromInt(0xFF64748B);
  final border = PdfColor.fromInt(0xFFE8EDF5);

  String payLabel(String raw) {
    final key = raw.toLowerCase().trim();
    if (key.isEmpty || key == 'other') return t.otherPayment;
    if (key == 'cash') return t.cash;
    if (key == 'card') return t.card;
    if (key.contains('mobile')) return t.mobileMoney;
    if (key == 'credit') return t.creditDebtBook;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Tera POS — ${t.reports}',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: navy,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${t.reportPeriod}: $periodLabel  ·  ${t.generatedAt}: $generated',
            style: pw.TextStyle(fontSize: 10, color: muted),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: border, thickness: 1),
          pw.SizedBox(height: 8),
        ],
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${ctx.pageNumber} / ${ctx.pagesCount}',
          style: pw.TextStyle(fontSize: 9, color: muted),
        ),
      ),
      build: (ctx) => [
        pw.Text(
          t.summary,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: navy,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            _statBox(t.totalRevenue, CurrencyFormatter.format(revenue), navy, teal),
            pw.SizedBox(width: 10),
            _statBox(t.transactions, '$txCount', navy, teal),
            pw.SizedBox(width: 10),
            _statBox(
              t.avgTransaction,
              CurrencyFormatter.format(avg),
              navy,
              teal,
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          t.paymentMethods,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: navy,
          ),
        ),
        pw.SizedBox(height: 8),
        if (payments.isEmpty)
          pw.Text(t.noPaymentData,
              style: pw.TextStyle(fontSize: 10, color: muted))
        else
          pw.TableHelper.fromTextArray(
            headers: [t.method, t.amount],
            data: payments
                .map((p) => [
                      payLabel(p.method),
                      CurrencyFormatter.format(p.total),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 10,
            ),
            headerDecoration: pw.BoxDecoration(color: navy),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {1: pw.Alignment.centerRight},
            border: pw.TableBorder.all(color: border, width: 0.5),
          ),
        pw.SizedBox(height: 20),
        pw.Text(
          t.transactionHistory,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: navy,
          ),
        ),
        pw.SizedBox(height: 8),
        if (sales.isEmpty)
          pw.Text(t.noTransactionsPeriod,
              style: pw.TextStyle(fontSize: 10, color: muted))
        else
          pw.TableHelper.fromTextArray(
            headers: [t.receiptNo, t.dateTime, t.method, t.amount],
            data: sales.map((s) {
              final id = s.serialNumber.isNotEmpty
                  ? s.serialNumber
                  : '#${s.id}';
              return [
                id,
                DateFormat('dd MMM yyyy HH:mm').format(s.createdAt),
                payLabel(s.paymentMethod),
                CurrencyFormatter.format(s.total),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9,
            ),
            headerDecoration: pw.BoxDecoration(color: navy),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(color: border, width: 0.4),
          ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _statBox(
  String label,
  String value,
  PdfColor navy,
  PdfColor accent,
) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE8EDF5)),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 8, color: PdfColor.fromInt(0xFF64748B))),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: navy,
            ),
          ),
        ],
      ),
    ),
  );
}
