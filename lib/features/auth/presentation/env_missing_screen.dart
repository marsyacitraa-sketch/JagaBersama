import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class EnvMissingScreen extends StatelessWidget {
  const EnvMissingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlueSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings_suggest_rounded,
                        size: 44,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Konfigurasi Supabase Belum Diisi',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'APK ini di-build tanpa SUPABASE_URL dan SUPABASE_ANON_KEY. '
                      'Pastikan Anda sudah mengisi GitHub Secrets atau parameter --dart-define saat build.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'flutter build apk --release \\\n'
                        '  --dart-define=SUPABASE_URL=... \\\n'
                        '  --dart-define=SUPABASE_ANON_KEY=...',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
