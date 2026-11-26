import 'package:flutter_test/flutter_test.dart';
import 'package:jaga_bersama/models/health_profile.dart';
import 'package:jaga_bersama/models/health_record.dart';

void main() {
  test('HealthProfile.fromJson memetakan profil tanpa akun dan role dengan benar', () {
    final profile = HealthProfile.fromJson({
      'id': 'p-1',
      'family_id': 'f-1',
      'user_id': null,
      'full_name': 'Ibu Siti',
      'relation_label': 'Ibu',
      'role': 'member',
      'access_permission': 'view_and_edit',
      'claim_code': 'KL-123456',
      'default_height_cm': 155,
      'created_at': '2026-11-26T00:00:00Z',
    });

    expect(profile.isDependent, isTrue);
    expect(profile.roleLabel, 'Profil Dikelola');
    expect(profile.defaultHeightCm, 155.0);
    expect(profile.claimCode, 'KL-123456');
  });

  test('HealthRecord.fromJson menghitung IMT dan ringkasan metrik', () {
    final record = HealthRecord.fromJson({
      'id': 'r-1',
      'family_id': 'f-1',
      'profile_id': 'p-1',
      'recorded_by_user_id': 'u-1',
      'recorded_by_name': 'Budi',
      'recorded_at': '2026-11-26T07:00:00Z',
      'systolic': 120,
      'diastolic': 80,
      'weight_kg': 65,
      'height_cm': 170,
      'blood_sugar': 95,
      'sugar_type': 'fasting',
      'created_at': '2026-11-26T07:00:00Z',
      'updated_at': '2026-11-26T07:00:00Z',
    });

    expect(record.hasBloodPressure, isTrue);
    expect(record.bmi, closeTo(22.49, 0.05));
    expect(record.sugarTypeLabel, 'Puasa');
    expect(record.metricSummaries.length, 4);
  });
}
