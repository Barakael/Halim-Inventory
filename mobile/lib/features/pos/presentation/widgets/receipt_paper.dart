import 'package:flutter/material.dart';

import 'receipt_content.dart';

/// On-screen thermal slip — same column grammar as the printed ticket.
class ReceiptPaper extends StatelessWidget {
  const ReceiptPaper({super.key, required this.content});

  final ReceiptContent content;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF111111);
    const muted = Color(0xFF5A5A5A);

    TextStyle body([double size = 11.5]) => TextStyle(
          fontSize: size,
          height: 1.25,
          color: ink,
          fontWeight: FontWeight.w400,
        );
    TextStyle bold([double size = 11.5]) => TextStyle(
          fontSize: size,
          height: 1.25,
          color: ink,
          fontWeight: FontWeight.w800,
        );

    Widget centered(String text, TextStyle style) => Text(
          text,
          textAlign: TextAlign.center,
          style: style,
        );

    Widget rule({bool heavy = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            height: heavy ? 2 : 1,
            color: heavy ? ink : const Color(0xFFCCCCCC),
          ),
        );

    Widget kv(ReceiptKv row, {bool emphasize = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  row.label,
                  style: emphasize
                      ? bold(12)
                      : body(11.5).copyWith(color: muted),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: Text(
                  row.value,
                  textAlign: TextAlign.right,
                  style: emphasize ? bold(12.5) : body(11.5),
                ),
              ),
            ],
          ),
        );

    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE6E0D4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (content.shopName.isNotEmpty) ...[
            centered(content.shopName, bold(16)),
            const SizedBox(height: 4),
          ],
          ...content.letterhead.map((line) => centered(line, body(12))),
          if (content.shopFacts.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...content.shopFacts.map(kv),
          ],
          rule(),
          ...content.identifiers.map(kv),
          if (content.customer.isNotEmpty) ...[
            rule(),
            centered('CUSTOMER', bold(11)),
            const SizedBox(height: 4),
            ...content.customer.map(kv),
          ],
          rule(heavy: true),
          Row(
            children: [
              SizedBox(width: 36, child: Text('QTY', style: bold(10.5))),
              Expanded(child: Text('DESCRIPTION', style: bold(10.5))),
              Text('AMOUNT', style: bold(10.5)),
            ],
          ),
          rule(),
          if (content.items.isEmpty)
            centered('(No line items)', body(12))
          else
            ...content.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(item.qty, style: body(12)),
                        ),
                        Expanded(
                          child: Text(item.name, style: body(12)),
                        ),
                        const SizedBox(width: 8),
                        Text(item.amount, style: bold(12)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 36, top: 2),
                      child: Text(
                        '@ ${item.unitPrice}',
                        style: body(10.5).copyWith(color: muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          rule(),
          ...content.totals.map(kv),
          rule(heavy: true),
          kv(ReceiptKv('TOTAL', content.grandTotal), emphasize: true),
          rule(),
          ...content.payment.map(kv),
          rule(),
          centered('Thank you for your purchase', body(11)),
        ],
      ),
    );
  }
}
