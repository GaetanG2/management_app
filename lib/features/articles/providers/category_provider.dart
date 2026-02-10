import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/category.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/database/database_service.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.read(databaseServiceProvider);
  return CategoryRepository(db);
});

final categoriesNotifierProvider = StateNotifierProvider<CategoriesNotifier, List<Category>>((ref) => CategoriesNotifier(ref.read(categoryRepositoryProvider)));

class CategoriesNotifier extends StateNotifier<List<Category>> {
  final CategoryRepository _repo;
  CategoriesNotifier(this._repo) : super([]) {
    load();
  }

  Future<void> load() async {
    final items = await _repo.getAll();
    state = items;
  }

  Future<void> addNew(String name) async {
    final existing = await _repo.findByName(name);
    if (existing != null) return;
    final c = Category.create(name);
    await _repo.add(c);
    state = [...state, c];
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = state.where((c) => c.id != id).toList();
  }
}
