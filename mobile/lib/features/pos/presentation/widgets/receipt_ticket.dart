import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_printer_helper/pos_printer_helper.dart';

import 'receipt_content.dart';

/// 58mm shop ticket — PDF for share, native tables for H10S,
/// ESC/POS columns for Bluetooth. Never space-pads proportional fonts.
class ReceiptTicket {
  ReceiptTicket._();

  static const _roll58 = PdfPageFormat(
    58 * PdfPageFormat.mm,
    double.infinity,
    marginLeft: 2.5 * PdfPageFormat.mm,
    marginRight: 2.5 * PdfPageFormat.mm,
    marginTop: 3 * PdfPageFormat.mm,
    marginBottom: 8 * PdfPageFormat.mm,
  );

  static Future<Uint8List> buildPdf(ReceiptContent c) async {
    final doc = pw.Document();
    const ink = PdfColors.black;
    const muted = PdfColor.fromInt(0xFF444444);

    pw.TextStyle body([double size = 8]) => pw.TextStyle(
          fontSize: size,
          color: ink,
          lineSpacing: 1.15,
        );
    pw.TextStyle bold([double size = 8]) => pw.TextStyle(
          fontSize: size,
          fontWeight: pw.FontWeight.bold,
          color: ink,
          lineSpacing: 1.15,
        );

    pw.Widget rule({bool heavy = false}) => pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
          height: heavy ? 1.4 : 0.5,
          color: ink,
        );

    pw.Widget kv(ReceiptKv row, {bool emphasize = false}) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 1.5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Text(
                  row.label,
                  style: emphasize ? bold(8) : body(8).copyWith(color: muted),
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                flex: 6,
                child: pw.Text(
                  row.value,
                  textAlign: pw.TextAlign.right,
                  style: emphasize ? bold(8.5) : body(8),
                ),
              ),
            ],
          ),
        );

    pw.Widget centered(String text, pw.TextStyle style) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(text, textAlign: pw.TextAlign.center, style: style),
        );

    doc.addPage(
      pw.Page(
        pageFormat: _roll58,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            centered('RECEIPT', bold(7.5)),
            rule(heavy: true),
            if (c.shopName.isNotEmpty) ...[
              centered(c.shopName, bold(12)),
              pw.SizedBox(height: 2),
            ],
            ...c.letterhead.map((line) => centered(line, body(8))),
            if (c.shopFacts.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              ...c.shopFacts.map(kv),
            ],
            rule(),
            ...c.identifiers.map(kv),
            if (c.customer.isNotEmpty) ...[
              rule(),
              centered('CUSTOMER', bold(8)),
              pw.SizedBox(height: 2),
              ...c.customer.map(kv),
            ],
            rule(heavy: true),
            pw.Row(
              children: [
                pw.SizedBox(
                  width: 28,
                  child: pw.Text('QTY', style: bold(7.5)),
                ),
                pw.Expanded(child: pw.Text('DESCRIPTION', style: bold(7.5))),
                pw.Text('AMOUNT', style: bold(7.5)),
              ],
            ),
            rule(),
            if (c.items.isEmpty)
              centered('(No line items)', body(8))
            else
              ...c.items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.SizedBox(
                            width: 28,
                            child: pw.Text(item.qty, style: body(8)),
                          ),
                          pw.Expanded(
                            child: pw.Text(item.name, style: body(8)),
                          ),
                          pw.SizedBox(width: 4),
                          pw.Text(item.amount, style: bold(8)),
                        ],
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 28, top: 1),
                        child: pw.Text(
                          '@ ${item.unitPrice}',
                          style: body(7).copyWith(color: muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            rule(),
            ...c.totals.map(kv),
            rule(heavy: true),
            kv(ReceiptKv('TOTAL', c.grandTotal), emphasize: true),
            rule(),
            ...c.payment.map(kv),
            rule(),
            centered('Thank you', bold(7.5)),
            centered('Welcome again', body(7)),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static Future<void> printH10S(ReceiptContent c) async {
    Future<void> center(String text, {double size = 20, bool bold = false}) async {
      await PosPrinterPlugin.setAlign(Alignments.center);
      await PosPrinterPlugin.printText('$text\n', size, bold, false);
    }

    Future<void> left(String text, {double size = 20, bool bold = false}) async {
      await PosPrinterPlugin.setAlign(Alignments.left);
      await PosPrinterPlugin.printText('$text\n', size, bold, false);
    }

    Future<void> kv(String label, String value, {bool bold = false}) async {
      await PosPrinterPlugin.setAlign(Alignments.left);
      await PosPrinterPlugin.printTable(
        [label, value],
        [1, 1],
        [0, 2],
        bold ? 22 : 20,
      );
    }

    Future<void> rule({bool heavy = false}) async {
      await center(heavy ? '================================' : '--------------------------------', size: 18);
    }

    await PosPrinterPlugin.start();

    await center('RECEIPT', size: 18, bold: true);
    await rule(heavy: true);
    if (c.shopName.isNotEmpty) {
      await center(c.shopName, size: 28, bold: true);
    }
    for (final line in c.letterhead) {
      await center(line, size: 20);
    }
    if (c.shopFacts.isNotEmpty) {
      await PosPrinterPlugin.feedPaper(1);
      for (final row in c.shopFacts) {
        await kv(row.label, row.value);
      }
    }
    await rule();
    for (final row in c.identifiers) {
      await kv(row.label, row.value);
    }
    if (c.customer.isNotEmpty) {
      await rule();
      await center('CUSTOMER', size: 20, bold: true);
      for (final row in c.customer) {
        await kv(row.label, row.value);
      }
    }
    await rule(heavy: true);
    await PosPrinterPlugin.setAlign(Alignments.left);
    await PosPrinterPlugin.printTable(
      ['QTY', 'ITEM', 'AMOUNT'],
      [1, 3, 2],
      [0, 0, 2],
      20,
    );
    await rule();
    if (c.items.isEmpty) {
      await center('(No line items)', size: 20);
    } else {
      for (final item in c.items) {
        await PosPrinterPlugin.setAlign(Alignments.left);
        await PosPrinterPlugin.printTable(
          [item.qty, _clip(item.name, 18), item.amount],
          [1, 3, 2],
          [0, 0, 2],
          22,
        );
        await left('     @ ${item.unitPrice}', size: 18);
      }
    }
    await rule();
    for (final row in c.totals) {
      await kv(row.label, row.value);
    }
    await rule(heavy: true);
    await kv('TOTAL', c.grandTotal, bold: true);
    await rule();
    for (final row in c.payment) {
      await kv(row.label, row.value);
    }
    await rule();
    await center('Thank you', size: 18, bold: true);
    await center('Welcome again', size: 18);

    await PosPrinterPlugin.feedPaper(4);
    try {
      await PosPrinterPlugin.cutPaper();
    } catch (_) {}
    await PosPrinterPlugin.release();
  }

  static Future<List<int>> buildBluetoothBytes(ReceiptContent c) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

    const left = PosStyles(align: PosAlign.left);
    const right = PosStyles(align: PosAlign.right);
    const center = PosStyles(align: PosAlign.center);
    const centerBold = PosStyles(align: PosAlign.center, bold: true);
    const leftBold = PosStyles(align: PosAlign.left, bold: true);
    const rightBold = PosStyles(align: PosAlign.right, bold: true);

    List<int> kv(String label, String value, {bool bold = false}) =>
        generator.row([
          PosColumn(
            text: _ascii(label),
            width: 6,
            styles: bold ? leftBold : left,
          ),
          PosColumn(
            text: _ascii(value),
            width: 6,
            styles: bold ? rightBold : right,
          ),
        ]);

    bytes.addAll(generator.reset());
    bytes.addAll(generator.text(
      'RECEIPT',
      styles: centerBold,
    ));
    bytes.addAll(generator.hr(ch: '='));
    if (c.shopName.isNotEmpty) {
      bytes.addAll(generator.text(_ascii(c.shopName), styles: centerBold));
    }
    for (final line in c.letterhead) {
      bytes.addAll(generator.text(_ascii(line), styles: center));
    }
    if (c.shopFacts.isNotEmpty) {
      bytes.addAll(generator.feed(1));
      for (final row in c.shopFacts) {
        bytes.addAll(kv(row.label, row.value));
      }
    }
    bytes.addAll(generator.hr());
    for (final row in c.identifiers) {
      bytes.addAll(kv(row.label, row.value));
    }
    if (c.customer.isNotEmpty) {
      bytes.addAll(generator.hr());
      bytes.addAll(generator.text('CUSTOMER', styles: centerBold));
      for (final row in c.customer) {
        bytes.addAll(kv(row.label, row.value));
      }
    }
    bytes.addAll(generator.hr(ch: '='));
    bytes.addAll(generator.row([
      PosColumn(text: 'QTY', width: 2, styles: leftBold),
      PosColumn(text: 'ITEM', width: 6, styles: leftBold),
      PosColumn(text: 'AMOUNT', width: 4, styles: rightBold),
    ]));
    bytes.addAll(generator.hr());
    if (c.items.isEmpty) {
      bytes.addAll(generator.text('(No line items)', styles: center));
    } else {
      for (final item in c.items) {
        bytes.addAll(generator.row([
          PosColumn(text: _ascii(item.qty), width: 2, styles: left),
          PosColumn(text: _ascii(_clip(item.name, 16)), width: 6, styles: left),
          PosColumn(text: _ascii(item.amount), width: 4, styles: rightBold),
        ]));
        bytes.addAll(generator.text(
          '  @ ${_ascii(item.unitPrice)}',
          styles: left,
        ));
      }
    }
    bytes.addAll(generator.hr());
    for (final row in c.totals) {
      bytes.addAll(kv(row.label, row.value));
    }
    bytes.addAll(generator.hr(ch: '='));
    bytes.addAll(kv('TOTAL', c.grandTotal, bold: true));
    bytes.addAll(generator.hr());
    for (final row in c.payment) {
      bytes.addAll(kv(row.label, row.value));
    }
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(
      'Thank you',
      styles: centerBold,
    ));
    bytes.addAll(generator.text(
      'Welcome again',
      styles: center,
    ));
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    return bytes;
  }

  static String _clip(String value, int max) {
    final t = value.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 3)}...';
  }

  static String _ascii(String value) => value
      .replaceAll('…', '...')
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"');
}
