import 'package:uuid/uuid.dart';

class Category {
  final String id;
  final String name;
  final int createdAt;

  Category({required this.id, required this.name, required this.createdAt});

  factory Category.create(String name) => Category(id: const Uuid().v4(), name: name, createdAt: DateTime.now().millisecondsSinceEpoch);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt,
      };

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as String,
        name: m['name'] as String,
        createdAt: (m['created_at'] as num).toInt(),
      );
}
