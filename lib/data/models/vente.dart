class Vente {
  final String id;
  final String? saleId;
  final String articleId;
  final int qty;
  final double total;
  final String? userId;
  final int createdAt;

  Vente({required this.id, this.saleId, required this.articleId, required this.qty, required this.total, this.userId, required this.createdAt});

  Map<String, dynamic> toMap() => {
        'id': id,
        'sale_id': saleId,
        'article_id': articleId,
        'qty': qty,
        'total': total,
        'user_id': userId,
        'created_at': createdAt,
      };

  factory Vente.fromMap(Map<String, dynamic> m) => Vente(
        id: m['id'] as String,
        saleId: m['sale_id'] as String?,
        articleId: m['article_id'] as String,
        qty: (m['qty'] as num).toInt(),
        total: (m['total'] as num).toDouble(),
        userId: m['user_id'] as String?,
        createdAt: (m['created_at'] as int),
      );
}
