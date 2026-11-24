import 'package:flutter/material.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/currency_formatter.dart';

class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  State<SuperAdminDashboardPage> createState() =>
      _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  final ApiClient _api = sl<ApiClient>();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

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
      final data = await _api.get<Map<String, dynamic>>(
        endpoint: ApiEndpoints.dashboardSuper,
        parser: (json) => Map<String, dynamic>.from(json as Map),
      );
      if (!mounted) return;
      setState(() {
        _data = data;
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

  @override
  Widget build(BuildContext context) {
    final sales = Map<String, dynamic>.from(
      (_data['sales_today'] as Map?) ?? const {},
    );
    final split = Map<String, dynamic>.from(
      (sales['payment_split'] as Map?) ?? const {},
    );
    final suppliers = ((_data['suppliers'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final supplierDebts = ((_data['supplier_debts'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final salesDebts = ((_data['sales_debts'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final statements = Map<String, dynamic>.from(
      (_data['statements'] as Map?) ?? const {},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Stat(
                      label: 'Sales today',
                      value: CurrencyFormatter.format(
                        (sales['total'] as num?) ?? 0,
                      ),
                      detail: '${sales['count'] ?? 0} sales',
                    ),
                    const SizedBox(height: 8),
                    _Stat(
                      label: 'Wasapazaji debt',
                      value: CurrencyFormatter.format(
                        (_data['supplier_debt_total'] as num?) ?? 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Stat(
                      label: 'Sales debt',
                      value: CurrencyFormatter.format(
                        (_data['sales_debt_total'] as num?) ?? 0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payment split today',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (split.isEmpty)
                      const Text('No sales yet today.')
                    else
                      ...split.entries.map(
                        (e) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(e.key),
                          trailing: Text(
                            CurrencyFormatter.format((e.value as num?) ?? 0),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      statements['title']?.toString() ?? 'Supplier statements',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statements['description']?.toString() ??
                          'Each supplier statement is the buying record. A delivery line shows who brought the goods, their phone, which products, the quantity, and the total. A payment line shows what was paid and when. The running balance is the deni.',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Wasapazaji',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (suppliers.isEmpty)
                      const Text('No suppliers yet.')
                    else
                      ...suppliers.map(
                        (s) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s['name']?.toString() ?? ''),
                          subtitle: Text(
                            '${s['phone'] ?? ''} · brought ${CurrencyFormatter.format((s['brought_in'] as num?) ?? 0)} · paid ${CurrencyFormatter.format((s['paid'] as num?) ?? 0)}',
                          ),
                          trailing: Text(
                            CurrencyFormatter.format((s['open_debt'] as num?) ?? 0),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Debts from wasapazaji',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ..._debtTiles(supplierDebts, empty: 'No supplier debt.'),
                    const SizedBox(height: 16),
                    Text(
                      'Debts from sales',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ..._debtTiles(salesDebts, empty: 'No sales debt.'),
                  ],
                ),
    );
  }

  List<Widget> _debtTiles(List<Map<String, dynamic>> rows, {required String empty}) {
    if (rows.isEmpty) return [Text(empty)];
    return rows
        .map(
          (row) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(row['name']?.toString() ?? ''),
            subtitle: Text(row['phone']?.toString() ?? ''),
            trailing: Text(
              CurrencyFormatter.format((row['open_debt'] as num?) ?? 0),
            ),
          ),
        )
        .toList();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: detail == null ? null : Text(detail!),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
