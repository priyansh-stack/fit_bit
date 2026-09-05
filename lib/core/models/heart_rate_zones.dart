// lib/core/models/heart_rate_zones.dart

import 'package:equatable/equatable.dart';
import 'heart_rate_record.dart';

/// Represents heart rate training zones and active zone minutes.
class HeartRateZones extends Equatable {
  const HeartRateZones({
    required this.maxHeartRate,
    required this.fatBurnMin,
    required this.cardioMin,
    required this.peakMin,
    this.outOfZoneMinutes = 0,
    this.fatBurnMinutes = 0,
    this.cardioMinutes = 0,
    this.peakMinutes = 0,
    this.dailyTargetAzm = 22, // ~150 Active Zone Minutes per week (AHA / WHO standard)
  });

  /// Maximum heart rate estimate (bpm).
  final int maxHeartRate;

  /// Lower threshold for Fat Burn zone (50% max HR).
  final int fatBurnMin;

  /// Lower threshold for Cardio zone (70% max HR).
  final int cardioMin;

  /// Lower threshold for Peak zone (85% max HR).
  final int peakMin;

  /// Time spent in Out of Zone / Light activity (< 50% max HR).
  final int outOfZoneMinutes;

  /// Time spent in Fat Burn zone (50% - 69% max HR).
  final int fatBurnMinutes;

  /// Time spent in Cardio zone (70% - 84% max HR).
  final int cardioMinutes;

  /// Time spent in Peak zone (>= 85% max HR).
  final int peakMinutes;

  /// Daily Active Zone Minutes target.
  final int dailyTargetAzm;

  /// Active Zone Minutes (AZM) earned.
  /// Fat Burn = 1x per minute; Cardio & Peak = 2x per minute.
  int get activeZoneMinutes =>
      fatBurnMinutes + (2 * cardioMinutes) + (2 * peakMinutes);

  /// Progress towards the daily AZM target (0.0 - 1.0+).
  double get progress =>
      dailyTargetAzm > 0 ? (activeZoneMinutes / dailyTargetAzm) : 0.0;

  /// Total active minutes across all 3 elevated zones.
  int get totalElevatedMinutes =>
      fatBurnMinutes + cardioMinutes + peakMinutes;

  /// Factory calculating thresholds and minutes from user age & heart rate data.
  factory HeartRateZones.fromBiometrics({
    int age = 30,
    int? customMaxHr,
    List<HeartRateRecord> records = const [],
    int? totalActiveMinutes,
  }) {
    final maxHr = customMaxHr ?? (220 - age).clamp(140, 210);
    final fatBurnMin = (maxHr * 0.50).round();
    final cardioMin = (maxHr * 0.70).round();
    final peakMin = (maxHr * 0.85).round();

    int outOfZoneCount = 0;
    int fatBurnCount = 0;
    int cardioCount = 0;
    int peakCount = 0;

    for (final r in records) {
      final bpm = r.bpm;
      if (bpm >= peakMin) {
        peakCount++;
      } else if (bpm >= cardioMin) {
        cardioCount++;
      } else if (bpm >= fatBurnMin) {
        fatBurnCount++;
      } else {
        outOfZoneCount++;
      }
    }

    final elevatedCount = fatBurnCount + cardioCount + peakCount;
    if (totalActiveMinutes != null && totalActiveMinutes > elevatedCount) {
      final additional = totalActiveMinutes - elevatedCount;
      final addFb = (additional * 0.70).round();
      final addCd = additional - addFb;
      fatBurnCount += addFb;
      cardioCount += addCd;
    }

    return HeartRateZones(
      maxHeartRate: maxHr,
      fatBurnMin: fatBurnMin,
      cardioMin: cardioMin,
      peakMin: peakMin,
      outOfZoneMinutes: outOfZoneCount,
      fatBurnMinutes: fatBurnCount,
      cardioMinutes: cardioCount,
      peakMinutes: peakCount,
    );
  }

  @override
  List<Object?> get props => [
        maxHeartRate,
        fatBurnMin,
        cardioMin,
        peakMin,
        outOfZoneMinutes,
        fatBurnMinutes,
        cardioMinutes,
        peakMinutes,
        dailyTargetAzm,
      ];
}
