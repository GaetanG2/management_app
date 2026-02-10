import 'dart:typed_data';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_theme.dart';

import '../providers/article_provider.dart';
import '../providers/category_provider.dart';
import '../../../data/models/article.dart';

class ArticlesPage extends ConsumerStatefulWidget {
  const ArticlesPage({super.key});

  @override
  ConsumerState<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends ConsumerState<ArticlesPage> {
  final _searchCtrl = TextEditingController();
  final _catSearchCtrl = TextEditingController();
  final GlobalKey _catFieldKey = GlobalKey();
  String? _selectedCategory;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _catSearchCtrl.addListener(() => setState(() {}));
    // make article search reactive
    _searchCtrl.addListener(() => setState(() {}));
    // Ensure categories are loaded after first frame so popup has data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(categoriesNotifierProvider.notifier).load();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _catSearchCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddOrEditDialog(BuildContext context, WidgetRef ref, {Article? article}) async {
    final nameCtrl = TextEditingController(text: article?.name ?? '');
    final buyCtrl = TextEditingController(text: article != null ? article.buyPrice.toString() : '');
    final sellCtrl = TextEditingController(text: article != null ? article.sellPrice.toString() : '');
    final qtyCtrl = TextEditingController(text: article != null ? article.quantity.toString() : '1');
    final catCtrl = TextEditingController(text: article?.category ?? '');
    final otherCatCtrl = TextEditingController();
    var useOther = false;
    Uint8List? pickedImage = article?.image;

    // Ensure categories are loaded before showing the dialog so the dropdown has data
    try {
      await ref.read(categoriesNotifierProvider.notifier).load();
    } catch (_) {}
    // dialogCategories removed (not needed) - we'll load categories directly from repository inside the dialog

    await showDialog(
      context: context,
      builder: (ctx) => Consumer(builder: (dialogCtx, dialogRef, _) {
        return StatefulBuilder(builder: (ctx2, setState) {
          return LayoutBuilder(builder: (ctx3, constraints) {
            // responsive width: full on narrow, limited on wide
            final dialogWidth = constraints.maxWidth < 600 ? constraints.maxWidth * 0.95 : 600.0;
            return AlertDialog(
              title: Text(article == null ? 'Nouvel article' : 'Modifier l\'article'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: dialogWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom')),
                      const SizedBox(height: 12),
                      TextField(controller: buyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix d\'achat')),
                      const SizedBox(height: 12),
                      TextField(controller: sellCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix de vente')),
                      const SizedBox(height: 12),
                      TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantité')),
                      const SizedBox(height: 16),

                      // category selector: dropdown of persisted categories + 'Autre' to type a new one
                      StatefulBuilder(builder: (dCtx, dSetState) {
                        // current not needed; we read catCtrl directly when required
                        final futureNames = dialogRef.read(categoryRepositoryProvider).getAll().then((persistedCats) {
                          final articlesAll = dialogRef.read(articlesNotifierProvider);
                          final Set<String> namesSet = {for (var c in persistedCats) c.name};
                          for (var a in articlesAll) {
                            if (a.category.trim().isNotEmpty) namesSet.add(a.category.trim());
                          }
                          final list = namesSet.toList()..sort();
                          return list;
                        });

                        return FutureBuilder<List<String>>(
                          future: futureNames,
                          builder: (ctxF, snap) {
                            final loading = snap.connectionState == ConnectionState.waiting;
                            final uniqueNames = snap.data ?? <String>[];

                            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Row(children: [
                                Expanded(
                                  child: loading
                                      ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
                                      : Autocomplete<String>(
                                          optionsBuilder: (TextEditingValue textEditingValue) {
                                            final input = textEditingValue.text.trim().toLowerCase();
                                            return uniqueNames.where((n) => input.isEmpty || n.toLowerCase().contains(input)).toList();
                                          },
                                          displayStringForOption: (opt) => opt,
                                          onSelected: (selection) {
                                            dSetState(() {
                                              useOther = false;
                                              catCtrl.text = selection;
                                            });
                                          },
                                          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                            textEditingController.text = catCtrl.text;
                                            textEditingController.selection = TextSelection.collapsed(offset: textEditingController.text.length);
                                            return TextField(
                                              controller: textEditingController,
                                              focusNode: focusNode,
                                              decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder()),
                                              onChanged: (v) {
                                                dSetState(() => useOther = false);
                                                catCtrl.text = v;
                                              },
                                              onSubmitted: (_) => onFieldSubmitted(),
                                            );
                                          },
                                          optionsViewBuilder: (context, onSelected, options) {
                                            return Material(
                                              elevation: 4.0,
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(maxHeight: 240),
                                                child: ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  itemCount: options.length,
                                                  itemBuilder: (ctx, i) {
                                                    final opt = options.elementAt(i);
                                                    return ListTile(
                                                      title: Text(opt),
                                                      onTap: () => onSelected(opt),
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Column(children: [
                                  SizedBox(
                                    height: 40,
                                    child: IconButton(
                                      tooltip: 'Rafraîchir les catégories',
                                      icon: const Icon(Icons.refresh),
                                      onPressed: () async {
                                        try {
                                          await dialogRef.read(categoriesNotifierProvider.notifier).load();
                                        } catch (_) {}
                                        // ensure the dialog is still mounted before updating its internal state
                                        if (!dCtx.mounted) return;
                                        dSetState(() {});
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    height: 40,
                                    child: IconButton(
                                      tooltip: 'Ajouter une nouvelle catégorie',
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => dSetState(() => useOther = true),
                                    ),
                                  ),
                                ])
                              ]),

                              const SizedBox(height: 6),
                              // informative line listing detected categories (helps debug if none visible)
                              Text(
                                uniqueNames.isEmpty ? 'Aucune catégorie trouvée' : 'Catégories détectées: ${uniqueNames.take(8).join(', ')}${uniqueNames.length > 8 ? ', ...' : ''}',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),

                              if (useOther) ...[
                                const SizedBox(height: 8),
                                TextField(controller: otherCatCtrl, decoration: const InputDecoration(labelText: 'Nouvelle catégorie'))
                              ]
                            ]);
                          },
                        );
                      }),

                      const SizedBox(height: 16),
                      if (pickedImage != null)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
                          child: Image.memory(pickedImage!, width: 160, height: 160, fit: BoxFit.cover),
                        ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                          onPressed: () async {
                            final typeGroup = XTypeGroup(label: 'images', extensions: ['jpg', 'png', 'jpeg']);
                            final files = await openFiles(acceptedTypeGroups: [typeGroup]);
                            if (files.isNotEmpty) {
                              final file = File(files.first.path);
                              final bytes = await file.readAsBytes();
                              // ensure dialog's state is still mounted before calling setState
                              if (!ctx2.mounted) return;
                              setState(() => pickedImage = bytes);
                            }
                          },
                          icon: const Icon(Icons.photo),
                          label: const Text('Ajouter une image'))
                    ],
                  ),
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
                      final cat = (useOther ? otherCatCtrl.text.trim() : catCtrl.text.trim());
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
          });
        });
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
    final categoriesList = ref.watch(categoriesNotifierProvider);

    final filtered = _applyFilters(articles);

    return Scaffold(
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

            // search & filters (larger search, compact category + add button)
            Row(children: [
              Expanded(flex: 4, child: TextField(controller: _searchCtrl, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher un article...', border: OutlineInputBorder()))),
              const SizedBox(width: 12),
              // reduced filter width (flex 1) so popup is smaller as requested
              Expanded(
                flex: 1,
                child: GestureDetector(
                  key: _catFieldKey,
                  onTap: () async {
                    _catSearchCtrl.text = '';
                    // force reload of categories to ensure latest from DB
                    try {
                      await ref.read(categoriesNotifierProvider.notifier).load();
                    } catch (_) {}
                    // compute position so popup matches field width
                    final renderBox = _catFieldKey.currentContext?.findRenderObject() as RenderBox?;
                    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                    RelativeRect position = RelativeRect.fromLTRB(0, 0, 0, 0);
                    if (renderBox != null) {
                      final offset = renderBox.localToGlobal(Offset.zero);
                      position = RelativeRect.fromLTRB(offset.dx, offset.dy + renderBox.size.height, overlay.size.width - offset.dx - renderBox.size.width, overlay.size.height - offset.dy);
                    }

                    // build list of category names: persisted categories plus distinct article.category fallback
                    final persisted = categoriesList;
                    final articlesAll = ref.read(articlesNotifierProvider);
                    final Set<String> names = {for (var c in persisted) c.name};
                    for (var a in articlesAll) {
                      if (a.category.trim().isNotEmpty) names.add(a.category.trim());
                    }
                    final currentList = names.toList()..sort();

                    final sel = await showMenu<String?>(
                      context: context,
                      position: position,
                      items: [
                        PopupMenuItem<String?>(
                          enabled: false,
                          child: SizedBox(
                            width: renderBox?.size.width ?? 200,
                            height: 280,
                            child: StatefulBuilder(builder: (ctxMenu, setStateMenu) {
                              final q = _catSearchCtrl.text.trim().toLowerCase();
                              final list = currentList.where((name) => q.isEmpty || name.toLowerCase().contains(q)).toList();
                              return Column(children: [
                                TextField(
                                  controller: _catSearchCtrl,
                                  autofocus: true,
                                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher une catégorie', border: OutlineInputBorder()),
                                  onChanged: (_) => setStateMenu(() {}),
                                ),
                                const SizedBox(height: 8),
                                // 'Toutes' option -> special token
                                ListTile(
                                  title: const Text('Toutes'),
                                  leading: const Icon(Icons.list),
                                  onTap: () => Navigator.of(ctxMenu).pop('__all__'),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: list.isEmpty
                                      ? const Center(child: Text('Aucune catégorie'))
                                      : ListView.separated(
                                          itemCount: list.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1),
                                          itemBuilder: (_, i) {
                                            final name = list[i];
                                            return ListTile(
                                              title: Text(name),
                                              onTap: () => Navigator.of(ctxMenu).pop(name),
                                            );
                                          },
                                        ),
                                )
                              ]);
                            }),
                          ),
                        ),
                      ],
                    );
                    // apply selection (handle '__all__')
                    if (sel == '__all__') {
                      setState(() => _selectedCategory = null);
                    } else if (sel != null) {
                      setState(() => _selectedCategory = sel);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                    child: Row(children: [
                      Expanded(child: Text(_selectedCategory ?? 'Toutes', style: const TextStyle(fontSize: 14))),
                      if (_selectedCategory != null)
                        GestureDetector(onTap: () => setState(() => _selectedCategory = null), child: const Padding(padding: EdgeInsets.only(right: 8.0), child: Icon(Icons.clear, size: 18, color: Colors.black54))),
                      const Icon(Icons.arrow_drop_down)
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                // ensure table expands to full available width
                final w = constraints.maxWidth;
                return Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: w,
                      child: DataTable(
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 80,
                        headingRowHeight: 56,
                        headingTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87, fontWeight: FontWeight.w600),
                        columnSpacing: 24,
                        showCheckboxColumn: false,
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
                        rows: filtered.map((a) => DataRow(cells: [
                          DataCell(Row(children: [
                            CircleAvatar(backgroundImage: a.image == null ? null : MemoryImage(a.image!), child: a.image == null ? const Icon(Icons.inventory) : null),
                            const SizedBox(width: 8),
                            Flexible(child: Text(a.name, overflow: TextOverflow.ellipsis)),
                          ])),
                          DataCell(Text(a.buyPrice.toStringAsFixed(2))),
                          DataCell(Text(a.sellPrice.toStringAsFixed(2))),
                          DataCell(Text('${a.quantity}')),
                          DataCell(Text(a.category)),
                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(onPressed: () => _showAddOrEditDialog(context, ref, article: a), icon: const Icon(Icons.edit)),
                            IconButton(onPressed: () async => await ref.read(articlesNotifierProvider.notifier).deleteArticle(a.id), icon: const Icon(Icons.delete, color: Colors.red)),
                          ])),
                        ])).toList(),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                ElevatedButton.icon(
                  onPressed: () => _showAddOrEditDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un article'),
                ),
                const SizedBox(width: 12),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final nameCtrl = TextEditingController();
                        await showDialog(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Nouvelle catégorie'),
                            content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom de la catégorie')),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('Annuler')),
                              ElevatedButton(
                                  onPressed: () async {
                                    final nm = nameCtrl.text.trim();
                                    if (nm.isEmpty) return;
                                    try {
                                      await ref.read(categoriesNotifierProvider.notifier).addNew(nm);
                                      // preselect freshly created category if still mounted
                                      if (mounted) setState(() => _selectedCategory = nm);
                                      // reload categories to ensure UI updates
                                      await ref.read(categoriesNotifierProvider.notifier).load();
                                    } catch (_) {}
                                    if (context.mounted) Navigator.of(dCtx).pop();
                                  },
                                  child: const Text('Ajouter'))
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Créer catégorie'),
                    ),
                  ),
                ]),
              ]),
            )
           ],
         ),
       ),
     );
   }
 }
