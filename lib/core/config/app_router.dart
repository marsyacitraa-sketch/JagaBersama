import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/env_missing_screen.dart';
import '../../features/auth/presentation/forgot_password_otp_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/dashboard/presentation/main_shell_screen.dart';
import '../../features/documents/presentation/document_viewer_screen.dart';
import '../../features/documents/presentation/upload_document_screen.dart';
import '../../features/family/presentation/activity_log_screen.dart';
import '../../features/family/presentation/add_dependent_profile_screen.dart';
import '../../features/family/presentation/edit_profile_screen.dart';
import '../../features/health_records/presentation/add_health_record_screen.dart';
import '../../features/health_records/presentation/health_record_detail_screen.dart';
import '../../features/onboarding/presentation/family_onboarding_screen.dart';
import '../../features/schedules/presentation/add_schedule_screen.dart';
import '../../models/health_document.dart';
import '../../models/health_profile.dart';
import '../../models/health_record.dart';
import '../config/app_env.dart';
import '../providers/supabase_providers.dart';
import '../theme/app_colors.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _AuthGateScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordOtpScreen(),
      ),
      GoRoute(
        path: '/record/add',
        builder: (context, state) => const AddHealthRecordScreen(),
      ),
      GoRoute(
        path: '/record/edit',
        builder: (context, state) {
          final record = state.extra as HealthRecord;
          return AddHealthRecordScreen(existingRecord: record);
        },
      ),
      GoRoute(
        path: '/record/:id',
        builder: (context, state) {
          final record = state.extra as HealthRecord;
          return HealthRecordDetailScreen(record: record);
        },
      ),
      GoRoute(
        path: '/schedule/add',
        builder: (context, state) => const AddScheduleScreen(),
      ),
      GoRoute(
        path: '/document/add',
        builder: (context, state) => const UploadDocumentScreen(),
      ),
      GoRoute(
        path: '/document/:id',
        builder: (context, state) {
          final doc = state.extra as HealthDocument;
          return DocumentViewerScreen(document: doc);
        },
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) {
          final profile = state.extra as HealthProfile;
          return EditProfileScreen(profile: profile);
        },
      ),
      GoRoute(
        path: '/family/add-dependent',
        builder: (context, state) => const AddDependentProfileScreen(),
      ),
      GoRoute(
        path: '/family/activity-logs',
        builder: (context, state) => const ActivityLogScreen(),
      ),
    ],
  );
});

class _AuthGateScreen extends ConsumerWidget {
  const _AuthGateScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppEnv.isConfigured) {
      return const EnvMissingScreen();
    }

    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const LoginScreen();
    }

    final profileAsync = ref.watch(currentProfileProvider);
    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const FamilyOnboardingScreen();
        }
        return const MainShellScreen();
      },
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primaryBlue),
              SizedBox(height: 16),
              Text('Memuat data keluarga...'),
            ],
          ),
        ),
      ),
      error: (err, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: AppColors.statusHigh,
                ),
                const SizedBox(height: 12),
                Text(
                  'Gagal terhubung ke server:\n$err',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(currentProfileProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
