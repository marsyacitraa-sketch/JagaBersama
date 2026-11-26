import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jaga_bersama/core/theme/app_theme.dart';
import 'package:jaga_bersama/core/utils/medical_evaluator.dart';
import 'package:jaga_bersama/core/widgets/app_widgets.dart';

void main() {
  testWidgets('StatusBadge dan EmptyStateView tampil dengan tema Material 3',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const Scaffold(
          body: Column(
            children: [
              StatusBadge(
                status: MedicalStatus(
                  level: HealthLevel.normal,
                  label: 'Normal',
                  detail: 'Dalam batas sehat',
                ),
              ),
              Expanded(
                child: EmptyStateView(
                  icon: Icons.health_and_safety,
                  title: 'Belum Ada Data',
                  subtitle: 'Silakan catat pemeriksaan pertama Anda',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Belum Ada Data'), findsOneWidget);
  });
}
