// lib/core/utils/date_utils.dart

import 'package:intl/intl.dart';

/// Date/time utilities with proper timezone handling.
///
/// Health data is sensitive to timezone boundaries. This class ensures we
/// always use the user's local calendar day rather than raw UTC, while still
/// sending UTC timestamps to the API.
class HealthDateUtils {
  HealthDateUtils._();

  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _displayDayFormat = DateFormat('EEE');
  static final DateFormat _displayTimeFormat = DateFormat('h:mm a');
  static final DateFormat _displayMonthDay = DateFormat('MMM d');

  // ---------------------------------------------------------------------------
  // Date → String
  // ---------------------------------------------------------------------------

  /// Returns today's date as an ISO-8601 date string (yyyy-MM-dd), using
  /// the device's local timezone.
  static String todayIso() => _isoDateFormat.format(DateTime.now());

  /// Formats a [DateTime] to ISO-8601 date string (yyyy-MM-dd).
  static String toIsoDate(DateTime dt) => _isoDateFormat.format(dt);

  /// Formats a [DateTime] to a full ISO-8601 string in UTC.
  static String toIsoUtc(DateTime dt) => dt.toUtc().toIso8601String();

  /// Human-readable date: "Aug 31, 2026".
  static String toDisplayDate(DateTime dt) => _displayDateFormat.format(dt);

  /// Short day label: "Mon", "Tue".
  static String toDayLabel(DateTime dt) => _displayDayFormat.format(dt);

  /// Short month-day: "Aug 31".
  static String toMonthDay(DateTime dt) => _displayMonthDay.format(dt);

  /// Time: "10:30 AM".
  static String toDisplayTime(DateTime dt) => _displayTimeFormat.format(dt);

  // ---------------------------------------------------------------------------
  // String → DateTime
  // ---------------------------------------------------------------------------

  /// Parses an ISO-8601 date string (yyyy-MM-dd) into a local [DateTime].
  static DateTime fromIsoDate(String isoDate) {
    final parts = isoDate.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Parses an ISO-8601 timestamp into a UTC [DateTime].
  static DateTime fromIsoTimestamp(String iso) => DateTime.parse(iso).toUtc();

  // ---------------------------------------------------------------------------
  // Date Ranges
  // ---------------------------------------------------------------------------

  /// Returns the last [days] dates as ISO strings, most recent last.
  /// Uses local calendar days.
  static List<String> lastNDates(int days) {
    final today = DateTime.now();
    return List.generate(days, (i) {
      final date = today.subtract(Duration(days: days - 1 - i));
      return toIsoDate(date);
    });
  }

  /// Returns the start date (inclusive) for an initial [days]-day sync.
  static DateTime initialSyncStart(int days) =>
      DateTime.now().subtract(Duration(days: days));

  // ---------------------------------------------------------------------------
  // Sleep duration formatting
  // ---------------------------------------------------------------------------

  /// Formats total sleep minutes as "7h 12m".
  static String formatSleepMinutes(int? minutes) {
    if (minutes == null || minutes <= 0) return '--';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  // ---------------------------------------------------------------------------
  // Relative time
  // ---------------------------------------------------------------------------

  /// Returns "X min ago", "X hours ago", "Yesterday", or the formatted date.
  static String relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return toDisplayDate(dt);
  }
}
