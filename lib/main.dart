import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/articles/pages/articles_page.dart';
import 'features/auth/pages/users_page.dart';
import 'features/settings/backup_page.dart';
import 'features/ventes/pages/ventes_page.dart';
import 'features/ventes/pages/history_page.dart';
import 'features/ventes/pages/statistics_page.dart';
import 'data/database/database_service.dart';
import 'core/theme/app_theme.dart';
import 'features/ventes/providers/vente_provider.dart';
import 'features/articles/providers/article_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation sqflite FFI pour desktop (Windows)
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbService = await DatabaseService.create();
  runApp(ProviderScope(overrides: [databaseServiceProvider.overrideWithValue(dbService)], child: const MyApp()));
}

class MyApp extends StatelessWidget {
  final Widget? home;
  const MyApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boutique Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: home ?? const LoginPage());
  }
}


// LoginPage now consumes authProvider
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _pinController = TextEditingController();
  final _nameController = TextEditingController();

  Future<void> _savePinAndContinue() async {
    final pin = _pinController.text.trim();
    final name = _nameController.text.trim().isEmpty ? 'Superadmin' : _nameController.text.trim();
    if (pin.length < 4) {
      _showError('Le PIN doit contenir au moins 4 chiffres.');
      return;
    }
    try {
      await ref.read(authProvider.notifier).setPin(pin, name: name);
      if (!mounted) return;
      _goHome();
    } catch (e) {
      _showError('Erreur lors de la création du Superadmin: ${e.toString()}');
    }
  }

  Future<void> _login() async {
    final pin = _pinController.text.trim();
    final ok = await ref.read(authProvider.notifier).verifyPin(pin);
    if (!ok) {
      _showError('PIN incorrect');
      return;
    }
    if (!mounted) return;
    _goHome();
  }

  void _goHome() {
    // read current user synchronously to avoid async gaps with BuildContext
    final currentUser = ref.read(authProvider).asData?.value;
    final role = currentUser?.role ?? 'Employee';
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage(role: role)));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, st) => Scaffold(body: Center(child: Text('Erreur: $err'))),
      data: (user) {
        final isFirst = user == null;
        return Scaffold(
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(child: Icon(Icons.store), radius: 28),
                      const SizedBox(height: 12),
                      Text('Bienvenue dans votre Boutique', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(isFirst ? 'Configuration initiale' : 'Connexion', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 16),
                      if (isFirst)
                        TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nom du Super Administrateur')),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pinController,
                        decoration: const InputDecoration(labelText: 'Code PIN (4 chiffres minimum)'),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isFirst)
                            OutlinedButton(onPressed: _savePinAndContinue, child: const Text('Terminer'))
                          else
                            OutlinedButton(onPressed: _login, child: const Text('Se connecter')),
                          TextButton(onPressed: () => _pinController.clear(), child: const Text('Effacer'))
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  final String role;
  const HomePage({super.key, required this.role});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _selected = 'home';

  Widget _buildContent(String id) {
    switch (id) {
      case 'articles':
        return const ArticlesPage();
      case 'sales':
        return const VentesPage();
      case 'history':
        return const HistoryPage();
      case 'statistics':
        return const StatisticsPage();
      case 'users':
        return const UsersPage();
      case 'settings':
        return const BackupPage();
      default:
        // use the new dashboard widget for a clean, responsive home
        return HomeDashboard(role: widget.role, onSelect: (id) => setState(() => _selected = id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role.toLowerCase();

    final allItems = [
      {'id': 'home', 'label': 'Accueil', 'icon': Icons.dashboard, 'roles': ['superadmin', 'admin', 'employee']},
      {'id': 'articles', 'label': 'Articles', 'icon': Icons.inventory, 'roles': ['superadmin', 'admin']},
      {'id': 'sales', 'label': 'Ventes', 'icon': Icons.shopping_cart, 'roles': ['superadmin', 'admin', 'employee']},
      {'id': 'history', 'label': 'Historique', 'icon': Icons.history, 'roles': ['superadmin', 'admin', 'employee']},
      {'id': 'statistics', 'label': 'Statistiques', 'icon': Icons.bar_chart, 'roles': ['superadmin', 'admin']},
      {'id': 'users', 'label': 'Utilisateurs', 'icon': Icons.people, 'roles': ['superadmin', 'admin']},
      {'id': 'settings', 'label': 'Paramètres', 'icon': Icons.settings, 'roles': ['superadmin', 'admin']},
    ];

    final menuItems = allItems.where((it) => (it['roles'] as List).contains(role)).toList();

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 700;

      final sidebar = Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // Removed the large gradient header as requested; keep a compact logo row
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                child: Row(children: [
                  const CircleAvatar(backgroundColor: AppTheme.primaryContainer, child: Icon(Icons.store, color: AppTheme.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Menu', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black))),
                ]),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: menuItems.length,
                  itemBuilder: (ctx, i) {
                    final it = menuItems[i];
                    final id = it['id'] as String;
                    final selected = _selected == id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Material(
                        color: selected ? AppTheme.primary.withOpacity(0.04) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() => _selected = id);
                            if (narrow) Navigator.of(context).pop();
                          },
                          child: Row(
                            children: [
                              // accent bar
                              Container(
                                width: 4,
                                height: 48,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(color: selected ? AppTheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(2)),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(children: [
                                    Icon(it['icon'] as IconData, color: selected ? AppTheme.primary : Colors.grey[700]),
                                    const SizedBox(width: 12),
                                    Text(it['label'] as String, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Divider(),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final notifier = ref.read(authProvider.notifier);
                      final navigator = Navigator.of(context);
                      await notifier.logout();
                      if (!mounted) return;
                      navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
                    },
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text('Se déconnecter'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      return Scaffold(
        // no AppBar: header is inside the dashboard for a cleaner look
        drawer: narrow ? sidebar : null,
        body: Row(
          children: [
            if (!narrow)
              SizedBox(
                width: 260,
                child: sidebar,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // top row: show small menu icon when narrow to open drawer
                        if (narrow)
                          Align(alignment: Alignment.topRight, child: Builder(builder: (c) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(c).openDrawer()))),
                        Expanded(child: _buildContent(_selected)),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      );
    });
  }
}

// Top-level HomeDashboard implementation
class HomeDashboard extends ConsumerWidget {
  final String role;
  final void Function(String id) onSelect;
  const HomeDashboard({super.key, required this.role, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(builder: (context, constraints) {
      final ventes = ref.watch(ventesListProvider);
      final articles = ref.watch(articlesNotifierProvider);

      // group ventes by sale_id (show most recent groups)
      final Map<String, List> grouped = {};
      for (final v in ventes) {
        final key = (v.saleId ?? v.id);
        grouped.putIfAbsent(key, () => []).add(v);
      }
      final recentKeys = grouped.keys.toList()
        ..sort((a, b) => grouped[b]!.first.createdAt.compareTo(grouped[a]!.first.createdAt));

      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // header (simple color block + title)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              child: LayoutBuilder(builder: (hhCtx, hhConstraints) {
                final headerHeight = hhConstraints.maxWidth < 700 ? 110.0 : 140.0;
                return SizedBox(
                  height: headerHeight,
                  width: double.infinity,
                  child: Container(
                    color: AppTheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.store, color: AppTheme.primary)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('Tableau de bord', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black)),
                            const SizedBox(height: 6),
                            Text('Bienvenue — $role', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),

            // shortcuts
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ElevatedButton.icon(onPressed: () => onSelect('sales'), icon: const Icon(Icons.add_shopping_cart), label: const Text('Nouvelle vente'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14))),
                const SizedBox(width: 12),
                OutlinedButton.icon(onPressed: () => onSelect('articles'), icon: const Icon(Icons.inventory), label: const Text('Articles'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14))),
                const SizedBox(width: 12),
                OutlinedButton.icon(onPressed: () => onSelect('history'), icon: const Icon(Icons.history), label: const Text('Historique'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14))),
                const SizedBox(width: 12),
                OutlinedButton.icon(onPressed: () => onSelect('settings'), icon: const Icon(Icons.cloud_upload), label: const Text('Sauvegarder'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14))),
              ]),
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 16),
            // Stats: row with 3 equal columns on wide screens, stacked on narrow
            LayoutBuilder(builder: (sctx, sc) {
              final wide = sc.maxWidth >= 100;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _StatCard(title: 'Chiffre du jour', value: '0')),
                    const SizedBox(width: 16),
                    Expanded(child: _StatCard(title: 'Articles en stock', value: articles.length.toString())),
                    const SizedBox(width: 16),
                    Expanded(child: _StatCard(title: 'Bénéfice', value: '0')),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(padding: const EdgeInsets.only(bottom: 16.0), child: _StatCard(title: 'Chiffre du jour', value: '0')),
                  Padding(padding: const EdgeInsets.only(bottom: 16.0), child: _StatCard(title: 'Articles en stock', value: articles.length.toString())),
                  Padding(padding: const EdgeInsets.only(bottom: 16.0), child: _StatCard(title: 'Bénéfice', value: '0')),
                ],
              );
            }),

            const SizedBox(height: 20),

            // recent activity — show up to 5 latest sales groups
            Text('Dernières ventes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  if (recentKeys.isEmpty) const Text('Aucune vente récente', style: TextStyle(color: Colors.grey))
                  else
                    Column(
                      children: recentKeys.take(5).map((k) {
                        final group = grouped[k]!;
                        final first = group.first;
                        final date = DateTime.fromMillisecondsSinceEpoch(first.createdAt).toLocal();
                        final names = group.map((v) {
                          final found = articles.where((a) => a.id == v.articleId);
                          return found.isEmpty ? 'Unknown' : found.first.name;
                        }).toList();
                        final total = group.fold<double>(0, (s, e) => s + e.total);
                        return ListTile(
                          title: Text('${date.toString().split('.').first}'),
                          subtitle: Text(names.join(', ')),
                          trailing: Text(total.toStringAsFixed(2)),
                        );
                      }).toList(),
                    )
                ]),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

// Small statistic card
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ]),
      ),
    );
  }
}

// Small reusable feature card with hover effect
class _FeatureCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _FeatureCard({required this.label, required this.icon, required this.onTap});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  double _elevation = 2;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _elevation = 6),
      onExit: (_) => setState(() => _elevation = 2),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Card(
          elevation: _elevation,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircleAvatar(radius: 28, backgroundColor: AppTheme.primary.withAlpha(40), child: Icon(widget.icon, size: 28, color: AppTheme.primary)),
              const SizedBox(height: 12),
              Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ));
    }
}
