import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_quote.dart';
import '../providers/watchlist_provider.dart';
import '../util/format.dart';
import 'add_stock_screen.dart';
import 'stock_detail_screen.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WatchlistProvider>();
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            title: const Text('KLSE Advisor'),
            backgroundColor: scheme.surface,
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add stock',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddStockScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => context.read<WatchlistProvider>().refresh(),
              ),
              const SizedBox(width: 4),
            ],
          ),
          if (wp.index != null)
            SliverToBoxAdapter(child: _IndexCard(quote: wp.index!)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    'My Watchlist',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  if (wp.lastUpdated != null && wp.status == WatchlistStatus.ready)
                    Text(
                      'Updated ${TimeOfDay.fromDateTime(wp.lastUpdated!).format(context)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          _buildBody(context, wp),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, WatchlistProvider wp) {
    if (wp.status == WatchlistStatus.loading && wp.symbols.isEmpty) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => const _QuoteSkeleton(),
          childCount: 6,
        ),
      );
    }
    if (wp.status == WatchlistStatus.error) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(
                wp.error ?? 'Failed to load quotes',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => context.read<WatchlistProvider>().refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (wp.symbols.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.playlist_add,
                  size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              const Text('Your watchlist is empty.\nTap + to add KLSE stocks.',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return SliverList.separated(
      itemCount: wp.symbols.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final symbol = wp.symbols[i];
        final quote = wp.quote(symbol);
        return _QuoteCard(symbol: symbol, quote: quote);
      },
    );
  }
}

class _IndexCard extends StatelessWidget {
  final StockQuote quote;

  const _IndexCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final up = (quote.changePercent ?? 0) >= 0;
    final color = up ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primary.withOpacity(0.12), scheme.tertiary.withOpacity(0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FTSE Bursa Malaysia KLCI',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  quote.price?.toStringAsFixed(2) ?? '--',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmtPct(quote.changePercent),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                  Text(
                    '${(quote.change ?? 0) >= 0 ? '+' : ''}${quote.change?.toStringAsFixed(2) ?? '--'}',
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final String symbol;
  final StockQuote? quote;

  const _QuoteCard({required this.symbol, required this.quote});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = quote?.displayName ?? symbol;
    final price = quote?.price;
    final changePct = quote?.changePercent;
    final up = (changePct ?? 0) > 0;
    final down = (changePct ?? 0) < 0;
    final color = up
        ? const Color(0xFF16A34A)
        : down
            ? const Color(0xFFDC2626)
            : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => StockDetailScreen(symbol: symbol)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        symbol.replaceAll('.KL', ''),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (quote == null)
                  const SizedBox(
                    width: 60,
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                else ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price?.toStringAsFixed(2) ?? '--',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          fmtPct(changePct),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuoteSkeleton extends StatelessWidget {
  const _QuoteSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
