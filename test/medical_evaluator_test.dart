import 'package:flutter_test/flutter_test.dart';
import 'package:jaga_bersama/core/utils/medical_evaluator.dart';

void main() {
  group('MedicalEvaluator', () {
    test('evaluasi tekanan darah normal, waspada, tinggi, dan rendah', () {
      expect(
        MedicalEvaluator.evaluateBloodPressure(115, 75).level,
        HealthLevel.normal,
      );
      expect(
        MedicalEvaluator.evaluateBloodPressure(130, 82).level,
        HealthLevel.warning,
      );
      expect(
        MedicalEvaluator.evaluateBloodPressure(145, 92).level,
        HealthLevel.high,
      );
      expect(
        MedicalEvaluator.evaluateBloodPressure(85, 55).level,
        HealthLevel.low,
      );
    });

    test('evaluasi gula darah puasa vs sewaktu', () {
      expect(
        MedicalEvaluator.evaluateBloodSugar(92, 'fasting').level,
        HealthLevel.normal,
      );
      expect(
        MedicalEvaluator.evaluateBloodSugar(110, 'fasting').level,
        HealthLevel.warning,
      );
      expect(
        MedicalEvaluator.evaluateBloodSugar(135, 'fasting').level,
        HealthLevel.high,
      );
      expect(
        MedicalEvaluator.evaluateBloodSugar(120, 'random').level,
        HealthLevel.normal,
      );
    });

    test('perhitungan dan evaluasi IMT (BMI)', () {
      final bmi = MedicalEvaluator.calculateBmi(65, 170);
      expect(bmi, isNotNull);
      expect(bmi!, closeTo(22.49, 0.05));
      expect(MedicalEvaluator.evaluateBmi(bmi).level, HealthLevel.normal);
      expect(MedicalEvaluator.evaluateBmi(28.5).level, HealthLevel.high);
    });
  });
}
