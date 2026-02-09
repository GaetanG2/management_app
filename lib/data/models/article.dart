import 'dart:typed_data';

class Article {
  final String id;
  final String name;
  final double buyPrice;
  final double sellPrice;
  final int quantity;
  final String category;
  final Uint8List? image;

  Article({required this.id, required this.name, required this.buyPrice, required this.sellPrice, required this.quantity, required this.category, this.image});

  Article copyWith({String? id, String? name, double? buyPrice, double? sellPrice, int? quantity, String? category, Uint8List? image}) {
    return Article(
      id: id ?? this.id,
      name: name ?? this.name,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      image: image ?? this.image,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
        'quantity': quantity,
        'category': category,
        'image': image,
      };

  factory Article.fromMap(Map<String, dynamic> m) => Article(
        id: m['id'] as String,
        name: m['name'] as String,
        buyPrice: (m['buyPrice'] as num).toDouble(),
        sellPrice: (m['sellPrice'] as num).toDouble(),
        quantity: (m['quantity'] as num).toInt(),
        category: (m['category'] as String?) ?? 'Uncategorized',
        image: m['image'] == null ? null : (m['image'] as Uint8List),
      );
}
