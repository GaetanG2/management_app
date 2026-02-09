class User {
  final String id;
  final String name;
  final String role;
  final int? createdAt;

  User({required this.id, required this.name, required this.role, this.createdAt});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'created_at': createdAt,
      };

  factory User.fromMap(Map<String, dynamic> m) => User(
        id: m['id'] as String,
        name: m['name'] as String,
        role: m['role'] as String,
        createdAt: m['created_at'] == null ? null : (m['created_at'] as int),
      );
}
