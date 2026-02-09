import '../database/database_service.dart';
import '../models/vente.dart';

class VenteRepository {
  final DatabaseService _dbService;

  VenteRepository(this._dbService);

  Future<void> add(Vente v) async => await _dbService.insert('ventes', v.toMap());

  Future<List<Vente>> getAll() async {
    final rows = await _dbService.query('ventes', orderBy: 'created_at DESC');
    return rows.map((r) => Vente.fromMap(r)).toList();
  }

  Future<List<Vente>> getByDateRange(int fromMs, int toMs) async {
    final rows = await _dbService.query('ventes', where: 'created_at BETWEEN ? AND ?', whereArgs: [fromMs, toMs], orderBy: 'created_at DESC');
    return rows.map((r) => Vente.fromMap(r)).toList();
  }

  Future<int> delete(String id) async => await _dbService.delete('ventes', 'id = ?', [id]);

  Future<int> deleteBySaleId(String saleId) async => await _dbService.delete('ventes', 'sale_id = ?', [saleId]);

  Future<Vente?> findById(String id) async {
    final rows = await _dbService.query('ventes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Vente.fromMap(rows.first);
  }
}
