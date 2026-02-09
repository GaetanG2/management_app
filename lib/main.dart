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
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: menuItems.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final it = menuItems[i];
                    final id = it['id'] as String;
                    return ListTile(
                      leading: Icon(it['icon'] as IconData, color: _selected == id ? AppTheme.primary : null),
                      title: Text(it['label'] as String),
                      selected: _selected == id,
                      onTap: () {
                        setState(() => _selected = id);
                        if (narrow) Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Se déconnecter'),
                onTap: () async {
                  final notifier = ref.read(authProvider.notifier);
                  final navigator = Navigator.of(context);
                  await notifier.logout();
                  if (!mounted) return;
                  navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
                },
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
class HomeDashboard extends StatelessWidget {
  final String role;
  final void Function(String id) onSelect;
  const HomeDashboard({super.key, required this.role, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final roleLower = role.toLowerCase();
    final allItems = [
      {'id': 'articles', 'label': 'Articles', 'subtitle': 'Gérer produits', 'icon': Icons.inventory, 'roles': ['superadmin', 'admin']},
      {'id': 'sales', 'label': 'Ventes', 'subtitle': 'Enregistrer une vente', 'icon': Icons.shopping_cart, 'roles': ['superadmin', 'admin', 'employee']},
      {'id': 'history', 'label': 'Historique', 'subtitle': 'Voir ventes passées', 'icon': Icons.history, 'roles': ['superadmin', 'admin', 'employee']},
      {'id': 'statistics', 'label': 'Statistiques', 'subtitle': 'Suivi simple', 'icon': Icons.bar_chart, 'roles': ['superadmin', 'admin']},
      {'id': 'users', 'label': 'Utilisateurs', 'subtitle': 'Comptes & rôles', 'icon': Icons.people, 'roles': ['superadmin', 'admin']},
      {'id': 'settings', 'label': 'Paramètres', 'subtitle': 'Backup & devise', 'icon': Icons.settings, 'roles': ['superadmin', 'admin']},
    ];

    final menuItems = allItems.where((it) => (it['roles'] as List).contains(roleLower)).toList();

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      // final crossAxis = width < 600 ? 1 : width < 900 ? 2 : 3; // crossAxis was unused; layout will use Wrap with responsive sizing

      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // header (simple color block + title) - removed image usage for clarity and MVP
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Container(
                  color: AppTheme.primaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                          Text('Tableau de bord', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black)),
                          const SizedBox(height: 6),
                          Text('Bienvenue — $role', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                        ]),
                      ),
                      Row(children: [
                        IconButton(onPressed: () {}, icon: const Icon(Icons.cloud_upload, color: Colors.black)),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications, color: Colors.black)),
                      ])
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // shortcuts (quick actions) — large buttons similar to Figma
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

            // search
            TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Rechercher un article, vente...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 12),

            const SizedBox(height: 16),
            // quick stats
            Wrap(spacing: 12, runSpacing: 12, children: [
              _StatCard(title: 'Chiffre du jour', value: '0'),
              _StatCard(title: 'Articles en stock', value: '0'),
              _StatCard(title: 'Bénéfice', value: '0'),
            ]),

            const SizedBox(height: 18),
            // feature shortcuts grid built from menuItems (uses provided subtitles)
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 12, children: menuItems.map((it) {
              final id = it['id'] as String;
              return SizedBox(width: 280, child: _FeatureCard(label: it['label'] as String, subtitle: it['subtitle'] as String?, icon: it['icon'] as IconData, onTap: () => onSelect(id)));
            }).toList()),

            // recent activity placeholder
            Text('Dernières ventes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [const Text('Aucune vente récente', style: TextStyle(color: Colors.grey))]))),
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
    return SizedBox(
      width: 280,
      child: Card(
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
      ),
    );
  }
}

// Small reusable feature card with hover effect
class _FeatureCard extends StatefulWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _FeatureCard({required this.label, this.subtitle, required this.icon, required this.onTap});

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
              if (widget.subtitle != null) Text(widget.subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
            ]),
          ),
        ),
      ),
    );
  }
}
