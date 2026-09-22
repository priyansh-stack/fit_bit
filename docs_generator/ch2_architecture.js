const {
  createChapterHeading,
  createSectionHeading,
  createSubSectionHeading,
  createBody,
  createBullet,
  createSubBullet,
  createCallout,
  createDiagramBlock,
  createCodeBlock,
  createMatrixTable
} = require('./helpers');

function getChapter2() {
  const elements = [];

  elements.push(createChapterHeading('2', 'Full System Architecture & Clean Architecture Blueprint'));

  // 2.1 The Architectural Paradigm
  elements.push(createSectionHeading('2.1 The Architectural Paradigm: Clean Architecture & Dependency Inversion'));
  elements.push(createBody('The Fitbit Health Intelligence Dashboard is architected in accordance with the principles of Clean Architecture formulated by Robert C. Martin, adapted for reactive, mobile-first Dart/Flutter runtimes. The core governing rule of this architecture is the Dependency Inversion Principle: source code dependencies must only point inward toward higher-level policies and domain business rules.'));
  elements.push(createBody('By decoupling the domain logic completely from UI frameworks, database drivers, and third-party network APIs, the system guarantees:'));
  elements.push(createBullet('The core biometric normalization algorithms and readiness calculations can be executed and validated in pure headless unit test environments without initializing Flutter engine bindings or Android contexts.', 'Framework Independence: '));
  elements.push(createBullet('Every UI screen and widget can be tested using mock Cubits without invoking network calls or writing to physical disk.', 'Total UI Testability: '));
  elements.push(createBullet('The underlying persistence mechanisms (e.g., swapping Firestore for an embedded SQLite database or migrating from Google Health API v4 to Apple HealthKit) can be executed without modifying a single line of presentation or domain logic.', 'Pluggable Infrastructure: '));

  // 2.2 Structural Layer Breakdown
  elements.push(createSectionHeading('2.2 Structural Layer Breakdown'));

  elements.push(createSubSectionHeading('2.2.1 Presentation Layer (UI & Interaction)'));
  elements.push(createBody('The Presentation Layer encompasses all visual widgets, screen layouts, animations, and user interaction handlers. It strictly adheres to a unidirectional presentation model:'));
  elements.push(createBullet('Widgets never contain imperative business logic, network invocations, or raw database queries. They observe immutable state emitted by Cubits via BlocBuilder, BlocConsumer, and BlocListener.', 'Declarative State Consumption: '));
  elements.push(createBullet('User interactions (such as tapping a date chip, modifying a daily step goal, or triggering a manual sync) are dispatched strictly as declarative events or method invocations on the appropriate Cubit/Bloc.', 'Intent Dispatch: '));
  elements.push(createBullet('Visual styling is centralized within the AppTheme token repository, enforcing consistent typography (Inter/Outfit), dark-mode palette values, spatial margins, and elevation shadows across all five main screens.', 'Design System Tokenization: '));

  elements.push(createSubSectionHeading('2.2.2 State Management Layer (BLoC / Cubit)'));
  elements.push(createBody('State management is governed by flutter_bloc using the Cubit specialization. A Cubit is a lightweight, predictable state container that exposes explicit methods to trigger state transitions. Unidirectional data flow is strictly preserved:'));
  elements.push(createCallout(
    'The Unidirectional Data Loop',
    'User Interaction -> Cubit Method Invoked -> Repository Async Operation -> Domain Logic Processing -> New Immutable State Emitted -> UI Re-renders via Widget Diffing'
  ));
  elements.push(createBody('The application defines six dedicated Cubits and one AuthBloc:'));
  elements.push(createBullet('Maintains user identity, Google Sign-In federation, session tokens, and authentication routing guards.', '1. AuthBloc: '));
  elements.push(createBullet('Coordinates aggregate daily health data, habit streaks, readiness scores, health coach insights, and 7-day comparative trends.', '2. DashboardCubit: '));
  elements.push(createBullet('Manages resting heart rate time-series, 14-day moving averages, American Heart Association training zones, HRV rMSSD, and SpO2 telemetry.', '3. HeartCubit: '));
  elements.push(createBullet('Governs multi-stage sleep architecture, net restorative sleep calculation, hypnograms, and sleep quality scores.', '4. SleepCubit: '));
  elements.push(createBullet('Orchestrates workout session histories, step volumes, distance metrics, and active calorie expenditure logs.', '5. ActivityCubit: '));
  elements.push(createBullet('Manages user-configurable targets (daily steps, calorie burns, sleep hours, active minutes) and persists goals to Cloud Firestore.', '6. GoalsCubit: '));
  elements.push(createBullet('Controls OAuth 2.0 connection lifecycle, token exchange states, background sync schedules, and rate-limiting backoffs.', '7. HealthConnectionCubit: '));

  elements.push(createSubSectionHeading('2.2.3 Domain & Business Logic Layer (Entities & Pure Engines)'));
  elements.push(createBody('The Domain Layer represents the operational core of the application. It consists of pure, strongly-typed Dart classes with zero external framework dependencies:'));
  elements.push(createBullet('Immutable representations of daily biometrics (HealthDaily), cardiac zones (HeartRateZones), sleep stages (SleepRecord), and recovery evaluations (ReadinessScore). All entities implement value-based equality via Equatable.', 'Pure Domain Entities: '));
  elements.push(createBullet('Deterministic mathematical calculation engines including ReadinessCalculator, HealthCoachEngine, StreakCalculator, and WeeklyComparison.', 'Normalization Engines: '));

  elements.push(createSubSectionHeading('2.2.4 Data & Repository Layer (Orchestration & Abstraction)'));
  elements.push(createBody('The Repository Layer implements the Repository Pattern, acting as a single source of truth for the upper layers. HealthConnectionRepository orchestrates data retrieval across multiple heterogeneous sources:'));
  elements.push(createBullet('Coordinates parallel requests between Google Health API v4 and Google Fitness REST, reconciling duplicate timestamps and filling sparse telemetry gaps.', 'Multi-Source Synthesis: '));
  elements.push(createBullet('Implements a single-flight asynchronous mutex to prevent concurrent refresh token requests from invalidating OAuth sessions.', 'Single-Flight Token Mutex: '));
  elements.push(createBullet('Transparently reads from Cloud Firestore local offline cache when network connectivity is degraded, seamlessly synchronizing deltas once connectivity is restored.', 'Cache-Aside Pattern: '));

  elements.push(createSubSectionHeading('2.2.5 Infrastructure & Persistence Layer'));
  elements.push(createBody('The outermost layer interfaces directly with operating system primitives and external cloud networks:'));
  elements.push(createBullet('Integrates Android KeyStore (AES-GCM-256) and iOS Keychain via flutter_secure_storage to encrypt sensitive OAuth credentials at rest.', 'Hardware Keystore: '));
  elements.push(createBullet('Persists denormalized daily summaries and historical records with path-level security rules enforcing strict multi-tenant isolation.', 'Cloud Firestore: '));
  elements.push(createBullet('Serverless Cloud Functions running on Node.js/TypeScript communicate with Google Cloud Secret Manager to execute OAuth client secret exchanges without embedding secrets in client binaries.', 'Serverless Cloud Proxy: '));

  // 2.3 System Topology Diagram
  elements.push(createSectionHeading('2.3 Comprehensive System Topology Diagram (ASCII)'));
  elements.push(createBody('The complete end-to-end data flow and architectural topology is mapped in the schematic below:'));

  const topologyDiagram = 
`+===================================================================================================+
|                                      PRESENTATION TIER (FLUTTER)                                  |
|  +------------------+  +------------------+  +------------------+  +---------------------------+  |
|  | DashboardScreen  |  |   HeartScreen    |  |   SleepScreen    |  | Activity / Connect Screens|  |
|  +--------+---------+  +--------+---------+  +--------+---------+  +-------------+-------------+  |
+===========|=====================|=====================|==========================|================+
            | (Observes States)   |                     |                          |                 
            v                     v                     v                          v                 
+===================================================================================================+
|                                    STATE MANAGEMENT TIER (BLoC / CUBIT)                           |
|  +------------------+  +------------------+  +------------------+  +---------------------------+  |
|  |  DashboardCubit  |  |    HeartCubit    |  |    SleepCubit    |  |  Activity / Goals Cubits  |  |
|  +--------+---------+  +--------+---------+  +--------+---------+  +-------------+-------------+  |
+===========|=====================|=====================|==========================|================+
            | (Dispatches Invocations & Receives Domain Entities)                  |                 
            v                                                                      v                 
+===================================================================================================+
|                                    DOMAIN & ALGORITHMIC ENGINES                                   |
|  * Circadian BMR Proration Engine               * AHA Heart Rate Zone Stratification Engine        |
|  * Restorative Sleep Net Duration Subtraction   * Tri-Factor Daily Readiness Recovery Engine       |
|  * 100-Point Polysomnography Sleep Calibrator   * Deterministic Rule-Based Health Coach Engine     |
+===================================================================================================+
                                                    |                                                
                                                    v (Synthesizes Data Contracts)                   
+===================================================================================================+
|                                     DATA & REPOSITORY TIER                                        |
|                                  HealthConnectionRepository                                       |
|  +-----------------------------+  +------------------------------+  +--------------------------+  |
|  | Single-Flight Token Mutex   |  | Multi-Source Sync Window     |  | Deduplication & Fallbacks|  |
|  +--------------+--------------+  +--------------+---------------+  +------------+-------------+  |
+=================|================================|===============================|================+
                  |                                |                               |                 
                  v (Encrypted Disk Reads)         v (Offline Document Cache)      v (HTTPS Transport)
+================================+  +==============================+  +=============================+
|       LOCAL SECURE VAULT       |  |     CLOUD FIRESTORE DB       |  |      REMOTE CLOUD APIS      |
|  * Android KeyStore (AES-GCM)  |  |  * Collection: users/{uid}   |  |  * Google Health API v4     |
|  * iOS Keychain Hardware Vault |  |  * Sub: daily_summaries      |  |  * Google Fitness REST API  |
|  * flutter_secure_storage      |  |  * Offline Persistence Cache |  |  * Firebase Cloud Functions |
+================================+  +==============================+  +=============================+`;
  elements.push(createDiagramBlock(topologyDiagram));

  // 2.4 State Machine Specifications
  elements.push(createSectionHeading('2.4 Finite State Machine (FSM) Transition Specifications'));
  elements.push(createBody('Every Cubit operates as a formal Finite State Machine (FSM). The state transitions, triggering intents, and resultant presentation behaviors are codified below:'));

  elements.push(createSubSectionHeading('2.4.1 DashboardCubit State Transitions'));
  const dashFsmHeaders = ['Initial State', 'Triggering Intent / Event', 'Transition Condition / Guard', 'Target State', 'UI Rendering Effect'];
  const dashFsmRows = [
    ['DashboardInitial', 'loadDashboard()', 'App cold-start or user navigation to Dashboard.', 'DashboardLoading(isRefreshing: false)', 'Full-screen shimmer loading skeleton with placeholder cards.'],
    ['DashboardLoading', 'Repository emits cached summaries', 'Local Firestore cache hit (<8ms).', 'DashboardLoaded(isOptimistic: true)', 'Populates cards instantly with cached data; readiness calculated.'],
    ['DashboardLoaded', 'refreshDashboard()', 'User performs pull-to-refresh gesture.', 'DashboardLoaded(isRefreshing: true)', 'Displays spinning top refresh indicator; retains current card data.'],
    ['DashboardLoaded', 'Repository emits live sync delta', 'Remote APIs return normalized biometrics.', 'DashboardLoaded(isRefreshing: false)', 'Smoothly cross-fades values to live synchronized telemetry.'],
    ['DashboardLoading / Loaded', 'Network timeout or API fatal error', '3 retry attempts fail; no local cache exists.', 'DashboardError(message, retryable)', 'Displays ErrorView with humanized explanation and "Retry Now" action.']
  ];
  elements.push(createMatrixTable(dashFsmHeaders, dashFsmRows, [18, 18, 24, 20, 20]));

  elements.push(createSubSectionHeading('2.4.2 HeartCubit State Transitions'));
  const heartFsmHeaders = ['Initial State', 'Triggering Intent', 'Guard Condition', 'Target State', 'UI Effect'];
  const heartFsmRows = [
    ['HeartInitial', 'loadHeartData()', 'Heart tab activated.', 'HeartLoading()', 'Renders pulse shimmer animation on hero card.'],
    ['HeartLoading', 'Repository returns RHR time series', '14-day history available.', 'HeartLoaded(rhr: 71, avg: 93)', 'Displays hero card, 14-day baseline pill, Bezier chart, and AHA zones.'],
    ['HeartLoaded', 'Today RHR unrecorded (early AM)', 'today.rhr == null && recentDays.isNotEmpty', 'HeartLoaded(isHistoricalFallback: true)', 'Displays "Last recorded · 71 bpm"; avoids jarring blank state.'],
    ['HeartLoading', 'Repository failure', 'Cache miss + network failure.', 'HeartError(errorMessage)', 'Renders card-level retry banner.']
  ];
  elements.push(createMatrixTable(heartFsmHeaders, heartFsmRows, [18, 18, 24, 20, 20]));

  elements.push(createSubSectionHeading('2.4.3 SleepCubit State Transitions'));
  const sleepFsmHeaders = ['Initial State', 'Triggering Intent', 'Guard Condition', 'Target State', 'UI Effect'];
  const sleepFsmRows = [
    ['SleepInitial', 'loadSleepData()', 'Sleep tab activated.', 'SleepLoading()', 'Displays moon shimmer skeleton.'],
    ['SleepLoading', 'Repository returns sleep sessions', 'Sessions parsed & date attributed.', 'SleepLoaded(score: 89, net: 525m)', 'Renders Hero Sleep Score 89, hypnogram stages, and session list.'],
    ['SleepLoaded', 'No overnight sleep detected', 'User has not slept with watch on.', 'SleepEmpty()', 'Renders informative sleep tracking onboarding guide.']
  ];
  elements.push(createMatrixTable(sleepFsmHeaders, sleepFsmRows, [18, 18, 24, 20, 20]));

  elements.push(createSubSectionHeading('2.4.4 AuthBloc State Transitions'));
  const authFsmHeaders = ['Initial State', 'Triggering Event', 'Guard Condition', 'Target State', 'UI Routing Effect'];
  const authFsmRows = [
    ['AuthInitial', 'AuthCheckRequested', 'App initialization bootstrap.', 'AuthLoading()', 'Renders native splash screen.'],
    ['AuthLoading', 'Session token exists in KeyStore', 'Valid Firebase Auth currentUser.', 'Authenticated(user)', 'GoRouter automatically redirects from /login to /dashboard.'],
    ['AuthLoading', 'No session credentials found', 'First launch or expired session.', 'Unauthenticated()', 'GoRouter redirects to /login (Google Sign-In screen).'],
    ['Unauthenticated', 'SignInWithGoogleRequested', 'User taps Google Sign-In button.', 'AuthLoading()', 'Triggers Google Identity SDK bottom sheet modal.'],
    ['AuthLoading', 'Google Sign-In succeeds', 'Firebase Auth returns valid credential.', 'Authenticated(user)', 'Persists tokens in KeyStore; navigates to /dashboard.'],
    ['Authenticated', 'SignOutRequested', 'User taps Sign Out in Profile screen.', 'Unauthenticated()', 'Purges KeyStore tokens; routes immediately to /login.']
  ];
  elements.push(createMatrixTable(authFsmHeaders, authFsmRows, [16, 20, 22, 18, 24]));

  return elements;
}

module.exports = { getChapter2 };
