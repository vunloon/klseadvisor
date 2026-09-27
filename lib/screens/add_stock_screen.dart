import 'package:flutter/material.dart';

import '../models/stock_quote.dart';
import '../services/yahoo_finance_service.dart';
import 'stock_detail_screen.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _controller = TextEditingController();
  final _yahoo = YahooFinanceService();
  List<StockQuote>? _results;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _yahoo.search(query);
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _results = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add KLSE Stock')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Company name or code (e.g. Maybank, 1155)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _search(_controller.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text('Add "${_controller.text.trim().toUpperCase()}" directly'),
                onPressed: _controller.text.trim().isEmpty
                    ? null
                    : () => _openDetail(_controller.text.trim().toUpperCase()),
              ),
            ),
          ),
          const Divider(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!,
                            style: TextStyle(color: scheme.error),
                            textAlign: TextAlign.center),
                      )
                    : _results == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.manage_search,
                                    size: 44, color: scheme.onSurfaceVariant),
                                const SizedBox(height: 8),
                                Text(
                                  'Search Yahoo Finance for Bursa Malaysia stocks.\nTap a result to view details.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : _results!.isEmpty
                            ? const Center(child: Text('No results found'))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                itemCount: _results!.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final q = _results![i];
                                  final symbol = q.symbol;
                                  final isKl = symbol.endsWith('.KL');
                                  return Card(
                                    margin: EdgeInsets.zero,
                                    child: ListTile(
                                      dense: true,
                                      title: Text(
                                        q.shortName ?? symbol,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Text(symbol),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isKl
                                              ? scheme.primary.withOpacity(0.14)
                                              : scheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          isKl ? 'KLSE' : (q.exchange ?? ''),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isKl
                                                ? scheme.primary
                                                : scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      onTap: () => _openDetail(symbol),
                                    ),
                                  );
                                },
                              ),
          ),
        ],
      ),
    );
  }

  void _openDetail(String symbol) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StockDetailScreen(symbol: symbol)),
    );
  }
}
