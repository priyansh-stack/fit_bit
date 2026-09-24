// Part 1: Chapters 1 to 6
module.exports = function renderPart1(engine) {
  // =========================================================================
  // CHAPTER 1
  // =========================================================================
  console.log('Rendering Chapter 1...');
  engine.addChapterBanner(
    1,
    'INDUSTRY CONTEXT, PROBLEM SPACE & STRATEGIC IMPERATIVE',
    'The Fragmented Wearable Ecosystem & The Biometric Integrity Crisis',
    'Over the past decade, personal health telemetry has evolved into sophisticated multi-sensor physiological monitors. ' +
    'However, client software layers suffer from systemic data fragmentation, battery-draining sync routines, and uncalibrated API ' +
    'anomalies. This chapter details the four critical failure modes of consumer fitness apps and establishes our clean architectural mandate.'
  );

  engine.addSectionHeader(1, '1.1 The Fragmented Modern Wearable Ecosystem', 'The Growing Gap Between Hardware Sensors and Client Software');
  engine.addParagraph(
    'Contemporary wearable devices—ranging from the Fitbit Sense and Charge families to Google Pixel Watch and Wear OS ecosystems—' +
    'feature high-frequency photoplethysmography (PPG), pulse oximetry (SpO2), electrodermal activity (cEDA), and multi-axis accelerometers. ' +
    'Despite these hardware advancements, consumer software frequently isolates interrelated parameters across disconnected screens. ' +
    'Sleep stages are sequestered inside a sleep tab, resting heart rate is hidden within a cardiovascular view, and daily steps dominate ' +
    'the landing screen without physiological context.'
  );

  engine.addSectionHeader(2, '1.2 Systemic Flaws in Stock Mobile Health Applications');
  engine.addBullet('Severe Data Fragmentation:', 'Users cannot easily correlate changes in resting heart rate with restorative deep sleep or training strain.');
  engine.addBullet('High Network Latency & Offline Stalls:', 'Applications fail to persist structured local caches, displaying blank screens or spinners during network drops.');
  engine.addBullet('Uncontrolled Background Polling:', 'Naive polling routines rapidly exhaust mobile battery and trigger OS Doze mode process termination.');
  engine.addBullet('Proprietary "Black-Box" Recovery Scores:', 'Readiness numbers withhold their mathematical formulations, alienating informed users and clinicians.');

  engine.addSectionHeader(2, '1.3 The Biometric Integrity Crisis in Raw Sensor APIs');
  engine.addParagraph(
    'A rigorous systems audit of commercial fitness APIs identified critical data anomalies that distort clinical metrics if ingested without normalization:'
  );

  engine.addTable(
    ['Biometric Dimension', 'Raw API Behavior / Anomaly', 'Physiological & Behavioral Impact', 'Severity'],
    [
      ['Caloric Burn (BMR)', 'Full 24-hour BMR (~1,400 kcal) credited upfront at 00:00:01 AM.', 'Waking at 08:00 AM with 30 steps shows 1,430 kcal burned; destroys energy deficit tracking.', 'CRITICAL'],
      ['Sleep vs Restfulness', 'Records "Time in Bed" (562 mins) as total sleep, ignoring wake intervals.', 'Users with fragmented sleep are credited with 9+ hours; obscures sleep apnea/debt.', 'HIGH'],
      ['Sleep Attribution', 'Overnight sleep spanning Day N to N+1 is indexed to Day N.', 'Waking on Day N+1 displays an empty sleep card ("No Sleep Recorded"); breaks morning utility.', 'HIGH'],
      ['Sensor Dropouts', 'PPG contact loss during movement or charging emits 0 BPM or NaN.', 'Rolling averages crash; triggers false bradycardia warnings and anxiety.', 'MODERATE'],
      ['Intraday Sparsity', 'Minute-by-minute heart rate is throttled or delayed by cloud quotas.', 'Active Zone Minute (AZM) engines fail, showing 0 AZM despite intense workouts.', 'HIGH'],
    ],
    [110, 150, 160, 75]
  );

  engine.addCallout('DECISION', 'The Strategic Imperative of Client-Driven Normalization',
    'The platform resolves this crisis by establishing an uncompromised client-side normalization tier. Raw API streams pass ' +
    'through deterministic mathematical filters before reaching state machines or persistent storage.'
  );

  // =========================================================================
  // CHAPTER 2
  // =========================================================================
  console.log('Rendering Chapter 2...');
  engine.addChapterBanner(
    2,
    'FULL SYSTEM ARCHITECTURE & CLEAN ARCHITECTURE BLUEPRINT',
    'Multi-Tier Dependency Inversion, Layer Decoupling & Finite State Machines',
    'The platform is architected according to Clean Architecture principles, ensuring all dependencies point strictly inward toward ' +
    'pure domain entities and mathematical engines. This chapter details the four application tiers and the formal finite state machine (FSM) ' +
    'specifications governing the user experience.'
  );

  engine.addSectionHeader(1, '2.1 Clean Architecture Tier Inversion');
  engine.addParagraph(
    'By isolating the presentation layer, state management, algorithmic domain rules, and data persistence, the system guarantees ' +
    'that UI components can be redesigned or backend cloud endpoints replaced without altering core physiological business logic.'
  );

  engine.addSectionHeader(2, '2.2 Finite State Machine (FSM) Specifications');

  engine.addSectionHeader(3, '2.2.1 DashboardCubit State Transitions');
  engine.addTable(
    ['Initial State', 'Triggering Intent', 'Guard Condition', 'Target State', 'UI Rendering Effect'],
    [
      ['DashboardInitial', 'loadDashboard()', 'Cold-start or tab activation', 'DashboardLoading(isRefreshing: false)', 'Full-screen shimmer loading skeleton.'],
      ['DashboardLoading', 'Cache hit emitted', 'Local Firestore cache (<8ms)', 'DashboardLoaded(isOptimistic: true)', 'Populates cards instantly with cached metrics.'],
      ['DashboardLoaded', 'refreshDashboard()', 'Pull-to-refresh gesture', 'DashboardLoaded(isRefreshing: true)', 'Displays spinning top indicator; preserves current view.'],
      ['DashboardLoaded', 'Live sync delta', 'Remote APIs return normalized biometrics', 'DashboardLoaded(isRefreshing: false)', 'Smoothly cross-fades values to live telemetry.'],
      ['DashboardLoading', 'Timeout / Fatal API', '3 retries fail; cache empty', 'DashboardError(message, retryable)', 'Renders ErrorView with humanized retry action.'],
    ],
    [95, 105, 105, 110, 80]
  );

  engine.addSectionHeader(3, '2.2.2 HeartCubit State Transitions');
  engine.addTable(
    ['Initial State', 'Triggering Intent', 'Guard Condition', 'Target State', 'UI Rendering Effect'],
    [
      ['HeartInitial', 'loadHeartData()', 'Heart tab activated', 'HeartLoading()', 'Renders pulse shimmer animation on hero card.'],
      ['HeartLoading', 'RHR time series', '14-day history available', 'HeartLoaded(rhr: 69, avg: 93)', 'Displays hero card, 14-day baseline, Bezier chart, AHA zones.'],
      ['HeartLoaded', 'Today RHR unrecorded', 'today.rhr == null && history exists', 'HeartLoaded(isHistoricalFallback: true)', 'Displays "Last recorded · 69 bpm"; avoids blank state.'],
      ['HeartLoading', 'Repository failure', 'Cache miss + network failure', 'HeartError(errorMessage)', 'Renders card-level retry banner.'],
    ],
    [95, 105, 105, 110, 80]
  );

  engine.addSectionHeader(3, '2.2.3 AuthBloc State Transitions');
  engine.addParagraph(
    'Authentication transitions manage the token lifecycle securely. On launch, AuthBloc evaluates hardware KeyStore tokens. ' +
    'Valid credentials transition to Authenticated(user), triggering GoRouter redirection to /dashboard; missing credentials route to /login.'
  );

  // =========================================================================
  // CHAPTER 3
  // =========================================================================
  console.log('Rendering Chapter 3...');
  engine.addChapterBanner(
    3,
    'TECHNOLOGY STACK & ARCHITECTURAL DECISION MATRIX',
    'Flutter 3.x, flutter_bloc, Cloud Firestore, Hardware KeyStore & FL Chart',
    'A detailed comparative evaluation of candidate technologies that culminated in the selection of Flutter 3.x, flutter_bloc, ' +
    'and Google Cloud Firestore. This chapter provides objective scoring criteria and engineering rationales for each core layer.'
  );

  engine.addSectionHeader(1, '3.1 Comprehensive Technology Evaluation Matrix');
  engine.addTable(
    ['Layer / Concern', 'Technology Selected', 'Key Alternatives Evaluated', 'Decisive Selection Rationale'],
    [
      ['Mobile Framework', 'Flutter 3.x (Dart 3)', 'React Native, Native Kotlin/Swift', 'Single codebase, 60/120 FPS Impeller engine, deterministic cross-platform UI.'],
      ['State Management', 'flutter_bloc / Cubit', 'Riverpod, Provider, GetX', 'Immutable unidirectional state streams, exceptional testability with bloc_test.'],
      ['Cloud Database', 'Google Cloud Firestore', 'Supabase, Custom PostgreSQL', 'Built-in offline SQLite cache, sub-10ms reads, declarative security rules.'],
      ['Cryptographic Storage', 'flutter_secure_storage', 'SharedPreferences, Hive unencrypted', 'Hardware-backed Android KeyStore AES-GCM-256; zero plaintext token storage.'],
      ['Data Visualization', 'FL Chart (Custom Shaders)', 'Syncfusion, Native Canvas, WebView', 'High-performance GPU rendering, custom Bezier curves, interactive touch listeners.'],
      ['AI Engine', 'Google Gemini 2.5 Flash / Pro', 'OpenAI GPT-4o, Local Ollama', 'Ultra-fast sub-second latency, 1M context token window, direct Google Cloud REST integration.'],
    ],
    [105, 115, 125, 150]
  );

  // =========================================================================
  // CHAPTER 4
  // =========================================================================
  console.log('Rendering Chapter 4...');
  engine.addChapterBanner(
    4,
    'ALGORITHMIC & NORMALIZATION ENGINES: MATHEMATICAL FORMULATIONS',
    'Circadian BMR Proration, Restorative Sleep Net, Tri-Factor Readiness & AHA Zones',
    'The core mathematical foundation of the platform. This chapter details the algorithmic formulations that convert raw sensor feeds ' +
    'into honest physiological metrics, eliminating sensor artifacts and providing clinically actionable insights.'
  );

  engine.addSectionHeader(1, '4.1 Circadian BMR Proration Algorithm');
  engine.addParagraph(
    'To eliminate the 1,400 kcal upfront morning burn artifact, the platform implements a time-weighted proration function for the active day:'
  );

  engine.addFormulaCard(
    'CIRCADIAN BMR PRORATION FORMULA',
    'BMR_prorated(t) = BMR_baseline × ((Hour(t) + Minute(t) / 60) / 24)\n' +
    'Total_Calories(t) = BMR_prorated(t) + Active_Calories_Tracked(t)'
  );

  engine.addParagraph(
    'For historical days, the full 24-hour BMR baseline is preserved. For the current active day, calories scale linearly with circadian progression.'
  );

  engine.addSectionHeader(2, '4.2 Net Restorative Sleep Formulation');
  engine.addFormulaCard(
    'NET RESTORATIVE SLEEP FORMULATION',
    'T_restorative = T_in_bed - T_awake - (T_restless × 0.5)\n' +
    'Efficiency(%) = (T_restorative / T_in_bed) × 100'
  );

  engine.addSectionHeader(3, '4.3 Tri-Factor Readiness Recovery Engine');
  engine.addFormulaCard(
    'TRI-FACTOR READINESS RECOVERY SCORE (0 - 100)',
    'Readiness = (S_sleep × 0.40) + (S_hrv_rhr × 0.35) + (S_strain_balance × 0.25)\n' +
    'Where: S_sleep = Sleep Efficiency Score, S_hrv_rhr = Heart Rate Recovery, S_strain = Acute-to-Chronic Load Ratio'
  );

  engine.addTable(
    ['Readiness Score', 'Recovery Classification', 'Physiological State & Recommendation'],
    [
      ['85 – 100', 'OPTIMAL', 'Autonomic nervous system fully recovered. Prime condition for high-intensity training (HIT) or PR attempts.'],
      ['70 – 84', 'GOOD', 'Adequate homeostatic recovery. Moderate to high training capacity; normal cognitive resilience.'],
      ['50 – 69', 'FAIR / MODERATE', 'Elevated resting HR or sleep deficit. Maintain active recovery, mobility, or zone 2 aerobic base.'],
      ['0 – 49', 'COMPROMISED', 'Acute systemic fatigue, chronic sleep deprivation, or immune activation. Mandatory rest day recommended.'],
    ],
    [90, 110, 295]
  );

  // =========================================================================
  // CHAPTER 5
  // =========================================================================
  console.log('Rendering Chapter 5...');
  engine.addChapterBanner(
    5,
    'DOMAIN DATA MODELS & STRUCTURAL SCHEMAS',
    'BiometricAggregates, Intraday Samples, Sleep Stages & Journal Models',
    'Strongly typed, immutable domain models engineered in pure Dart. This chapter details JSON serialization, copyWith patterns, ' +
    'and schema migration strategies ensuring backward compatibility.'
  );

  engine.addSectionHeader(1, '5.1 Master HealthDaily Aggregate Entity');
  engine.addParagraph(
    'HealthDaily encapsulates a complete 24-hour physiological profile. It contains normalized step totals, active calories, ' +
    'prorated BMR, resting heart rate, sleep efficiency, and readiness tier scores.'
  );

  engine.addTable(
    ['Entity Field', 'Data Type', 'Validation Rules & Range', 'Physiological Meaning'],
    [
      ['date', 'DateTime', 'ISO-8601 YYYY-MM-DD', 'Calendar day of attribution (adjusted for 04:00 AM wake threshold).'],
      ['steps', 'int', '≥ 0, typical [0..50,000]', 'Total kinetic steps recorded across 24 hours.'],
      ['restingHeartRate', 'int?', 'Range [35..140] bpm', 'Overnight minimum photoplethysmography heart rate baseline.'],
      ['sleepDurationMinutes', 'int', 'Range [0..900] mins', 'Net restorative sleep time (excluding awake intervals).'],
      ['sleepScore', 'int', 'Range [0..100]', 'Calculated composite sleep quality score.'],
      ['readinessScore', 'int', 'Range [0..100]', 'Tri-factor autonomic readiness score.'],
      ['caloriesBurned', 'int', '≥ 0, typical [1,200..6,000]', 'Prorated BMR plus tracked active energy expenditure.'],
      ['activeZoneMinutes', 'int', '≥ 0, typical [0..240]', 'Minutes spent in Fat Burn, Cardio, or Peak heart rate zones.'],
    ],
    [115, 75, 130, 175]
  );

  // =========================================================================
  // CHAPTER 6
  // =========================================================================
  console.log('Rendering Chapter 6...');
  engine.addChapterBanner(
    6,
    'CORE APPLICATION FEATURE MODULES',
    'Clinical Command HUD, Intraday PPG, Sleep Architecture, AZM Strain & Cloud Sync',
    'The five core user-facing presentation modules that translate normalized domain models into interactive health intelligence, ' +
    'including interactive rendering mechanics, chart touch interactions, and PDF summary exports.'
  );

  engine.addSectionHeader(1, '6.1 The Clinical Command HUD & Executive KPI Ring');
  engine.addParagraph(
    'The HUD serves as the primary operational cockpit. At its center is the Tri-Factor Readiness Recovery Ring (86 Optimal), accompanied by four ' +
    'quick-stat metric cards: Steps (progress bar against 10,000 goal), Active Zone Minutes (against 30m AHA target), Calories Burned ' +
    '(prorated gauge), and Sleep Score (71% Sleep Efficiency).'
  );

  engine.addSectionHeader(2, '6.2 Heart & Cardiovascular Intelligence Module');
  engine.addParagraph(
    'Features the Resting Heart Rate Hero Card displaying current RHR (69 bpm), 14-day rolling average (93 bpm), and interactive Bezier trend ' +
    'curves. Implements American Heart Association (AHA) heart rate zones (Fat Burn 50-69%, Cardio 70-84%, Peak 85%+).'
  );

  engine.addSectionHeader(3, '6.3 Sleep Staging & Architecture Module');
  engine.addParagraph(
    'Visualizes the 4 clinical sleep stages (Deep N3, Light N1/N2, REM, and Awake) using multi-colored stacked interval bars. Evaluates sleep hygiene ' +
    'and provides automated sleep quality recommendations.'
  );

  engine.addSectionHeader(4, '6.4 Weekly Health Summary PDF Export Subsystem');
  engine.addParagraph(
    'A clinical-grade PDF generation engine (WeeklySummaryPdfService) compiles 7-day longitudinal metrics, resting heart rate curves, ' +
    'sleep architecture averages, and AI coaching insights into a standardized medical report. The service writes directly to user-accessible storage.'
  );
};
