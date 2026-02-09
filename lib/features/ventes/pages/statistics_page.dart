import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

import '../../articles/providers/article_provider.dart';
import '../providers/vente_provider.dart';
import '../../../data/models/vente.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articles = ref.watch(articlesNotifierProvider);
    final venteRepo = ref.read(venteRepositoryProvider);

    return FutureBuilder<List<Vente>>(
      future: venteRepo.getAll(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final ventes = snap.data ?? [];

        // ventes par jour
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

        // top 10 articles
        final topArticles = articleCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final top10 = topArticles.take(10).toList();

        // helper to normalize counts for progress bars
        int maxCount = 1;
        for (final e in top10) {
          if (e.value > maxCount) maxCount = e.value;
        }

        return Scaffold(
          // AppBar removed to keep UI minimal; header is in the body
          body: Padding(
            padding: EdgeInsets.all(AppTheme.defaultPadding),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // stylized header
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

                  // summary cards
                  Row(
                    children: [
                      Expanded(
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
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
                    ],
                  ),

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
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: recettesParJour.entries.map((e) => Text('${e.key}: ${e.value.toStringAsFixed(2)}')).toList()),

                  const SizedBox(height: 16),
                  const Text('Stock par catégorie', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  stockByCategory.isEmpty ? const Text('Aucun') : Column(crossAxisAlignment: CrossAxisAlignment.start, children: stockByCategory.entries.map((e) => Text('${e.key}: ${e.value}')).toList()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
