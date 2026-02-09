import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/database_service.dart';
import '../models/user.dart';

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(() => AuthNotifier());

class AuthNotifier extends AsyncNotifier<User?> {
  static const _currentUserKey = 'current_user_id';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  late final DatabaseService _dbService;

  @override
  Future<User?> build() async {
    _dbService = ref.read(databaseServiceProvider);

    // check if there is a current user id stored
    final currentId = await _storage.read(key: _currentUserKey);
    if (currentId != null) {
      final rows = await _dbService.query('users', where: 'id = ?', whereArgs: [currentId]);
      if (rows.isNotEmpty) return User.fromMap(rows.first);
    }

    // If there's no current user, check if a Superadmin exists.
    final superRows = await _dbService.query('users', where: 'role = ?', whereArgs: ['Superadmin'], limit: 1);
    if (superRows.isNotEmpty) {
      // A Superadmin exists -> app is configured. Return a non-null stub so LoginPage shows the login form instead of configuration.
      return User.fromMap(superRows.first);
    }

    // otherwise no Superadmin: app not configured -> ask for initial configuration
    return null;
  }

  String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

  Future<void> setPin(String pin, {String name = 'Superadmin'}) async {
    state = const AsyncValue.loading();
    try {
      // create superadmin role
      await createUser(name: name, role: 'Superadmin', pin: pin);
      state = AsyncValue.data(await build());
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<User> createUser({required String name, required String role, required String pin}) async {
    // ensure pin length
    if (pin.length < 4) throw Exception('PIN must be at least 4 chars');

    final pinHash = _hashPin(pin);

    // ensure uniqueness of pin_hash
    final existing = await _dbService.query('users', where: 'pin_hash = ?', whereArgs: [pinHash]);
    if (existing.isNotEmpty) throw Exception('PIN déjà utilisé');

    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final userMap = {
      'id': id,
      'name': name,
      'role': role,
      'pin_hash': pinHash,
      'created_at': now,
    };

    await _dbService.insert('users', userMap);

    // set current user to created user
    await _storage.write(key: _currentUserKey, value: id);

    final user = User(id: id, name: name, role: role);
    state = AsyncValue.data(user);
    return user;
  }

  Future<List<User>> getUsers() async {
    final rows = await _dbService.query('users', orderBy: 'created_at DESC');
    return rows.map((r) => User.fromMap(r)).toList();
  }

  Future<bool> verifyPin(String pin) async {
    final pinHash = _hashPin(pin);
    final rows = await _dbService.query('users', where: 'pin_hash = ?', whereArgs: [pinHash]);
    if (rows.isEmpty) return false;
    final map = rows.first;
    final user = User.fromMap(map);

    // set current user
    await _storage.write(key: _currentUserKey, value: user.id);
    state = AsyncValue.data(user);
    return true;
  }

  Future<void> logout() async {
    await _storage.delete(key: _currentUserKey);
    state = const AsyncValue.data(null);
  }

  Future<void> deleteUser(String id) async {
    // prevent deleting current user
    final currentId = await _storage.read(key: _currentUserKey);
    if (currentId == id) throw Exception('Impossible de supprimer l\'utilisateur connecté');
    await _dbService.delete('users', 'id = ?', [id]);
    // no direct state refresh here; callers should refresh via getUsers or build
  }

  Future<void> updateUserRole(String id, String role) async {
    await _dbService.update('users', {'role': role}, 'id = ?', [id]);
    // if current user changed role, update in secure storage if needed
    final currentId = await _storage.read(key: _currentUserKey);
    if (currentId == id) state = AsyncValue.data(await build());
  }
}
