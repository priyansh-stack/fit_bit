const {
  createChapterHeading,
  createSectionHeading,
  createSubSectionHeading,
  createBody,
  createBullet,
  createSubBullet,
  createCallout,
  createCodeBlock,
  createMatrixTable
} = require('./helpers');

function getChapter5() {
  const elements = [];

  elements.push(createChapterHeading('5', 'Domain Entity Specifications & Data Schemas'));

  // 5.1 Philosophy
  elements.push(createSectionHeading('5.1 Domain Modeling Philosophy & Immutability Contracts'));
  elements.push(createBody('The Domain Layer embodies the stateful data contracts of the application. To eliminate subtle concurrency bugs and ensure deterministic rendering across asynchronous widget builds, all domain entities adhere to three immutable design principles:'));
  elements.push(createBullet('Every field across all domain classes is declared as final. Once instantiated, an entity instance can never be mutated. State transformations are achieved exclusively through copyWith() copy-constructor methods.', '1. Strict Object Immutability: '));
  elements.push(createBullet('Entities extend Equatable. Equality is computed by evaluating the values of internal properties rather than object memory references. This allows Flutter BLoC to perform efficient widget rebuild pruning by detecting identical states.', '2. Value-Based Equality: '));
  elements.push(createBullet('Entities implement bidirectional serialization (fromJson() and toJson() / toFirestore()). Schema migrations and missing JSON keys are handled with defensive fallbacks, preventing runtime parsing crashes.', '3. Defensive Serialization Contracts: '));

  // 5.2 HealthDaily
  elements.push(createSectionHeading('5.2 HealthDaily: The Master Daily Aggregate Entity'));
  elements.push(createBody('HealthDaily represents the unified physiological record for a single 24-hour calendar day. It encapsulates aggregated metrics derived from both Google Health API v4 and Google Fitness REST.'));

  const dailyHeaders = ['Field Name', 'Dart Type', 'Nullability', 'Validation Invariant & Physiological Meaning'];
  const dailyRows = [
    ['date', 'DateTime', 'Non-Null', 'Calendar date normalized to 00:00:00 UTC for consistent temporal indexing.'],
    ['steps', 'int', 'Non-Null', 'Total validated pedometer count (>= 0). Default: 0.'],
    ['calories', 'int', 'Non-Null', 'Total normalized calories burned including circadian BMR proration (>= 0).'],
    ['distanceMeters', 'double', 'Non-Null', 'Cumulative physical displacement in meters (>= 0.0). Derived from stride sensors/GPS.'],
    ['activeMinutes', 'int', 'Non-Null', 'Cumulative duration of moderate-to-vigorous physical activity (MVPA) (>= 0).'],
    ['restingHeartRate', 'int?', 'Nullable', 'Estimated baseline waking resting heart rate in BPM [35..130]. Null if unrecorded.'],
    ['sleepMinutes', 'int', 'Non-Null', 'Net restorative sleep duration (excluding wakefulness) in minutes (>= 0).'],
    ['sleepScore', 'int?', 'Nullable', 'Normalized 100-point wearable sleep score [0..100]. Null if no session recorded.'],
    ['hrvRmssd', 'double?', 'Nullable', 'Root Mean Square of Successive Differences of R-R intervals in milliseconds [5..200].'],
    ['spo2Percentage', 'double?', 'Nullable', 'Peripheral capillary oxygen saturation percentage [70.0..100.0].'],
    ['breathingRate', 'double?', 'Nullable', 'Sleeping respiratory rate in breaths per minute (RPM) [8.0..30.0].'],
    ['syncStatus', 'SyncStatus', 'Non-Null', 'Enum: pending, synced, syncing, error. Tracks cloud synchronization state.'],
    ['lastSyncedAt', 'DateTime', 'Non-Null', 'Wall-clock timestamp of the most recent successful upstream/downstream sync.']
  ];
  elements.push(createMatrixTable(dailyHeaders, dailyRows, [20, 15, 15, 50]));

  elements.push(createCodeBlock(
`class HealthDaily extends Equatable {
  final DateTime date;
  final int steps;
  final int calories;
  final double distanceMeters;
  final int activeMinutes;
  final int? restingHeartRate;
  final int sleepMinutes;
  final int? sleepScore;
  final double? hrvRmssd;
  final double? spo2Percentage;
  final double? breathingRate;
  final SyncStatus syncStatus;
  final DateTime lastSyncedAt;

  const HealthDaily({
    required this.date,
    this.steps = 0,
    this.calories = 0,
    this.distanceMeters = 0.0,
    this.activeMinutes = 0,
    this.restingHeartRate,
    this.sleepMinutes = 0,
    this.sleepScore,
    this.hrvRmssd,
    this.spo2Percentage,
    this.breathingRate,
    this.syncStatus = SyncStatus.pending,
    required this.lastSyncedAt,
  });

  Map<String, dynamic> toFirestore() => {
    'date': date.toIso8601String(),
    'steps': steps,
    'calories': calories,
    'distanceMeters': distanceMeters,
    'activeMinutes': activeMinutes,
    'restingHeartRate': restingHeartRate,
    'sleepMinutes': sleepMinutes,
    'sleepScore': sleepScore,
    'hrvRmssd': hrvRmssd,
    'spo2Percentage': spo2Percentage,
    'breathingRate': breathingRate,
    'syncStatus': syncStatus.name,
    'lastSyncedAt': lastSyncedAt.toIso8601String(),
  };

  factory HealthDaily.fromFirestore(Map<String, dynamic> json) => HealthDaily(
    date: DateTime.parse(json['date'] as String),
    steps: (json['steps'] as num?)?.toInt() ?? 0,
    calories: (json['calories'] as num?)?.toInt() ?? 0,
    distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
    activeMinutes: (json['activeMinutes'] as num?)?.toInt() ?? 0,
    restingHeartRate: (json['restingHeartRate'] as num?)?.toInt(),
    sleepMinutes: (json['sleepMinutes'] as num?)?.toInt() ?? 0,
    sleepScore: (json['sleepScore'] as num?)?.toInt(),
    hrvRmssd: (json['hrvRmssd'] as num?)?.toDouble(),
    spo2Percentage: (json['spo2Percentage'] as num?)?.toDouble(),
    breathingRate: (json['breathingRate'] as num?)?.toDouble(),
    syncStatus: SyncStatus.values.byName(json['syncStatus'] as String? ?? 'pending'),
    lastSyncedAt: json['lastSyncedAt'] != null 
        ? DateTime.parse(json['lastSyncedAt'] as String) 
        : DateTime.now(),
  );

  @override
  List<Object?> get props => [
    date, steps, calories, distanceMeters, activeMinutes,
    restingHeartRate, sleepMinutes, sleepScore, hrvRmssd,
    spo2Percentage, breathingRate, syncStatus, lastSyncedAt,
  ];
}`, 'DART DOMAIN ENTITY & SERIALIZATION: HealthDaily'));

  // 5.3 HeartRateRecord & Zones
  elements.push(createSectionHeading('5.3 HeartRateRecord & HeartRateZones: Cardiovascular Telemetry'));
  elements.push(createBody('Cardiovascular data is partitioned between instantaneous sensor records (HeartRateRecord) and aggregated physiological training distributions (HeartRateZones).'));

  const hrHeaders = ['Entity / Field', 'Data Type', 'Description & Domain Invariant'];
  const hrRows = [
    ['HeartRateRecord.bpm', 'int', 'Instantaneous photoplethysmography (PPG) pulse measurement in BPM [30..240].'],
    ['HeartRateRecord.timestamp', 'DateTime', 'UTC timestamp of the sensor reading. Enforces monotonic chronological ordering.'],
    ['HeartRateRecord.confidence', 'double', 'Signal-to-noise ratio confidence score [0.0..1.0] reported by sensor firmware.'],
    ['HeartRateZones.outOfZoneMinutes', 'int', 'Minutes spent < 50% max HR. Passive daily baseline.'],
    ['HeartRateZones.fatBurnMinutes', 'int', 'Minutes spent 50% to 69% max HR. Yields 1x Active Zone Minute per minute.'],
    ['HeartRateZones.cardioMinutes', 'int', 'Minutes spent 70% to 84% max HR. Yields 2x Active Zone Minutes per minute.'],
    ['HeartRateZones.peakMinutes', 'int', 'Minutes spent >= 85% max HR. Yields 2x Active Zone Minutes per minute.'],
    ['HeartRateZones.activeZoneMinutes', 'int', 'Total earned AZM = (FatBurn * 1) + (Cardio * 2) + (Peak * 2).']
  ];
  elements.push(createMatrixTable(hrHeaders, hrRows, [25, 20, 55]));

  // 5.4 SleepRecord
  elements.push(createSectionHeading('5.4 SleepRecord: Polysomnography Stage Breakdown'));
  elements.push(createBody('SleepRecord models clinical hypnograms by partitioning sleep sessions into standard polysomnography stages:'));

  const sleepHeaders = ['Property', 'Type', 'Physiological Classification & Clinical Significance'];
  const sleepRows = [
    ['id', 'String', 'Unique GUID derived from user UID and session start timestamp.'],
    ['startTime', 'DateTime', 'Initial bedtime timestamp marking physical recumbency.'],
    ['endTime', 'DateTime', 'Final rising timestamp marking conclusion of the sleep episode.'],
    ['totalInBedMinutes', 'int', 'Total elapsed duration in bed = endTime - startTime.'],
    ['awakeMinutes', 'int', 'Cumulative restless tossing and nocturnal awakenings. Subtracted from in-bed time.'],
    ['lightSleepMinutes', 'int', 'NREM Stage 1 and Stage 2 sleep. Facilitates initial metabolic slowing and memory stabilization.'],
    ['deepSleepMinutes', 'int', 'NREM Stage 3/4 slow-wave sleep. Essential for human growth hormone release and physical repair.'],
    ['remSleepMinutes', 'int', 'Rapid Eye Movement sleep. Vital for cognitive synthesis, emotional regulation, and neural plasticity.'],
    ['sleepScore', 'int', 'Standardized 100-point score computed via our multi-factor scoring function.']
  ];
  elements.push(createMatrixTable(sleepHeaders, sleepRows, [20, 15, 65]));

  // 5.5 Wire Payloads
  elements.push(createSectionHeading('5.5 Upstream Wire Protocols: Google Health API v4 & Fitness Payloads'));
  elements.push(createBody('The application transparently ingests and deserializes raw REST/JSON payloads emitted by upstream Google services:'));

  elements.push(createCodeBlock(
`{
  "sleep": [
    {
      "logId": 45892189012,
      "startTime": "2026-09-04T22:30:00.000Z",
      "endTime": "2026-09-05T07:15:00.000Z",
      "duration": 31500000,
      "timeInBed": 562,
      "minutesAwake": 37,
      "minutesAsleep": 525,
      "efficiency": 93,
      "levels": {
        "summary": {
          "deep": { "count": 4, "minutes": 120, "thirtyDayAvgMinutes": 105 },
          "wake": { "count": 22, "minutes": 37, "thirtyDayAvgMinutes": 42 },
          "light": { "count": 28, "minutes": 310, "thirtyDayAvgMinutes": 320 },
          "rem": { "count": 5, "minutes": 95, "thirtyDayAvgMinutes": 90 }
        }
      }
    }
  ]
}`, 'JSON WIRE PAYLOAD: Google Health API v4 Sleep Endpoint'));

  elements.push(createCodeBlock(
`{
  "bucket": [
    {
      "startTimeMillis": "1788566400000",
      "endTimeMillis": "1788652800000",
      "dataset": [
        {
          "dataSourceId": "derived:com.google.step_count.delta:com.google.android.gms:aggregated",
          "point": [
            {
              "startTimeNanos": "1788566400000000000",
              "endTimeNanos": "1788652800000000000",
              "value": [{ "intVal": 10482 }]
            }
          ]
        },
        {
          "dataSourceId": "derived:com.google.calories.expended:com.google.android.gms:aggregated",
          "point": [
            {
              "startTimeNanos": "1788566400000000000",
              "endTimeNanos": "1788652800000000000",
              "value": [{ "fpVal": 648.5 }]
            }
          ]
        }
      ]
    }
  ]
}`, 'JSON WIRE PAYLOAD: Google Fitness REST Aggregated Bucket'));

  return elements;
}

module.exports = { getChapter5 };
