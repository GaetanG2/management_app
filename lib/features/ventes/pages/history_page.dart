import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

import '../../articles/providers/article_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/vente_provider.dart';
import '../../../data/models/vente.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  DateTimeRange? _range;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
    final end = now;
    final r = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDateRange: _range ?? DateTimeRange(start: start, end: end));
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    final ventes = ref.watch(ventesListProvider);
    final articles = ref.watch(articlesNotifierProvider);

    // lookup
    final artMap = {for (final a in articles) a.id: a};

    return FutureBuilder<List>(
      future: ref.read(authProvider.notifier).getUsers(),
      builder: (context, usersSnap) {
        final users = usersSnap.data ?? [];
        final userMap = {for (final u in users) u.id: u};

        final filtered = _range == null
            ? ventes
            : ventes.where((v) {
                final d = DateTime.fromMillisecondsSinceEpoch(v.createdAt).toLocal();
                return !d.isBefore(_range!.start) && !d.isAfter(_range!.end);
              }).toList();

        // group by sale_id
        final Map<String, List<Vente>> grouped = {};
        for (final v in filtered) {
          final key = v.saleId ?? v.id;
          grouped.putIfAbsent(key, () => []).add(v);
        }

        final keys = grouped.keys.toList()..sort((a, b) => grouped[b]!.first.createdAt.compareTo(grouped[a]!.first.createdAt));

        // totals
        double totalSales = 0;
        double totalProfit = 0;
        for (final g in grouped.values) {
          for (final v in g) {
            totalSales += v.total;
            final art = artMap[v.articleId];
            if (art != null) totalProfit += v.total - (art.buyPrice * v.qty);
          }
        }

        return Scaffold(
          // AppBar removed to keep UI minimal; header is provided in the body
          body: Padding(
            padding: EdgeInsets.all(AppTheme.defaultPadding),
            child: Column(
              children: [
                // stylized header (theme)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
                  child: Row(children: [
                    const Icon(Icons.history, size: 28, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Historique des ventes', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Liste des ventes et détails', style: Theme.of(context).textTheme.bodySmall),
                    ])
                  ]),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        ElevatedButton.icon(onPressed: _pickRange, icon: const Icon(Icons.date_range), label: const Text('Filtrer')),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_range == null ? 'Période: Toutes' : 'Période: ${_range!.start.toLocal().toString().split(' ').first} → ${_range!.end.toLocal().toString().split(' ').first}', overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Total: ${totalSales.toStringAsFixed(2)}'), Text('Bénéfice: ${totalProfit.toStringAsFixed(2)}')])
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: keys.isEmpty
                      ? const Center(child: Text('Aucune vente trouvée'))
                      : ListView.separated(
                          itemCount: keys.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final key = keys[index];
                            final group = grouped[key]!;
                            final first = group.first;
                            final date = DateTime.fromMillisecondsSinceEpoch(first.createdAt).toLocal();
                            final sellerName = userMap[first.userId]?.name ?? 'Inconnu';
                            final groupTotal = group.fold<double>(0, (s, e) => s + e.total);
                            final groupProfit = group.fold<double>(0, (s, e) => s + (e.total - ((artMap[e.articleId]?.buyPrice ?? 0) * e.qty)));

                            return Card(
                              elevation: 2,
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Expanded(child: Text('${date.toString().split('.').first} - $sellerName', overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 12),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Total: ${groupTotal.toStringAsFixed(2)}'), Text('Bénéfice: ${groupProfit.toStringAsFixed(2)}')])
                                ]),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                    child: Column(
                                      children: group
                                          .map(
                                            (v) => Row(
                                              children: [
                                                Expanded(child: Text(artMap[v.articleId]?.name ?? 'Unknown', overflow: TextOverflow.ellipsis)),
                                                const SizedBox(width: 8),
                                                Text('Qté: ${v.qty}'),
                                                const SizedBox(width: 16),
                                                Text((v.total).toStringAsFixed(2)),
                                              ],
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                  OverflowBar(
                                    overflowSpacing: 8,
                                    children: [
                                      TextButton(
                                          onPressed: () async {
                                            // delete sale
                                            await ref.read(venteRepositoryProvider).deleteBySaleId(key);
                                            await ref.read(ventesListProvider.notifier).load();
                                          },
                                          child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
                                    ],
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
