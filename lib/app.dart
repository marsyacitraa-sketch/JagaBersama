import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_router.dart';
import 'core/providers/accessibility_provider.dart';
import 'core/theme/app_theme.dart';

class JagaBersamaApp extends ConsumerWidget {
  const JagaBersamaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final largeText = ref.watch(largeTextModeProvider);

    return MaterialApp.router(
      title: 'JagaBersama',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = largeText ? 1.2 : 1.0;
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
