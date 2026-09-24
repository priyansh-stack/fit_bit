import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitbit_health_dashboard/services/weekly_summary_pdf_service.dart';
import 'package:fitbit_health_dashboard/core/models/weekly_trend.dart';

void main() {
  group('WeeklySummaryPdfService Tests', () {
    test('generateWeeklySummaryPdf builds valid non-empty PDF bytes with real telemetry', () async {
      final realRecords = [
        {'date': 'Thu, Sep 17', 'steps': '5252', 'activeMin': '95', 'restingHr': '68 bpm', 'sleep': '7.1h', 'calories': '2100 kcal'},
        {'date': 'Fri, Sep 18', 'steps': '5478', 'activeMin': '115', 'restingHr': '67 bpm', 'sleep': '7.4h', 'calories': '2400 kcal'},
        {'date': 'Sat, Sep 19', 'steps': '102', 'activeMin': '6', 'restingHr': '69 bpm', 'sleep': '6.8h', 'calories': '1600 kcal'},
        {'date': 'Sun, Sep 20', 'steps': '3252', 'activeMin': '101', 'restingHr': '66 bpm', 'sleep': '7.5h', 'calories': '2000 kcal'},
        {'date': 'Mon, Sep 21', 'steps': '5143', 'activeMin': '98', 'restingHr': '67 bpm', 'sleep': '7.2h', 'calories': '2200 kcal'},
        {'date': 'Tue, Sep 22', 'steps': '1384', 'activeMin': '78', 'restingHr': '68 bpm', 'sleep': '7.0h', 'calories': '2100 kcal'},
        {'date': 'Wed, Sep 23', 'steps': '6139', 'activeMin': '111', 'restingHr': '66 bpm', 'sleep': '7.6h', 'calories': '2000 kcal'},
      ];

      const trend = WeeklyTrend(
        stepDeltaPercent: 12.5,
        avgStepsThisWeek: 3821,
        avgStepsLastWeek: 3400,
        activeMinDelta: 45,
        totalActiveMinThisWeek: 604,
        restingHrDelta: -1,
        avgRestingHrThisWeek: 67,
        sleepMinutesDelta: 20,
        avgSleepHoursThisWeek: 7.2,
        coachingInsights: [
          'Excellent activity on Sep 23 reaching 6,139 steps!',
        ],
      );

      final pdfBytes = await WeeklySummaryPdfService.instance.generateWeeklySummaryPdf(
        trend: trend,
        dailyRecords: realRecords,
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.isNotEmpty, isTrue);
      // PDF documents always start with %PDF
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, equals('%PDF'));
    });
  });
}
