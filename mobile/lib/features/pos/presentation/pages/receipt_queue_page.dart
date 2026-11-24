import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../sales/data/models/sale_model.dart';
import '../widgets/receipt_dialog.dart';

class ReceiptQueuePage extends StatefulWidget {
  const ReceiptQueuePage({super.key, required this.canPrint});

  final bool canPrint;

  @override
  State<ReceiptQueuePage> createState() => _ReceiptQueuePageState();
}

class _ReceiptQueuePageState extends State<ReceiptQueuePage> {
  final ApiClient _api = sl<ApiClient>();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _jobs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = await _api.get<List<Map<String, dynamic>>>(
        endpoint: ApiEndpoints.receiptJobs,
        parser: (json) {
          final list = json is List ? json : const [];
          return list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        },
      );
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _open(Map<String, dynamic> job) async {
    final id = job['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      final payload = await _api.get<Map<String, dynamic>>(
        endpoint: ApiEndpoints.receiptJob(id),
        parser: (json) => Map<String, dynamic>.from(json as Map),
      );
      final saleRaw = payload['sale'];
      if (saleRaw is! Map) {
        throw StateError('Receipt has no sale');
      }
      final sale = SaleModel.fromLaravelJson(
        Map<String, dynamic>.from(saleRaw),
      ).toEntity();
      final allowPrint = widget.canPrint && payload['can_print'] != false;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ReceiptDialog(
          sale: sale,
          shop: sale.shop,
          allowPrint: allowPrint,
          onPrinted: allowPrint ? () => _markPrinted(id) : null,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open receipt: $e')),
      );
    }
  }

  Future<void> _markPrinted(String id) async {
    await _api.post<void>(
      endpoint: ApiEndpoints.receiptJobPrinted(id),
      data: const {},
      parser: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.canPrint ? 'Receipt queue' : 'Receipts'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _jobs.isEmpty
                  ? const Center(child: Text('No receipts yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _jobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final job = _jobs[i];
                        final printed = job['status'] == 'printed';
                        final when = DateTime.tryParse(
                          job['created_at']?.toString() ?? '',
                        );
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          title: Text(
                            job['serial_number']?.toString() ??
                                'Sale ${job['sale_id']}',
                          ),
                          subtitle: Text(
                            [
                              if (when != null)
                                DateFormat('dd/MM HH:mm').format(when.toLocal()),
                              job['customer_name']?.toString() ?? 'Walk-in',
                              job['payment_method']?.toString() ?? '',
                              CurrencyFormatter.format(
                                (job['amount'] as num?) ?? 0,
                              ),
                            ].where((s) => s.isNotEmpty).join(' · '),
                          ),
                          trailing: widget.canPrint
                              ? FilledButton(
                                  onPressed: () => _open(job),
                                  child: Text(printed ? 'Print again' : 'Print'),
                                )
                              : OutlinedButton(
                                  onPressed: () => _open(job),
                                  child: const Text('View'),
                                ),
                        );
                      },
                    ),
    );
  }
}
