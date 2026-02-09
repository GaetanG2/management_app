import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

import '../../articles/providers/article_provider.dart';
import '../providers/vente_provider.dart';
import '../../auth/providers/auth_provider.dart';

class VentesPage extends ConsumerStatefulWidget {
  const VentesPage({super.key});

  @override
  ConsumerState<VentesPage> createState() => _VentesPageState();
}

class _VentesPageState extends ConsumerState<VentesPage> {
  String? _selectedArticleId;
  final _qtyCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _addToCart(BuildContext context, List articles) {
    final id = _selectedArticleId;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un article')));
      return;
    }
    dynamic art;
    try {
      art = articles.firstWhere((a) => a.id == id);
    } catch (_) {
      art = null;
    }
    if (art == null) return;
    if (art.quantity < qty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantité demandée supérieure au stock')));
      return;
    }
    ref.read(cartProvider.notifier).add(id, qty: qty);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajouté au panier')));
  }

  @override
  Widget build(BuildContext context) {
    final articles = ref.watch(articlesNotifierProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(AppTheme.defaultPadding),
        child: LayoutBuilder(builder: (ctx, constraints) {
          final isNarrow = constraints.maxWidth < 780;

          // Selector card
          final selector = Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // stylized header (aligned with app theme)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                    decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(6)),
                    child: Row(children: [
                      const Icon(Icons.point_of_sale, size: 28, color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Ventes', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Enregistrer une nouvelle vente', style: Theme.of(context).textTheme.bodySmall),
                      ])
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Text('Nouvelle vente', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedArticleId,
                    decoration: const InputDecoration(labelText: 'Article', border: OutlineInputBorder()),
                    hint: const Text('Sélectionner un article'),
                    items: articles
                        .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (stock: ${a.quantity})', overflow: TextOverflow.ellipsis, maxLines: 1)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedArticleId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qtyCtrl,
                          decoration: const InputDecoration(labelText: 'Quantité', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 110),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12)),
                          onPressed: () => _addToCart(context, articles),
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Ajouter'),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Quick info for selected article
                  if (_selectedArticleId != null)
                    Builder(builder: (c) {
                      // safe lookup
                      dynamic art;
                      try {
                        art = articles.firstWhere((a) => a.id == _selectedArticleId);
                      } catch (_) {
                        art = null;
                      }
                      if (art == null) return const SizedBox.shrink();
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Prix de vente: ${art.sellPrice.toStringAsFixed(2)}'),
                        const SizedBox(height: 4),
                        Text('Prix d\'achat: ${art.buyPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('En stock: ${art.quantity}', style: const TextStyle(color: Colors.grey)),
                      ]);
                    })
                ],
              ),
            ),
          );

          // Cart card
          final cartCard = Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Panier', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (cart.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Center(child: Text('Le panier est vide')))
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: isNarrow ? 300 : 480),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: cart.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final c = cart[i];
                          final art = articles.firstWhere((a) => a.id == c.articleId, orElse: () => throw Exception('Article introuvable'));
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              children: [
                                // placeholder thumbnail
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                  child: const Icon(Icons.inventory_2, color: Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(art.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text('Prix unitaire: ${art.sellPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                                  ]),
                                ),
                                const SizedBox(width: 8),
                                // qty controls
                                Row(children: [
                                  IconButton(
                                      onPressed: () => ref.read(cartProvider.notifier).updateQty(c.articleId, c.qty - 1),
                                      icon: const Icon(Icons.remove_circle_outline)),
                                  Text('${c.qty}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(onPressed: () => ref.read(cartProvider.notifier).updateQty(c.articleId, c.qty + 1), icon: const Icon(Icons.add_circle_outline)),
                                ]),
                                const SizedBox(width: 8),
                                // subtotal + delete
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text((art.sellPrice * c.qty).toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(onPressed: () => ref.read(cartProvider.notifier).remove(c.articleId), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                                ])
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Builder(builder: (ctx) {
                    final total = ref.read(cartProvider.notifier).totalPrice(articles);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total:', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                            Text(total.toStringAsFixed(2), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                            onPressed: cart.isEmpty
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final currentUser = ref.read(authProvider).asData?.value;
                                    final userId = currentUser?.id ?? '';
                                    try {
                                      await ref.read(cartProvider.notifier).commitSale(userId);
                                      await ref.read(ventesListProvider.notifier).load();
                                      if (!mounted) return;
                                      messenger.showSnackBar(const SnackBar(content: Text('Vente enregistrée')));
                                      // keep on page and show cart empty
                                    } catch (e) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
                                    }
                                  },
                            child: const Text('Finaliser la vente'))
                      ],
                    );
                  })
                ],
              ),
            ),
          );

          if (isNarrow) {
            return SingleChildScrollView(
              child: Column(
                children: [selector, const SizedBox(height: 12), cartCard],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 420, child: selector),
              const SizedBox(width: 12),
              Expanded(child: cartCard),
            ],
          );
        }),
      ),
    );
  }
}
