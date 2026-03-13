import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/user_auth.dart';
import '../../core/api/open_prices_client.dart';

final currencySymbolProvider = StateNotifierProvider<CurrencyNotifier, String>((ref) {
  return CurrencyNotifier();
});

class CurrencyNotifier extends StateNotifier<String> {
  CurrencyNotifier() : super('€') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('currency_symbol') ?? '€';
  }

  Future<void> set(String symbol) async {
    state = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency_symbol', symbol);
  }
}

class _OffLoginDialog extends ConsumerStatefulWidget {
  const _OffLoginDialog();

  @override
  ConsumerState<_OffLoginDialog> createState() => _OffLoginDialogState();
}

class _OffLoginDialogState extends ConsumerState<_OffLoginDialog> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _client = OpenPricesClient();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(offCredentialsProvider);
    if (current != null) {
      _userController.text = current.username;
      _passController.text = current.password;
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _saveAndVerify() async {
    final user = _userController.text.trim();
    final pass = _passController.text.trim();

    if (user.isEmpty || pass.isEmpty) return;

    setState(() => _loading = true);

    try {
      // ignore: avoid_print
      print('DEBUG LOGIN: Tentative de connexion pour $user');
      final success = await _client.login(user, pass);
      // ignore: avoid_print
      print('DEBUG LOGIN: Résultat de l\'API : $success');
      
      if (!mounted) return;

      if (success) {
        // ignore: avoid_print
        print('DEBUG LOGIN: Enregistrement des identifiants...');
        await ref.read(offCredentialsProvider.notifier).set(user, pass);
        // ignore: avoid_print
        print('DEBUG LOGIN: Enregistrement terminé.');
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connexion réussie !')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identifiants incorrects. Veuillez réessayer.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG LOGIN ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.read(offCredentialsProvider);

    return AlertDialog(
      title: const Text('Compte Open Food Facts'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Requis pour l\'analyse des tickets de caisse par l\'IA.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _userController,
            decoration: const InputDecoration(
              labelText: 'Nom d\'utilisateur',
              border: OutlineInputBorder(),
            ),
            enabled: !_loading,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mot de passe',
              border: OutlineInputBorder(),
            ),
            enabled: !_loading,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        if (current != null)
          TextButton(
            onPressed: _loading ? null : () {
              ref.read(offCredentialsProvider.notifier).clear();
              Navigator.pop(context);
            },
            child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
          ),
        FilledButton(
          onPressed: _loading ? null : _saveAndVerify,
          child: _loading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Se connecter'),
        ),
      ],
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showOffLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _OffLoginDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencySymbolProvider);
    final offCreds = ref.watch(offCredentialsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Général'),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Symbole monétaire'),
            trailing: DropdownButton<String>(
              value: currency,
              items: const [
                DropdownMenuItem(value: '€', child: Text('€ Euro')),
                DropdownMenuItem(value: '\$', child: Text('\$ Dollar')),
                DropdownMenuItem(value: '£', child: Text('£ Livre')),
                DropdownMenuItem(value: 'CHF', child: Text('CHF Franc suisse')),
              ],
              onChanged: (v) {
                if (v != null) ref.read(currencySymbolProvider.notifier).set(v);
              },
            ),
          ),
          const Divider(),
          const _SectionHeader(title: 'Services Externes'),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('Compte Open Food Facts'),
            subtitle: Text(offCreds != null 
              ? 'Connecté en tant que ${offCreds.username}' 
              : 'Non connecté'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showOffLoginDialog(context),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
