import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

import '../../articles/providers/article_provider.dart';
import '../../articles/providers/category_provider.dart';
import '../providers/vente_provider.dart';
import '../../../data/models/vente.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  // active (applied) filters
  DateTimeRange? _range;
  String? _selectedCategory;
  String _articleQuery = '';

  // pending filters (edited in UI until 'Appliquer' is pressed)
  DateTimeRange? _pendingRange;
  String? _pendingSelectedCategory;
  final TextEditingController _searchController = TextEditingController();

  // sorting for table
  int? _sortColumnIndex;
  bool _sortAscending = false;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
    final end = now;
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range ?? DateTimeRange(start: start, end: end),
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
            child: Material(
              elevation: 8,
              color: Theme.of(context).dialogTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: child,
            ),
          ),
        );
      },
    );
    if (r != null) {
      if (!mounted) return;
      setState(() => _pendingRange = r);
    }
  }

  void _resetFilters() {
    setState(() {
      _range = null;
      _selectedCategory = null;
      _articleQuery = '';
      // reset pendings as well
      _pendingRange = null;
      _pendingSelectedCategory = null;
      _searchController.text = '';
      _sortColumnIndex = null;
      _sortAscending = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _pendingSelectedCategory = _selectedCategory;
    _pendingRange = _range;
    _searchController.text = _articleQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final articles = ref.watch(articlesNotifierProvider);
    final categories = ref.watch(categoriesNotifierProvider);
    final venteRepo = ref.read(venteRepositoryProvider);

    return FutureBuilder<List<Vente>>(
      future: venteRepo.getAll(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final ventesAll = snap.data ?? [];

        // apply active filters to ventes
        List<Vente> ventes = ventesAll;
        if (_range != null) {
          ventes = ventes.where((v) {
            final d = DateTime.fromMillisecondsSinceEpoch(v.createdAt).toLocal();
            return !d.isBefore(_range!.start) && !d.isAfter(_range!.end);
          }).toList();
        }

        if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
          final allowedIds = articles.where((a) => a.category == _selectedCategory).map((a) => a.id).toSet();
          ventes = ventes.where((v) => allowedIds.contains(v.articleId)).toList();
        }

        if (_articleQuery.isNotEmpty) {
          final matched = articles.where((a) => a.name.toLowerCase().contains(_articleQuery.toLowerCase())).map((a) => a.id).toSet();
          ventes = ventes.where((v) => matched.contains(v.articleId)).toList();
        }

        // compute stats from filtered ventes
        final Map<String, int> ventesParJour = {};
        final Map<String, double> recettesParJour = {};
        final Map<String, double> beneficesParJour = {};

        final Map<String, double> articleTotals = {};
        final Map<String, int> articleCounts = {};

        final Map<String, int> stockByCategory = {};

        for (final a in articles) {
          stockByCategory[a.category] = (stockByCategory[a.category] ?? 0) + a.quantity;
        }

        double totalRecettes = 0;
        double totalProfit = 0;

        for (final v in ventes) {
          final d = DateTime.fromMillisecondsSinceEpoch(v.createdAt);
          final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          ventesParJour[key] = (ventesParJour[key] ?? 0) + 1;
          recettesParJour[key] = (recettesParJour[key] ?? 0) + v.total;

          final found = articles.where((aa) => aa.id == v.articleId);
          if (found.isNotEmpty) {
            final art = found.first;
            final cost = art.buyPrice * v.qty;
            final profit = v.total - cost;
            beneficesParJour[key] = (beneficesParJour[key] ?? 0) + profit;

            articleTotals[art.name] = (articleTotals[art.name] ?? 0) + v.total;
            articleCounts[art.name] = (articleCounts[art.name] ?? 0) + v.qty;

            totalRecettes += v.total;
            totalProfit += profit;
          } else {
            totalRecettes += v.total;
          }
        }

        final totalVentesCount = ventes.length;

        // top 10 articles for visuals
        final topArticles = articleCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final top10 = topArticles.take(10).toList();

        int maxCount = 1;
        for (final e in top10) {
          if (e.value > maxCount) maxCount = e.value;
        }

        // prepare category list for dropdown
        final categoryNames = categories.map((c) => c.name).toSet().toList()..sort();

        // prepare table rows will be computed where needed (table rendering)

        return Scaffold(
          body: Padding(
            padding: EdgeInsets.all(AppTheme.defaultPadding),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
                    child: Row(children: [
                      const Icon(Icons.bar_chart, size: 28, color: Colors.indigo),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Statistiques', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Résumé des ventes et performances', style: Theme.of(context).textTheme.bodySmall),
                      ])
                    ]),
                  ),

                  const SizedBox(height: 12),

                  // Filters row (edit pending filters, Apply to activate)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(children: [
                        Row(children: [
                          ElevatedButton.icon(onPressed: _pickRange, icon: const Icon(Icons.date_range), label: const Text('Période')),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_range == null ? 'Période active: Toutes' : 'Période active: ${_range!.start.toLocal().toString().split(' ').first} → ${_range!.end.toLocal().toString().split(' ').first}', overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(_pendingRange == null ? 'Période sélectionnée: Toutes' : 'Période sélectionnée: ${_pendingRange!.start.toLocal().toString().split(' ').first} → ${_pendingRange!.end.toLocal().toString().split(' ').first}', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ]),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String?>(
                            value: _pendingSelectedCategory,
                            hint: const Text('Catégorie'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Toutes')),
                              ...categoryNames.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c)))
                            ],
                            onChanged: (v) => setState(() => _pendingSelectedCategory = v),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher un article (nom)'),
                              controller: _searchController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                              onPressed: () => setState(() {
                                    // apply pending filters
                                    _range = _pendingRange;
                                    _selectedCategory = _pendingSelectedCategory;
                                    _articleQuery = _searchController.text.trim();
                                  }),
                              child: const Text('Appliquer')),
                          const SizedBox(width: 8),
                          OutlinedButton(onPressed: _resetFilters, child: const Text('Réinitialiser')),
                        ])
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),

                  // summary cards using Wrap for responsiveness
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 800 ? double.infinity : (MediaQuery.of(context).size.width - 48) / 3,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Ventes totales', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('$totalVentesCount', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 800 ? double.infinity : (MediaQuery.of(context).size.width - 48) / 3,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Recettes (total)', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(totalRecettes.toStringAsFixed(2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 800 ? double.infinity : (MediaQuery.of(context).size.width - 48) / 3,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Bénéfice estimé', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(totalProfit.toStringAsFixed(2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),
                  const Text('Top articles (par quantité vendue)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  top10.isEmpty
                      ? const Text('Aucun')
                      : Column(
                          children: top10
                              .map((e) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis)),
                                        const SizedBox(width: 8),
                                        SizedBox(width: 80, child: Text('${e.value}')),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: LinearProgressIndicator(value: e.value / maxCount.toDouble()),
                                        )
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),

                  const SizedBox(height: 16),
                  const Text('Recettes par jour (extrait)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  recettesParJour.isEmpty
                      ? const Text('Aucune donnée')
                      : LayoutBuilder(builder: (ctx, cons) {
                          // show last up to 14 days sorted
                          final entries = recettesParJour.entries.toList()
                            ..sort((a, b) => a.key.compareTo(b.key));
                          final last = entries.length <= 14 ? entries : entries.sublist(entries.length - 14);
                          final maxVal = last.map((e) => e.value).fold<double>(0, (p, n) => n > p ? n : p);
                          final barMaxHeight = 160.0;
                          return SizedBox(
                            height: barMaxHeight + 40,
                            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: last.map((e) {
                              final h = maxVal <= 0 ? 0.0 : (e.value / maxVal) * barMaxHeight;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                    Tooltip(message: e.value.toStringAsFixed(2), child: Container(height: h, width: double.infinity, decoration: BoxDecoration(color: Colors.indigo.shade400, borderRadius: BorderRadius.circular(4)))) ,
                                    const SizedBox(height: 6),
                                    Text(e.key.split('-').sublist(1).join('-'), style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                                  ]),
                                ),
                              );
                            }).toList()),
                          );
                        }),

                  const SizedBox(height: 16),
                  const Text('Stock par catégorie', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  stockByCategory.isEmpty
                      ? const Text('Aucun')
                      : LayoutBuilder(builder: (ctx, cons) {
                          final entries = stockByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                          final top = entries.length <= 8 ? entries : entries.sublist(0, 8);
                          final maxStock = top.map((e) => e.value).fold<int>(1, (p, n) => n > p ? n : p);
                          return Column(children: top.map((e) {
                            final frac = maxStock <= 0 ? 0.0 : e.value / maxStock;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Row(children: [
                                Expanded(flex: 2, child: Text(e.key, overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 8),
                                Expanded(flex: 5, child: LinearProgressIndicator(value: frac, minHeight: 14, color: Colors.teal, backgroundColor: Colors.teal.shade100)),
                                const SizedBox(width: 8),
                                SizedBox(width: 48, child: Text('${e.value}')),
                              ]),
                            );
                          }).toList());
                        }),

                  const SizedBox(height: 16),
                  const Text('Top articles - tableau récapitulatif', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  // DataTable showing top articles with qty and total
                  () {
                    final rows = articleCounts.entries.map((entry) {
                      final name = entry.key;
                      final qty = entry.value;
                      final total = articleTotals[name] ?? 0.0;
                      return {'name': name, 'qty': qty, 'total': total};
                    }).toList()
                      ..sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
                    final topRows = rows.take(10).toList();
                    if (topRows.isEmpty) return const Text('Aucun');
                    return Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          columns: [
                            const DataColumn(label: Text('Article')),
                            DataColumn(label: const Text('Qté vendue'), numeric: true, onSort: (colIndex, asc) {
                              setState(() {
                                if (_sortColumnIndex == colIndex) {
                                  _sortAscending = !_sortAscending;
                                } else {
                                  _sortColumnIndex = colIndex;
                                  _sortAscending = true;
                                }
                              });
                            }),
                            DataColumn(label: const Text('Recette'), numeric: true, onSort: (colIndex, asc) {
                              setState(() {
                                if (_sortColumnIndex == colIndex) {
                                  _sortAscending = !_sortAscending;
                                } else {
                                  _sortColumnIndex = colIndex;
                                  _sortAscending = true;
                                }
                              });
                            }),
                          ],
                          rows: topRows
                              .map((r) => DataRow(cells: [
                                    DataCell(Text(r['name'] as String)),
                                    DataCell(Text('${r['qty']}')),
                                    DataCell(Text((r['total'] as double).toStringAsFixed(2))),
                                  ]))
                              .toList(),
                        ),
                      ),
                    );
                   }(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
