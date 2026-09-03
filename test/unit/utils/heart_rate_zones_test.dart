// test/unit/utils/heart_rate_zones_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fitbit_health_dashboard/core/models/heart_rate_zones.dart';
import 'package:fitbit_health_dashboard/core/models/heart_rate_record.dart';

void main() {
  group('HeartRateZones Model & Calculator Tests', () {
    test('computes correct zone thresholds based on age', () {
      // Age 30 -> Max HR = 220 - 30 = 190 bpm
      final zones = HeartRateZones.fromBiometrics(age: 30);

      expect(zones.maxHeartRate, 190);
      expect(zones.fatBurnMin, 95); // 50% of 190
      expect(zones.cardioMin, 133); // 70% of 190
      expect(zones.peakMin, 162); // 85% of 190
    });

    test('categorizes intraday heart rate records into zones correctly', () {
      final now = DateTime.now();
      final records = [
        HeartRateRecord(timestamp: now, bpm: 70), // Out of zone (< 95)
        HeartRateRecord(timestamp: now, bpm: 85), // Out of zone (< 95)
        HeartRateRecord(timestamp: now, bpm: 105), // Fat burn (95 - 132)
        HeartRateRecord(timestamp: now, bpm: 120), // Fat burn (95 - 132)
        HeartRateRecord(timestamp: now, bpm: 140), // Cardio (133 - 161)
        HeartRateRecord(timestamp: now, bpm: 170), // Peak (>= 162)
      ];

      final zones = HeartRateZones.fromBiometrics(age: 30, records: records);

      expect(zones.outOfZoneMinutes, 2);
      expect(zones.fatBurnMinutes, 2);
      expect(zones.cardioMinutes, 1);
      expect(zones.peakMinutes, 1);

      // Active Zone Minutes: FatBurn (2*1) + Cardio (1*2) + Peak (1*2) = 2 + 2 + 2 = 6
      expect(zones.activeZoneMinutes, 6);
      expect(zones.totalElevatedMinutes, 4);
      expect(zones.progress, closeTo(6 / 22, 0.01));
    });

    test('strictly returns zero zone minutes when no raw records are present', () {
      final zones = HeartRateZones.fromBiometrics(
        age: 30,
        records: const [],
      );

      expect(zones.fatBurnMinutes, 0);
      expect(zones.cardioMinutes, 0);
      expect(zones.peakMinutes, 0);
      expect(zones.activeZoneMinutes, 0);
    });

    test('handles empty data safely', () {
      final zones = HeartRateZones.fromBiometrics();

      expect(zones.outOfZoneMinutes, 0);
      expect(zones.fatBurnMinutes, 0);
      expect(zones.cardioMinutes, 0);
      expect(zones.peakMinutes, 0);
      expect(zones.activeZoneMinutes, 0);
      expect(zones.progress, 0.0);
    });
  });
}
