import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';

import '../../../data/models/article.dart';
import '../../../data/repositories/article_repository.dart';
import '../../../data/database/database_service.dart';

final articleRepositoryProvider = Provider<ArticleRepository>((ref) {
  final dbService = ref.read(databaseServiceProvider);
  return ArticleRepository(dbService);
});
final articlesNotifierProvider = StateNotifierProvider<ArticlesNotifier, List<Article>>((ref) => ArticlesNotifier(ref.read(articleRepositoryProvider)));

class ArticlesNotifier extends StateNotifier<List<Article>> {
  final ArticleRepository _repo;
  ArticlesNotifier(this._repo) : super([]) {
    load();
  }

  Future<void> load() async {
    final items = await _repo.getAll();
    state = items;
  }

  Future<void> addNew({required String name, required double buyPrice, required double sellPrice, required int quantity, required String category, Uint8List? image}) async {
    final id = const Uuid().v4();
    final art = Article(id: id, name: name, buyPrice: buyPrice, sellPrice: sellPrice, quantity: quantity, category: category, image: image);
    await _repo.add(art);
    state = [...state, art];
  }

  Future<void> updateArticle(Article a) async {
    await _repo.update(a);
    state = [for (final x in state) if (x.id == a.id) a else x];
  }

  Future<void> deleteArticle(String id) async {
    await _repo.delete(id);
    state = state.where((e) => e.id != id).toList();
  }
}
