import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  final Database _db;
  final String path;

  DatabaseService._(this._db, this.path);

  static Future<DatabaseService> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'boutique.db');

    // ensure directory exists
    await Directory(dir.path).create(recursive: true);

    final db = await openDatabase(dbPath, version: 3, onCreate: (db, version) async {
      // users table: store pin_hash unique
      await db.execute('''
        CREATE TABLE users (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          role TEXT NOT NULL,
          pin_hash TEXT UNIQUE,
          created_at INTEGER
        )
      ''');

      // articles table (field names matching Article model)
      await db.execute('''
        CREATE TABLE articles (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          buyPrice REAL,
          sellPrice REAL,
          quantity INTEGER,
          category TEXT NOT NULL,
          image BLOB
        )
      ''');

      // ventes table (one row per sold article, sale_id groups lines into a single sale)
      await db.execute('''
        CREATE TABLE ventes (
          id TEXT PRIMARY KEY,
          sale_id TEXT,
          article_id TEXT,
          qty INTEGER,
          total REAL,
          user_id TEXT,
          created_at INTEGER
        )
      ''');
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        // add user_id column to ventes if migrating from v1
        try {
          await db.execute('ALTER TABLE ventes ADD COLUMN user_id TEXT');
        } catch (_) {}
      }
      if (oldVersion < 3) {
        // add image column to articles
        try {
          await db.execute('ALTER TABLE articles ADD COLUMN image BLOB');
        } catch (_) {}
        // add sale_id column to ventes
        try {
          await db.execute('ALTER TABLE ventes ADD COLUMN sale_id TEXT');
        } catch (_) {}

        // ensure category is not null: create temp table and copy data with default
        try {
          await db.execute('''
            CREATE TABLE articles_new (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              buyPrice REAL,
              sellPrice REAL,
              quantity INTEGER,
              category TEXT NOT NULL,
              image BLOB
            )
          ''');
          // copy with default category where null
          await db.execute("INSERT INTO articles_new (id,name,buyPrice,sellPrice,quantity,category,image) SELECT id,name,buyPrice,sellPrice,quantity,COALESCE(category,'Uncategorized'),image FROM articles;");
          await db.execute('DROP TABLE articles');
          await db.execute('ALTER TABLE articles_new RENAME TO articles');
        } catch (_) {
          // ignore migration errors, preserve old table
        }
      }
    });

    return DatabaseService._(db, dbPath);
  }

  Database get db => _db;

  String get dbFilePath => path;

  Future<void> close() async => await _db.close();

  // helper: insert a row into a table
  Future<int> insert(String table, Map<String, Object?> values) => _db.insert(table, values);

  Future<int> update(String table, Map<String, Object?> values, String where, List<Object?> whereArgs) =>
      _db.update(table, values, where: where, whereArgs: whereArgs);

  Future<int> delete(String table, String where, List<Object?> whereArgs) => _db.delete(table, where: where, whereArgs: whereArgs);

  Future<List<Map<String, Object?>>> query(String table, {String? where, List<Object?>? whereArgs, String? orderBy, int? limit, int? offset}) =>
      _db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit, offset: offset);
}

final databaseServiceProvider = Provider<DatabaseService>((ref) => throw UnimplementedError());
