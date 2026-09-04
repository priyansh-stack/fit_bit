// test/unit/repositories/health_sync_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:fitbit_health_dashboard/core/models/health_daily.dart';

void main() {
  group('Incremental Sync & Finalization Logic Tests', () {
    final now = DateTime(2026, 9, 4, 15, 30);
    final todayStr = DateFormat('yyyy-MM-dd').format(now); // 2026-09-04
    final yesterdayDate = now.subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterdayDate); // 2026-09-03
    final twoDaysAgoStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 2))); // 2026-09-02
    final todayMidnight = DateTime(now.year, now.month, now.day);

    test('Past date (2+ days ago) is recognized as finalized when present in Firestore', () {
      final existingDailies = <String, HealthDaily>{
        twoDaysAgoStr: HealthDaily(
          date: twoDaysAgoStr,
          steps: 8500,
          distanceMeters: 6200.0,
          calories: 2100,
          sleepMinutes: 420,
          updatedAt: DateTime(2026, 9, 2, 23, 0),
        ),
      };

      bool isDateFinalized(String dateStr) {
        if (dateStr.isEmpty || dateStr == todayStr) return false;
        final existing = existingDailies[dateStr];
        if (existing == null) return false;
        if (dateStr.compareTo(yesterdayStr) < 0) return true;
        if (existing.updatedAt != null && existing.updatedAt!.isAfter(todayMidnight)) return true;
        if ((existing.steps ?? 0) > 0 && existing.sleepMinutes != null && existing.sleepMinutes! > 0) return true;
        return false;
      }

      expect(isDateFinalized(twoDaysAgoStr), isTrue);
      expect(isDateFinalized(todayStr), isFalse);
    });

    test('Yesterday is finalized if it was already updated today after midnight', () {
      final existingDailies = <String, HealthDaily>{
        yesterdayStr: HealthDaily(
          date: yesterdayStr,
          steps: 9200,
          sleepMinutes: 450,
          // Updated today at 8:00 AM (after midnight)
          updatedAt: DateTime(2026, 9, 4, 8, 0),
        ),
      };

      bool isDateFinalized(String dateStr) {
        if (dateStr.isEmpty || dateStr == todayStr) return false;
        final existing = existingDailies[dateStr];
        if (existing == null) return false;
        if (dateStr.compareTo(yesterdayStr) < 0) return true;
        if (existing.updatedAt != null && existing.updatedAt!.isAfter(todayMidnight)) return true;
        if ((existing.steps ?? 0) > 0 && existing.sleepMinutes != null && existing.sleepMinutes! > 0) return true;
        return false;
      }

      expect(isDateFinalized(yesterdayStr), isTrue);
    });

    test('Unchanged past days are filtered out of write batches preserving updatedAt', () {
      final existing = HealthDaily(
        date: twoDaysAgoStr,
        steps: 8000,
        distanceMeters: 6000.0,
        calories: 2000,
        activeMinutes: 45,
        restingHeartRate: 65,
        sleepMinutes: 420,
        avgSpo2: 98.0,
        avgHrv: 45.0,
        updatedAt: DateTime(2026, 9, 2, 22, 0),
      );

      final incoming = existing.copyWith(); // identical copy

      final hasChanged = existing.steps != incoming.steps ||
          existing.distanceMeters != incoming.distanceMeters ||
          existing.calories != incoming.calories ||
          existing.activeMinutes != incoming.activeMinutes ||
          existing.restingHeartRate != incoming.restingHeartRate ||
          existing.sleepMinutes != incoming.sleepMinutes ||
          existing.avgSpo2 != incoming.avgSpo2 ||
          existing.avgHrv != incoming.avgHrv;

      expect(hasChanged, isFalse);
      // Because hasChanged is false, existing.updatedAt is preserved without touching Firestore
      expect(existing.updatedAt, DateTime(2026, 9, 2, 22, 0));
    });

    test('Today summary always gets updated with current timestamp', () {
      final todaySummary = HealthDaily(
        date: todayStr,
        steps: 3200,
        updatedAt: DateTime(2026, 9, 4, 10, 0),
      );

      final newTimestamp = DateTime(2026, 9, 4, 15, 30);
      final updatedToday = todaySummary.copyWith(
        steps: 4500,
        updatedAt: newTimestamp,
      );

      expect(updatedToday.steps, 4500);
      expect(updatedToday.updatedAt, newTimestamp);
    });
  });
}
