import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

import '../providers/auth_provider.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String _role = 'Employee';

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (name.isEmpty || pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom et PIN (>=4) requis')));
      return;
    }
    try {
      await ref.read(authProvider.notifier).createUser(name: name, role: _role, pin: pin);
      if (!mounted) return;
      _nameCtrl.clear();
      _pinCtrl.clear();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur créé')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showEditRoleDialog(String userId, String currentRole) async {
    String role = currentRole;
    // Let the dialog return the selected role; perform update after dialog returns
    final selected = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setState) {
        return AlertDialog(
          title: const Text('Modifier rôle'),
          content: DropdownButton<String>(
            value: role,
            items: const [
              DropdownMenuItem(value: 'Admin', child: Text('Admin')),
              DropdownMenuItem(value: 'Employee', child: Text('Employé')),
              DropdownMenuItem(value: 'Superadmin', child: Text('Superadmin'))
            ],
            onChanged: (v) => setState(() => role = v ?? role),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx2).pop(null), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.of(ctx2).pop(role), child: const Text('Enregistrer'))
          ],
        );
      }),
    );

    if (selected == null || selected == currentRole) return;
    try {
      await ref.read(authProvider.notifier).updateUserRole(userId, selected);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rôle mis à jour')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmDelete(String userId) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Confirmer'), content: const Text('Supprimer cet utilisateur ?'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Supprimer'))]));
    if (ok != true) return;
    try {
      await ref.read(authProvider.notifier).deleteUser(userId);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur supprimé')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar removed to keep UI minimal; page content includes form and list
      body: Padding(
        padding: EdgeInsets.all(AppTheme.defaultPadding),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _pinCtrl, decoration: const InputDecoration(labelText: 'PIN'), keyboardType: TextInputType.number, obscureText: true)),
                const SizedBox(width: 8),
                DropdownButton<String>(value: _role, items: const [DropdownMenuItem(value: 'Admin', child: Text('Admin')), DropdownMenuItem(value: 'Employee', child: Text('Employé')), DropdownMenuItem(value: 'Superadmin', child: Text('Superadmin'))], onChanged: (v) => setState(() => _role = v ?? 'Employee')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _create, child: const Text('Ajouter'))
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List>(
                future: ref.read(authProvider.notifier).getUsers(),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                  final users = snap.data ?? [];
                  if (users.isEmpty) return const Center(child: Text('Aucun utilisateur'));
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, i) {
                      final u = users[i];
                      return ListTile(
                        title: Text(u.name),
                        subtitle: Text(u.role),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(onPressed: () => _showEditRoleDialog(u.id, u.role), icon: const Icon(Icons.edit)),
                          IconButton(onPressed: () => _confirmDelete(u.id), icon: const Icon(Icons.delete, color: Colors.red)),
                        ]),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
