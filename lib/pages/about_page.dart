import 'package:flutter/material.dart';
import '../constants/app_info.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Hakkında')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 96,
                    height: 96,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  appName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v$appVersion',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 🔸 Açıklama
          Text(
            appDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),

          // 🔸 Ek bilgiler
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Geliştirici'),
            subtitle: const Text(appAuthor),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Sürüm'),
            subtitle: Text(appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Gizlilik Politikası'),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Gizlilik Politikası'),
                  content: const Text(
                    'CS Tasker kişisel verilerinizi toplamaz veya üçüncü taraflarla paylaşmaz. '
                    'Veriler yalnızca cihazınızda saklanır.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Kapat'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('İletişim'),
            subtitle: const Text(appAuthorContact),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              '© ${DateTime.now().year} CS Software',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
