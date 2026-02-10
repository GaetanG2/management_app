import '../database/database_service.dart';
import '../models/category.dart';

class CategoryRepository {
  final DatabaseService _dbService;
  CategoryRepository(this._dbService);

  Future<List<Category>> getAll() async {
    final rows = await _dbService.query('categories', orderBy: 'name ASC');
    // debug: print rows fetched
    // ignore: avoid_print
    print('DEBUG: CategoryRepository.getAll rows=${rows.length}');
    // ignore: avoid_print
    print('DEBUG: CategoryRepository.getAll rows_names=${rows.map((r) => r['name']).toList()}');
    return rows.map((r) => Category.fromMap(r)).toList();
  }

  Future<void> add(Category c) async {
    await _dbService.insert('categories', c.toMap());
    // debug: confirm insertion
    // ignore: avoid_print
    print('DEBUG: CategoryRepository.add inserted=${c.name}');
  }

  Future<void> delete(String id) async {
    await _dbService.delete('categories', 'id = ?', [id]);
  }

  Future<Category?> findByName(String name) async {
    final rows = await _dbService.query('categories', where: 'name = ?', whereArgs: [name]);
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }
}
