import '../models/article.dart';
import '../database/database_service.dart';

class ArticleRepository {
  final DatabaseService _dbService;

  ArticleRepository(this._dbService);

  Future<List<Article>> getAll() async {
    final rows = await _dbService.query('articles', orderBy: 'name ASC');
    return rows.map((r) => Article.fromMap(r)).toList();
  }

  Future<void> add(Article article) async {
    await _dbService.insert('articles', article.toMap());
  }

  Future<void> update(Article article) async {
    await _dbService.update('articles', article.toMap(), 'id = ?', [article.id]);
  }

  Future<void> delete(String id) async {
    await _dbService.delete('articles', 'id = ?', [id]);
  }

  Future<Article?> findById(String id) async {
    final rows = await _dbService.query('articles', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Article.fromMap(rows.first);
  }
}
