import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme/app_theme.dart';

import '../../../data/database/database_service.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _currencyKey = 'default_currency';
  String _currency = 'FCFA';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final c = await _storage.read(key: _currencyKey);
    if (c != null) setState(() => _currency = c);
  }

  Future<void> _saveCurrency(String c) async {
    await _storage.write(key: _currencyKey, value: c);
    setState(() => _currency = c);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devise enregistrée')));
  }

  @override
  Widget build(BuildContext context) {
    final dbService = ref.read(databaseServiceProvider);

    Future<void> exportDb() async {
      try {
        final suggestedName = 'backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}.db';
        // getSaveLocation is the newer API; fallback to getSavePath for older versions
        final location = await getSaveLocation(suggestedName: suggestedName, acceptedTypeGroups: [XTypeGroup(label: 'Database', extensions: ['db'])]);
        final path = location?.path;
        if (path == null) return; // user cancelled
        final src = File(dbService.dbFilePath);
        await src.copy(path);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sauvegarde exportée avec succès.')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur export: $e')));
      }
    }

    Future<void> importDb() async {
      try {
        final files = await openFiles(acceptedTypeGroups: [XTypeGroup(label: 'Database', extensions: ['db'])]);
        if (files.isEmpty) return;
        final file = File(files.first.path);
        final dest = File(dbService.dbFilePath);
        await file.copy(dest.path);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Base importée. Redémarrez l\'application.')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur import: $e')));
      }
    }

    return Scaffold(
      // AppBar removed to keep UI minimal; page content has its own headings
      body: Padding(
        padding: EdgeInsets.all(AppTheme.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Actions de sauvegarde', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: exportDb, icon: const Icon(Icons.upload_file), label: const Text('Exporter la base (.db)')),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: importDb, icon: const Icon(Icons.download), label: const Text('Importer une sauvegarde (.db)')),
            const SizedBox(height: 20),
            const Text('Paramètres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Devise par défaut: '),
              const SizedBox(width: 8),
              DropdownButton<String>(value: _currency, items: const [DropdownMenuItem(value: 'FCFA', child: Text('FCFA')), DropdownMenuItem(value: 'USD', child: Text('USD')), DropdownMenuItem(value: 'EUR', child: Text('EUR'))], onChanged: (v) => _saveCurrency(v ?? 'FCFA'))
            ]),
            const SizedBox(height: 20),
            const Text('Remarques:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('• Utilisez cette interface pour copier manuellement la base entre appareils.'),
            const Text('• Pour la sauvegarde sur Google Drive (futur), nous ajouterons OAuth et upload automatique.'),
          ],
        ),
      ),
    );
  }
}
