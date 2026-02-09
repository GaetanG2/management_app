import 'dart:typed_data';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

import '../providers/article_provider.dart';
import '../../../data/models/article.dart';

class ArticlesPage extends ConsumerStatefulWidget {
  const ArticlesPage({super.key});

  @override
  ConsumerState<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends ConsumerState<ArticlesPage> {
  final _searchCtrl = TextEditingController();
  String? _selectedCategory;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  Future<void> _showAddOrEditDialog(BuildContext context, WidgetRef ref, {Article? article}) async {
    final nameCtrl = TextEditingController(text: article?.name ?? '');
    final buyCtrl = TextEditingController(text: article != null ? article.buyPrice.toString() : '');
    final sellCtrl = TextEditingController(text: article != null ? article.sellPrice.toString() : '');
    final qtyCtrl = TextEditingController(text: article != null ? article.quantity.toString() : '1');
    final catCtrl = TextEditingController(text: article?.category ?? '');
    Uint8List? pickedImage = article?.image;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setState) {
        return AlertDialog(
          title: Text(article == null ? 'Nouvel article' : 'Modifier l\'article'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom')),
                TextField(controller: buyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix d\'achat')),
                TextField(controller: sellCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix de vente')),
                TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantité')),
                TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Catégorie')),
                const SizedBox(height: 8),
                if (pickedImage != null) Image.memory(pickedImage!, width: 120, height: 120, fit: BoxFit.cover),
                TextButton.icon(
                    onPressed: () async {
                      final typeGroup = XTypeGroup(label: 'images', extensions: ['jpg', 'png', 'jpeg']);
                      final files = await openFiles(acceptedTypeGroups: [typeGroup]);
                      if (files.isNotEmpty) {
                        final file = File(files.first.path);
                        final bytes = await file.readAsBytes();
                        setState(() => pickedImage = bytes);
                      }
                    },
                    icon: const Icon(Icons.photo),
                    label: const Text('Ajouter une image'))
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final buy = double.tryParse(buyCtrl.text.trim()) ?? 0;
                  final sell = double.tryParse(sellCtrl.text.trim()) ?? 0;
                  final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                  final cat = catCtrl.text.trim();
                  if (name.isEmpty || cat.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom et catégorie sont obligatoires')));
                    return;
                  }

                  if (article == null) {
                    await ref.read(articlesNotifierProvider.notifier).addNew(name: name, buyPrice: buy, sellPrice: sell, quantity: qty, category: cat, image: pickedImage);
                  } else {
                    final updated = article.copyWith(name: name, buyPrice: buy, sellPrice: sell, quantity: qty, category: cat, image: pickedImage);
                    await ref.read(articlesNotifierProvider.notifier).updateArticle(updated);
                  }

                  if (context.mounted) Navigator.of(ctx).pop();
                },
                child: Text(article == null ? 'Ajouter' : 'Enregistrer'))
          ],
        );
      }),
    );
  }

  List<Article> _applyFilters(List<Article> articles) {
    final q = _searchCtrl.text.trim().toLowerCase();
    var list = articles.where((a) => q.isEmpty || a.name.toLowerCase().contains(q) || a.category.toLowerCase().contains(q)).toList();
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      list = list.where((a) => a.category == _selectedCategory).toList();
    }
    // simple sort by name if requested
    if (_sortColumnIndex == 0) {
      list.sort((a, b) => _sortAscending ? a.name.compareTo(b.name) : b.name.compareTo(a.name));
    } else if (_sortColumnIndex == 1) {
      list.sort((a, b) => _sortAscending ? a.sellPrice.compareTo(b.sellPrice) : b.sellPrice.compareTo(a.sellPrice));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final articles = ref.watch(articlesNotifierProvider);
    final categories = <String>{};
    for (var a in articles) {
      if (a.category.isNotEmpty) categories.add(a.category);
    }

    final filtered = _applyFilters(articles);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Articles'),
        actions: [
          TextButton.icon(onPressed: () => _showAddOrEditDialog(context, ref), icon: const Icon(Icons.add, color: Colors.black), label: const Text('Ajouter', style: TextStyle(color: Colors.black))),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(AppTheme.defaultPadding),
        child: Column(
          children: [
            // header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
              child: Row(children: [
                const Icon(Icons.inventory, size: 28, color: AppTheme.primary),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Articles', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Gérez vos produits (Admin)', style: Theme.of(context).textTheme.bodySmall),
                ])
              ]),
            ),
            const SizedBox(height: 12),

            // search & filters
            Row(children: [
              Expanded(child: TextField(controller: _searchCtrl, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher...', border: OutlineInputBorder()))),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String?>(
                  initialValue: _selectedCategory,
                  items: [const DropdownMenuItem(value: null, child: Text('Toutes')), ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))],
                  onChanged: (v) => setState(() => _selectedCategory = v),
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            Expanded(
              child: LayoutBuilder(builder: (ctx, constraints) {
                final narrow = constraints.maxWidth < 700;
                if (filtered.isEmpty) return const Center(child: Text('Aucun article. Ajoutez-en un.'));

                if (narrow) {
                  // mobile: simple list
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final a = filtered[i];
                      return ListTile(
                        leading: a.image == null ? const CircleAvatar(child: Icon(Icons.inventory)) : CircleAvatar(backgroundImage: MemoryImage(a.image!)),
                        title: Text(a.name),
                        subtitle: Text('Stock: ${a.quantity} • Prix: ${a.sellPrice.toStringAsFixed(2)} • Cat: ${a.category}'),
                        onTap: () => _showAddOrEditDialog(context, ref, article: a),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(onPressed: () => _showAddOrEditDialog(context, ref, article: a), icon: const Icon(Icons.edit)),
                          IconButton(onPressed: () async => await ref.read(articlesNotifierProvider.notifier).deleteArticle(a.id), icon: const Icon(Icons.delete, color: Colors.red)),
                        ]),
                      );
                    },
                  );
                }

                // wide: DataTable with sorting
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Card(
                    child: DataTable(
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      columns: [
                        DataColumn(label: const Text('Nom'), onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; })),
                        DataColumn(label: const Text('Prix achat')),
                        DataColumn(label: const Text('Prix vente'), numeric: true, onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; })),
                        DataColumn(label: const Text('Quantité'), numeric: true),
                        DataColumn(label: const Text('Catégorie')),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: filtered
                          .map(
                            (a) => DataRow(cells: [
                              DataCell(Text(a.name)),
                              DataCell(Text(a.buyPrice.toStringAsFixed(2))),
                              DataCell(Text(a.sellPrice.toStringAsFixed(2))),
                              DataCell(Text('${a.quantity}')),
                              DataCell(Text(a.category)),
                              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(onPressed: () => _showAddOrEditDialog(context, ref, article: a), icon: const Icon(Icons.edit)),
                                IconButton(onPressed: () async => await ref.read(articlesNotifierProvider.notifier).deleteArticle(a.id), icon: const Icon(Icons.delete, color: Colors.red)),
                              ])),
                            ]),
                          )
                          .toList(),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _showAddOrEditDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un article'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
