import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/vente.dart';
import '../../../data/models/article.dart';
import '../../../data/repositories/vente_repository.dart';
import '../../../data/repositories/article_repository.dart';
import '../../../data/database/database_service.dart';
import '../../articles/providers/article_provider.dart';

final venteRepositoryProvider = Provider<VenteRepository>((ref) {
  final db = ref.read(databaseServiceProvider);
  return VenteRepository(db);
});

final venteServiceProvider = Provider<VenteService>((ref) {
  final vRepo = ref.read(venteRepositoryProvider);
  final aRepo = ref.read(articleRepositoryProvider);
  return VenteService(vRepo, aRepo);
});

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier(ref));

class CartItem {
  final String articleId;
  int qty;
  CartItem({required this.articleId, required this.qty});
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  final Ref ref;
  CartNotifier(this.ref) : super([]);

  void add(String articleId, {int qty = 1}) {
    final existing = state.where((e) => e.articleId == articleId).toList();
    if (existing.isNotEmpty) {
      // increment
      final e = existing.first;
      e.qty += qty;
      state = [...state];
    } else {
      state = [...state, CartItem(articleId: articleId, qty: qty)];
    }
  }

  void remove(String articleId) {
    state = state.where((e) => e.articleId != articleId).toList();
  }

  void updateQty(String articleId, int qty) {
    state = [for (final c in state) if (c.articleId == articleId) CartItem(articleId: c.articleId, qty: qty) else c];
  }

  Future<void> clear() async {
    state = [];
  }

  double totalPrice(List<Article> articles) {
    double sum = 0;
    for (final item in state) {
      final found = articles.where((a) => a.id == item.articleId);
      if (found.isEmpty) continue;
      final art = found.first;
      sum += art.sellPrice * item.qty;
    }
    return sum;
  }

  Future<void> commitSale(String userId) async {
    final venteRepo = ref.read(venteRepositoryProvider);
    final artRepo = ref.read(articleRepositoryProvider);
    final articles = await artRepo.getAll();
    final saleId = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final item in state) {
      final found = articles.where((a) => a.id == item.articleId);
      if (found.isEmpty) throw Exception('Article introuvable');
      final art = found.first;
      final total = art.sellPrice * item.qty;
      final vente = Vente(id: const Uuid().v4(), saleId: saleId, articleId: art.id, qty: item.qty, total: total, userId: userId, createdAt: now);
      await venteRepo.add(vente);
      // update stock
      final updated = art.copyWith(quantity: art.quantity - item.qty);
      await artRepo.update(updated);
    }
    await clear();
  }
}

final ventesListProvider = StateNotifierProvider<VentesListNotifier, List<Vente>>((ref) => VentesListNotifier(ref));

class VentesListNotifier extends StateNotifier<List<Vente>> {
  final Ref ref;
  VentesListNotifier(this.ref) : super([]) {
    load();
  }

  Future<void> load() async {
    final repo = ref.read(venteRepositoryProvider);
    final list = await repo.getAll();
    state = list;
  }
}

class VenteService {
  final VenteRepository _vRepo;
  final ArticleRepository _aRepo;

  VenteService(this._vRepo, this._aRepo);

  Future<void> recordSale({required String articleId, required int qty, required String userId}) async {
    // find article
    final art = await _aRepo.findById(articleId);
    if (art == null) throw Exception('Article introuvable');
    if (art.quantity < qty) throw Exception('Quantité insuffisante');

    final total = qty * art.sellPrice;
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final vente = Vente(id: id, articleId: articleId, qty: qty, total: total, userId: userId, createdAt: now);

    // insert vente
    await _vRepo.add(vente);

    // update article stock
    final updated = art.copyWith(quantity: art.quantity - qty);
    await _aRepo.update(updated);
  }
}
