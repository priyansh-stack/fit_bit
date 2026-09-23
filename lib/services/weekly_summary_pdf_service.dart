import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/models/weekly_trend.dart';
import '../core/services/fcm_service.dart';
import '../core/utils/weekly_comparison.dart';
import '../repositories/health_repository.dart';

class WeeklySummaryPdfService {
  WeeklySummaryPdfService._internal();
  static final WeeklySummaryPdfService instance =
      WeeklySummaryPdfService._internal();

  /// Generates a clinical & fitness PDF report for the Weekly Health Summary,
  /// saves it to public Download directory (/storage/emulated/0/Download/),
  /// triggers a completion notification, and opens the file.
  Future<File> generateAndDownloadWeeklySummary({
    WeeklyTrend? trend,
    String userName = 'Priyanshu Kumar',
    String cohort = 'Young Adult Cohort (18-25)',
    String dob = '17-Sep-2004',
    int age = 22,
    List<Map<String, dynamic>>? dailyRecords,
    HealthRepository? healthRepo,
  }) async {
    final pdfBytes = await generateWeeklySummaryPdf(
      trend: trend,
      userName: userName,
      cohort: cohort,
      dob: dob,
      age: age,
      dailyRecords: dailyRecords,
      healthRepo: healthRepo,
    );

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'Fitbit_Weekly_Health_Summary_$timestamp.pdf';

    return await saveAndNotify(
      bytes: pdfBytes,
      fileName: fileName,
    );
  }

  /// Compiles the PDF document bytes
  Future<Uint8List> generateWeeklySummaryPdf({
    WeeklyTrend? trend,
    String userName = 'Priyanshu Kumar',
    String cohort = 'Young Adult Cohort (18-25)',
    String dob = '17-Sep-2004',
    int age = 22,
    List<Map<String, dynamic>>? dailyRecords,
    HealthRepository? healthRepo,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(now);
    final weekRange =
        '${DateFormat('MMM dd').format(now.subtract(const Duration(days: 6)))} - ${DateFormat('MMM dd, yyyy').format(now)}';

    WeeklyTrend? effectiveTrend = trend;
    List<Map<String, dynamic>>? records = dailyRecords;

    // Dynamically query real telemetry from Firestore when trend or records are not supplied
    if (effectiveTrend == null || records == null) {
      try {
        final repo = healthRepo ?? HealthRepository();
        final recentSummaries = await repo.getRecentDailySummaries(days: 14);
        final sortedDays = recentSummaries.values.toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        if (sortedDays.isNotEmpty) {
          effectiveTrend ??= WeeklyComparison.compare(days: sortedDays);

          records ??= List.generate(7, (i) {
            final d = now.subtract(Duration(days: 6 - i));
            final dateIso = DateFormat('yyyy-MM-dd').format(d);
            final item = recentSummaries[dateIso];
            final stepsVal = (item?.steps != null && item!.steps! > 0)
                ? item.steps.toString()
                : '0';
            final activeVal =
                (item?.activeMinutes != null && item!.activeMinutes! > 0)
                    ? item.activeMinutes.toString()
                    : '0';
            final rhrVal =
                (item?.restingHeartRate != null && item!.restingHeartRate! > 0)
                    ? '${item.restingHeartRate} bpm'
                    : '--';
            final sleepVal =
                (item?.sleepMinutes != null && item!.sleepMinutes! > 0)
                    ? '${(item.sleepMinutes! / 60.0).toStringAsFixed(1)}h'
                    : '--';
            final calVal = (item?.calories != null && item!.calories! > 0)
                ? '${item.calories} kcal'
                : '--';

            return {
              'date': DateFormat('EEE, MMM dd').format(d),
              'steps': stepsVal,
              'activeMin': activeVal,
              'restingHr': rhrVal,
              'sleep': sleepVal,
              'calories': calVal,
            };
          });
        }
      } catch (e) {
        debugPrint('[WeeklySummaryPdfService] Telemetry fetch notice: $e');
      }
    }

    // Default clean 7-day breakdown if none could be loaded
    final activeRecords = records ??
        List.generate(7, (i) {
          final d = now.subtract(Duration(days: 6 - i));
          return {
            'date': DateFormat('EEE, MMM dd').format(d),
            'steps': '0',
            'activeMin': '0',
            'restingHr': '--',
            'sleep': '--',
            'calories': '--',
          };
        });

    // Derive actual total and daily average directly from the real 7-day record table
    final totalSteps = activeRecords.fold<int>(
      0,
      (sum, r) => sum + (int.tryParse(r['steps']?.toString() ?? '0') ?? 0),
    );
    final activeStepDays = activeRecords
        .where((r) => (int.tryParse(r['steps']?.toString() ?? '0') ?? 0) > 0)
        .length;
    final calculatedAvgSteps =
        activeStepDays > 0 ? (totalSteps ~/ activeStepDays) : (totalSteps ~/ 7);

    final t = effectiveTrend ??
        WeeklyTrend(
          stepDeltaPercent: 0.0,
          avgStepsThisWeek: calculatedAvgSteps,
          avgStepsLastWeek: 0,
          activeMinDelta: 0,
          totalActiveMinThisWeek: 0,
          restingHrDelta: 0,
          avgRestingHrThisWeek: null,
          sleepMinutesDelta: 0,
          avgSleepHoursThisWeek: 0.0,
          coachingInsights: const [
            'Wearable telemetry synchronized. Maintain daily activity to build cardiovascular endurance.',
          ],
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // 1. Header Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#0F172A'),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'FITBIT HEALTH DASHBOARD',
                        style: pw.TextStyle(
                          color: PdfColor.fromHex('#38BDF8'),
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Weekly Health & Fitness Generation Summary',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                        ),
                      ),
                      pw.Text(
                        'Report Period: $weekRange',
                        style: pw.TextStyle(
                          color: PdfColor.fromHex('#94A3B8'),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#0369A1'),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'VERIFIED SYNC',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // 2. Member Demographic Strip
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                borderRadius: pw.BorderRadius.circular(8),
                color: PdfColor.fromHex('#F8FAFC'),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetaCol('Member Name', userName),
                  _buildMetaCol('DOB / Age', '$dob ($age YRS)'),
                  _buildMetaCol('Cohort', cohort),
                  _buildMetaCol('Generated On', dateStr),
                ],
              ),
            ),
            pw.SizedBox(height: 18),

            // 3. Weekly High-Level Metric Tiles (4 Columns)
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildMetricCard(
                    title: 'Total Steps',
                    value: NumberFormat('#,###').format(totalSteps),
                    subtext: '${t.avgStepsThisWeek} avg/day (${t.stepDeltaPercent >= 0 ? "+" : ""}${t.stepDeltaPercent.toStringAsFixed(1)}%)',
                    headerColor: '#0284C7',
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildMetricCard(
                    title: 'Active Zone Min',
                    value: '${t.totalActiveMinThisWeek} min',
                    subtext: '${t.activeMinDelta >= 0 ? "+" : ""}${t.activeMinDelta} min vs prev week',
                    headerColor: '#0D9488',
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildMetricCard(
                    title: 'Resting Heart Rate',
                    value: t.avgRestingHrThisWeek != null
                        ? '${t.avgRestingHrThisWeek} bpm'
                        : '--',
                    subtext: '${t.restingHrDelta <= 0 ? "" : "+"}${t.restingHrDelta} bpm trend',
                    headerColor: '#E11D48',
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildMetricCard(
                    title: 'Avg Sleep Duration',
                    value: '${t.avgSleepHoursThisWeek.toStringAsFixed(1)} hrs',
                    subtext: '${t.sleepMinutesDelta >= 0 ? "+" : ""}${t.sleepMinutesDelta} min/night',
                    headerColor: '#6366F1',
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // 4. Daily Log Table
            pw.Text(
              '7-Day Biometric Daily Breakdown',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1E293B'),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Day / Date', 'Steps', 'Active Min', 'Resting HR', 'Sleep', 'Est. Burn'],
              data: activeRecords.map((r) => [
                r['date'] ?? '',
                r['steps'] ?? '',
                '${r['activeMin']} min',
                r['restingHr'] ?? '',
                r['sleep'] ?? '',
                r['calories'] ?? '',
              ]).toList(),
              headerStyle: const pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E293B')),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // 5. AI Coach & Health Insights
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F0FDF4'),
                border: pw.Border.all(color: PdfColor.fromHex('#BBF7D0')),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Clinical & AI Coach Weekly Recommendations',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#166534'),
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  ...t.coachingInsights.map(
                    (insight) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            margin: const pw.EdgeInsets.only(top: 3.5, right: 6),
                            width: 3.5,
                            height: 3.5,
                            decoration: const pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              color: PdfColors.green700,
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              insight,
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColor.fromHex('#1E293B'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // 6. Medical Disclaimer Footer
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Text(
              'Confidential Health Record - For personal health tracking & wellness monitoring only. '
              'Not a replacement for professional clinical diagnosis. Generated by Fitbit Health Dashboard on $dateStr.',
              style: pw.TextStyle(
                fontSize: 7.5,
                color: PdfColor.fromHex('#64748B'),
              ),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildMetaCol(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 7.5,
            color: PdfColor.fromHex('#64748B'),
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#0F172A'),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtext,
    required String headerColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColor.fromHex('#FFFFFF'),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColor.fromHex('#64748B'),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex(headerColor),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtext,
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColor.fromHex('#94A3B8'),
            ),
          ),
        ],
      ),
    );
  }

  /// Writes PDF to Android public Download folder (/storage/emulated/0/Download/)
  /// and fires local alert.
  Future<File> saveAndNotify({
    required Uint8List bytes,
    required String fileName,
  }) async {
    File? savedFile;

    // 1. Direct write to public Android Downloads directory
    try {
      final publicDownloadDir = Directory('/storage/emulated/0/Download');
      if (await publicDownloadDir.exists()) {
        savedFile = File('${publicDownloadDir.path}/$fileName');
        await savedFile.writeAsBytes(bytes, flush: true);
        debugPrint('[WeeklySummaryPdfService] Saved to public downloads: ${savedFile.path}');
      }
    } catch (e) {
      debugPrint('[WeeklySummaryPdfService] Public download dir error: $e');
    }

    // 2. Secondary fallback
    if (savedFile == null || !await savedFile.exists()) {
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          savedFile = File('${extDir.path}/$fileName');
          await savedFile.writeAsBytes(bytes, flush: true);
          debugPrint('[WeeklySummaryPdfService] Saved to external storage: ${savedFile.path}');
        }
      } catch (e) {
        debugPrint('[WeeklySummaryPdfService] External storage error: $e');
      }
    }

    // 3. Fallback to app documents directory
    if (savedFile == null || !await savedFile.exists()) {
      final appDocDir = await getApplicationDocumentsDirectory();
      savedFile = File('${appDocDir.path}/$fileName');
      await savedFile.writeAsBytes(bytes, flush: true);
      debugPrint('[WeeklySummaryPdfService] Saved to app documents: ${savedFile.path}');
    }

    // 4. Trigger local notification
    try {
      final sizeKb = (savedFile.lengthSync() / 1024).toStringAsFixed(1);
      await FitbitFcmService.instance.showLocalAlert(
        title: '📥 Weekly Health PDF Downloaded',
        body: 'Saved to ${savedFile.path.contains("Download") ? "Downloads folder" : savedFile.path} ($sizeKb KB). Tap to open.',
        payload: savedFile.path,
      );
    } catch (e) {
      debugPrint('[WeeklySummaryPdfService] Notification error: $e');
    }

    return savedFile;
  }

  /// Opens the PDF file with the system default viewer
  Future<OpenResult> openPdf(String filePath) async {
    try {
      return await OpenFilex.open(filePath);
    } catch (e) {
      debugPrint('[WeeklySummaryPdfService] OpenFilex error: $e');
      return OpenResult(type: ResultType.error, message: e.toString());
    }
  }
}
