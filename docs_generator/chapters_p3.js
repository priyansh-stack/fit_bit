// Part 3: Chapters 14 to 19
module.exports = function renderPart3(engine) {
  // =========================================================================
  // CHAPTER 14: DATA QUALITY, VALIDATION & PHYSIOLOGICAL INTEGRITY
  // =========================================================================
  console.log('Rendering Chapter 14...');
  engine.addChapterBanner(
    14,
    'DATA QUALITY, VALIDATION & PHYSIOLOGICAL INTEGRITY',
    'Ingestion Anomaly Detection, Strongly-Typed Domain Entities & Cross-Metric Plausibility Rules',
    'Wearable sensor feeds are vulnerable to motion artifacts, transmission drops, and temporal disconnections. ' +
    'This chapter details the ingestion validation pipeline, biological boundary clamps, and the cross-metric physiological ' +
    'plausibility engine that ensures only pristine data reaches state machines.'
  );

  engine.addSectionHeader(1, '14.1 Ingestion-Time Anomaly Detection & Biological Clamps');
  engine.addParagraph(
    'Raw sensor streams pass through strict mathematical bounds checks immediately upon ingestion:'
  );

  engine.addBullet('Heart Rate Clamp [30, 220] BPM:', 'Any sample outside this range is flagged as SENSOR_OUTLIER and excluded from rolling baselines.');
  engine.addBullet('Step Velocity Limit (5 steps/sec):', 'Cadence exceeding 300 steps/minute triggers VEHICLE_ARTIFACT filtering, preventing driving or train motion from inflating step metrics.');
  engine.addBullet('Sleep Stage Chronology Validator:', 'Deep sleep (N3) cannot transition directly to REM without passing through an intermediate light sleep (N2) stage; impossible sequences are flagged.');
  engine.addBullet('Calorie Plausibility Ceiling (1,500 kcal/hr):', 'Hourly energy expenditure is capped at physiological limits, preventing corrupted multiplier anomalies.');

  engine.addSectionHeader(2, '14.2 Cross-Metric Physiological Plausibility Rules');
  engine.addTable(
    ['Rule Identifier', 'Telemetry Pattern Detected', 'Cross-Metric Evaluation', 'Automated Remediation Action'],
    [
      ['PLAUS-001', 'Elevated HR (>130 BPM) with Zero Cadence', 'Steps = 0, Gyroscope = Static for >10 mins', 'Flags as acute stress event or sensor artifact; excludes from VO2 max estimation.'],
      ['PLAUS-002', 'High Step Count (>3,000) with Minimal Caloric Burn', 'Caloric burn <100 kcal over active window', 'Re-evaluates BMR active multiplier; logs telemetry divergence warning.'],
      ['PLAUS-003', 'Sleep Stage Logged During High-Motion Period', 'Accelerometry indicates walking while sleep recorded', 'Truncates sleep window; attributes motion to wakefulness.'],
    ],
    [85, 135, 135, 140]
  );

  // =========================================================================
  // CHAPTER 15: OFFLINE-FIRST SYNCHRONIZATION & CONFLICT RESOLUTION
  // =========================================================================
  console.log('Rendering Chapter 15...');
  engine.addChapterBanner(
    15,
    'OFFLINE-FIRST SYNCHRONIZATION & CONFLICT RESOLUTION',
    'Three-Tier Local Storage Hierarchy, Last-Write-Wins with Wall-Clock Tiebreakers & FIFO Mutation Queues',
    'Healthcare applications must maintain full operational integrity during network loss. This chapter details ' +
    'the local cache architecture, multi-device conflict resolution algorithms, and disk-backed background sync queues.'
  );

  engine.addSectionHeader(1, '15.1 Three-Tier Local Storage Hierarchy');
  engine.addParagraph(
    'The platform implements a multi-level storage pyramid optimizing latency and durability:'
  );

  engine.addBullet('Tier 1: In-Memory RAM State (<1ms):', 'Active Cubit/BLoC state objects held in application memory for instantaneous 60/120 FPS frame rendering.');
  engine.addBullet('Tier 2: Encrypted KeyStore Vault (<5ms):', 'Hardware-backed AES-GCM-256 secure storage for OAuth tokens, cryptographic keys, and user session state.');
  engine.addBullet('Tier 3: Indexed SQLite Document Cache (<12ms):', 'Local Firestore persistence layer indexing daily biometric documents and multi-turn AI coaching sessions.');

  engine.addSectionHeader(2, '15.2 Conflict Resolution: LWW with Clock Skew Compensation');
  engine.addParagraph(
    'When biometrics are modified across multiple devices while offline, conflicts resolve deterministically using server-timestamp ' +
    'vectors with microsecond precision. If device clocks drift, the Firestore server timestamp acts as the definitive arbitration vector.'
  );

  // =========================================================================
  // CHAPTER 16: OBSERVABILITY, DIAGNOSTICS & OPERATIONAL TELEMETRY
  // =========================================================================
  console.log('Rendering Chapter 16...');
  engine.addChapterBanner(
    16,
    'OBSERVABILITY, DIAGNOSTICS & OPERATIONAL TELEMETRY',
    'Structured JSON Logging, 60/120 FPS Frame Monitoring, Crashlytics Custom Keys & Synthetic Probes',
    'Comprehensive observability infrastructure enabling proactive detection of performance degradation, ' +
    'unhandled exceptions, and API throttling across the distributed user fleet.'
  );

  engine.addSectionHeader(1, '16.1 Structured Diagnostic Logging');
  engine.addParagraph(
    'All platform subsystems emit standardized JSON log events containing correlation IDs, timestamp, severity level, ' +
    'subsystem tag, and sanitized metadata. Personal Health Information (PHI) is strictly stripped prior to logging.'
  );

  engine.addSectionHeader(2, '16.2 Impeller Frame Budget Monitoring');
  engine.addParagraph(
    'The UI harness monitors the rendering budget: 16.6ms on 60 Hz displays and 8.3ms on 120 Hz ProMotion panels. ' +
    'Any frame taking longer than 16ms is flagged as a jank event with stack traces captured for widget tree optimization.'
  );

  // =========================================================================
  // CHAPTER 17: PERFORMANCE, BATTERY & RENDERING ENGINEERING
  // =========================================================================
  console.log('Rendering Chapter 17...');
  engine.addChapterBanner(
    17,
    'PERFORMANCE, BATTERY & RENDERING ENGINEERING',
    'Impeller GPU Shaders, Stream Subscription Hygiene, Android WorkManager Batching & Payload Compression',
    'Engineering strategies maximizing frame rates, eliminating memory leaks, preserving mobile battery life, ' +
    'and minimizing cellular data consumption across diverse Android hardware tiers.'
  );

  engine.addSectionHeader(1, '17.1 Memory Leak Elimination & Subscription Hygiene');
  engine.addParagraph(
    'To guarantee zero memory leaks during multi-hour active sessions, all Cubit stream subscriptions, TextEditingControllers, ' +
    'and AnimationControllers implement explicit lifecycle disposal inside State.dispose() overrides.'
  );

  engine.addSectionHeader(2, '17.2 Battery-Preserving Background WorkManager Pipelines');
  engine.addParagraph(
    'Background sync utilizes Android WorkManager with network-unmetered and charging constraints, avoiding battery drain ' +
    'and Doze mode termination.'
  );

  // =========================================================================
  // CHAPTER 18: ACCESSIBILITY, UX RESILIENCE & INFORMATION HIERARCHY
  // =========================================================================
  console.log('Rendering Chapter 18...');
  engine.addChapterBanner(
    18,
    'ACCESSIBILITY, UX RESILIENCE & INFORMATION HIERARCHY',
    'WCAG 2.1 AA Compliance, Screen Reader Semantics Trees, Dynamic Text Scaling & Humanized Error States',
    'Designing an inclusive, resilient biometric interface that empowers users of all physical abilities, ' +
    'supporting TalkBack screen readers, high-contrast ratios, and graceful empty states.'
  );

  engine.addSectionHeader(1, '18.1 WCAG 2.1 AA Compliance Specifications');
  engine.addBullet('Contrast Ratios:', 'Normal text maintains a minimum contrast ratio of 4.5:1 against dark backgrounds; large text and UI components maintain 3.0:1.');
  engine.addBullet('Touch Target Sizing:', 'All interactive buttons, chips, and cards provide a minimum touch target of 48x48 dp with 8 dp spacing buffers.');
  engine.addBullet('Dynamic Font Scaling:', 'UI layouts accommodate text scaling between 0.85x and 1.35x without clipping or unreadable overflows.');

  // =========================================================================
  // CHAPTER 19: API CONTRACTS, MAPPING & VERSIONING STRATEGY
  // =========================================================================
  console.log('Rendering Chapter 19...');
  engine.addChapterBanner(
    19,
    'API CONTRACTS, MAPPING & VERSIONING STRATEGY',
    'Google Health API v4 DTOs, Semantic Versioning, Deprecation Schedules & Exponential Backoff Quotas',
    'Architectural interface contracts governing communication between wearable REST endpoints, Google Health API v4, ' +
    'Gemini AI Studio, and local domain models.'
  );

  engine.addSectionHeader(1, '19.1 Ingestion Quota Management & Backoff Protocols');
  engine.addParagraph(
    'The ingestion client enforces a 100 req/min token bucket algorithm. HTTP 429 responses trigger exponential backoff with ' +
    'randomized jitter (t_backoff = 2^attempt + rand(0, 1000) ms) up to 5 retries.'
  );
};
