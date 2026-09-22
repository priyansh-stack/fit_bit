const {
  createChapterHeading,
  createSectionHeading,
  createSubSectionHeading,
  createBody,
  createBullet,
  createSubBullet,
  createCallout,
  createMatrixTable
} = require('./helpers');

function getChapter3() {
  const elements = [];

  elements.push(createChapterHeading('3', 'Technology Stack & Architectural Decision Matrix'));

  // 3.1 Overview
  elements.push(createSectionHeading('3.1 Engineering Philosophy & Selection Principles'));
  elements.push(createBody('Every framework, library, protocol, and runtime component integrated into the Fitbit Health Intelligence Dashboard was chosen after rigorous empirical evaluation against five architectural criteria:'));
  elements.push(createBullet('Achieve consistent 60 FPS and 120 FPS rendering across mid-tier and flagship mobile devices with zero frame drops during complex graph animations.', '1. Deterministic Frame Timing: '));
  elements.push(createBullet('Minimize CPU wake-locks, background radio polling, and memory footprints to preserve all-day battery life.', '2. Battery & Power Efficiency: '));
  elements.push(createBullet('Ensure the entire user interface remains fully functional, responsive, and queryable when the physical device is disconnected from the internet.', '3. Offline-First Resilience: '));
  elements.push(createBullet('Guarantee hardware-backed cryptographic protection for user credentials and mathematical guarantees against multi-tenant data leaks.', '4. Cryptographic Security & Privacy: '));
  elements.push(createBullet('Maximize code maintainability, domain logic reusability, and automated test coverage across development lifecycles.', '5. Long-Term Maintainability: '));

  // 3.2 Detailed Evaluations
  elements.push(createSectionHeading('3.2 Comprehensive Component Evaluations & Trade-Off Analyses'));

  elements.push(createSubSectionHeading('3.2.1 Mobile Application Runtime: Flutter & Dart 3'));
  elements.push(createBody('Flutter (powered by Dart 3) was selected as the core cross-platform client development framework. Unlike traditional hybrid frameworks, Flutter compiles directly to native ARM64 machine code via the Skia and Impeller graphics rendering engines.'));
  elements.push(createBullet('Dart 3 sound null safety guarantees compile-time elimination of null-pointer exceptions, an essential requirement for mission-critical health telemetry parsing.', 'Sound Null Safety: '));
  elements.push(createBullet('Impeller bypasses runtime shader compilation, completely eliminating "shader compilation jank" when rendering multi-point Bézier heart rate curves and complex hypnogram bars.', 'Impeller Graphics Pipeline: '));
  elements.push(createBullet('Sharing 100% of mathematical normalization algorithms, BLoC state machines, and repository contracts across platforms guarantees identical biometric calculations on Android and iOS.', 'Single Codebase Integrity: '));
  elements.push(createBullet('JavaScript bridge serialization introduces CPU bottlenecks when streaming high-frequency intraday heart rate data (1,440 data points per day). Native UI components exhibit inconsistent styling and behavior across different OEM Android skins.', 'Rejected Alternative — React Native: '));
  elements.push(createBullet('Maintaining two separate codebases in Kotlin/Jetpack Compose and Swift/SwiftUI would double development overhead and inevitably introduce subtle mathematical discrepancies in readiness and recovery calculations.', 'Rejected Alternative — Dual Native (Kotlin & Swift): '));

  elements.push(createSubSectionHeading('3.2.2 State Management: flutter_bloc & Cubit'));
  elements.push(createBody('State management is the single most critical structural decision in a reactive mobile application. We selected flutter_bloc with Cubit containers to govern all state transitions.'));
  elements.push(createBullet('A Cubit enforces strict unidirectional data flow. Widgets can only trigger predefined public methods; state can only be modified by emitting new immutable state instances.', 'Unidirectional Predictability: '));
  elements.push(createBullet('The companion bloc_test package provides declarative testing primitives that allow complete verification of async data flows, debounced search streams, and error fallbacks in milliseconds.', 'Declarative Testability: '));
  elements.push(createBullet('While powerful, Riverpod introduces global provider scopes, auto-dispose lifecycle complexities, and less formal architectural boundaries for multi-engineer enterprise teams.', 'Rejected Alternative — Riverpod: '));
  elements.push(createBullet('Lacks built-in event-to-state contracts, requiring custom boilerplate for loading/success/error state handling across complex asynchronous synchronization pipelines.', 'Rejected Alternative — Provider: '));
  elements.push(createBullet('Relies heavily on global service locator anti-patterns and bypasses standard Flutter widget lifecycle trees, leading to memory leaks and untestable code.', 'Rejected Alternative — GetX: '));

  elements.push(createSubSectionHeading('3.2.3 Cloud Persistence & Identity: Cloud Firestore & Firebase Auth'));
  elements.push(createBody('User identity and longitudinal biometric summaries are managed via Firebase Authentication and Google Cloud Firestore.'));
  elements.push(createBullet('Firestore provides a built-in, indexed local document cache on the physical device. Reads execute against local disk in less than 8 milliseconds, automatically synchronizing changes with the cloud when an active connection is detected.', 'Native Offline Persistence: '));
  elements.push(createBullet('Declarative security rules enforce granular, path-level user isolation (e.g., allow read, write: if request.auth.uid == userId;), making cross-tenant data access mathematically impossible at the database engine level.', 'Strict Path-Level Isolation: '));
  elements.push(createBullet('Eliminates the operational overhead of provisioning, patching, and scaling dedicated PostgreSQL or MySQL container clusters.', 'Zero Server Maintenance: '));
  elements.push(createBullet('Building a custom relational database backend requires implementing a bespoke, bidirectional offline synchronization engine with conflict-resolution protocols, drastically increasing failure points.', 'Rejected Alternative — Custom PostgreSQL / Express Backend: '));

  elements.push(createSubSectionHeading('3.2.4 Cryptographic Vault: flutter_secure_storage'));
  elements.push(createBody('The application must store highly sensitive OAuth 2.0 access and refresh tokens. Storing these credentials in plaintext is an unacceptable vulnerability.'));
  elements.push(createBullet('On Android, tokens are encrypted using AES-GCM-256 with encryption keys generated and stored within the hardware-backed Android KeyStore (backed by a Trusted Execution Environment [TEE] or StrongBox Keymaster).', 'Hardware Keystore Integration: '));
  elements.push(createBullet('On iOS, tokens are encrypted and deposited directly into the hardware-protected iOS Keychain with kSecAttrAccessibleAfterFirstUnlock permissions.', 'iOS Keychain Hardware Vault: '));
  elements.push(createBullet('Stores unencrypted XML files in the application sandbox. Any rooted device or backup extraction tool can read tokens in plaintext, exposing the user to account takeover.', 'Rejected Alternative — SharedPreferences: '));

  elements.push(createSubSectionHeading('3.2.5 Biometric Transport: Google Health API v4 & Google Fitness REST'));
  elements.push(createBody('Biometric telemetry is ingested using an intelligent dual-API pipeline:'));
  elements.push(createBullet('Google Health API v4 serves as the primary endpoint, providing granular sleep stage classifications (deep, REM, light, awake), SpO2, breathing rate, and continuous intraday heart rate.', 'Primary Pipeline (Google Health API v4): '));
  elements.push(createBullet('Google Fitness REST API serves as an automated fallback and aggregation engine for daily step bucket rollups and active minute expenditures.', 'Secondary Pipeline (Google Fitness REST): '));
  elements.push(createBullet('Deprecated by Google, features restrictive rate-limiting tiers, and forces cumbersome browser-based OAuth redirects that degrade mobile onboarding.', 'Rejected Alternative — Legacy Fitbit Web API: '));

  elements.push(createSubSectionHeading('3.2.6 Data Visualization: FL Chart'));
  elements.push(createBody('Visualizing biometric trends requires high-performance charting:'));
  elements.push(createBullet('FL Chart compiles directly into native Flutter CustomPainter render objects. Charts utilize GPU canvas shaders to draw smooth Bézier curves, gradient fills, and interactive touch cursors with zero latency.', 'Zero-Latency GPU Canvas: '));
  elements.push(createBullet('Embedding web-based charting engines (such as Chart.js or Highcharts) within a mobile WebView consumes excessive RAM (150MB+ per view), introduces touch gesture latency, and destroys 60 FPS scrolling performance.', 'Rejected Alternative — WebView-Based Charting: '));

  // 3.3 Master Decision Matrix Table
  elements.push(createSectionHeading('3.3 Master Technology Decision Matrix'));
  elements.push(createBody('The comparative evaluation across all core system layers is summarized in the matrix below:'));

  const techMatrixHeaders = ['Subsystem Layer', 'Selected Technology', 'Core Architectural Advantage', 'Disqualified Competitors & Rationale'];
  const techMatrixRows = [
    [
      'Client Runtime',
      'Flutter & Dart 3',
      'AOT compilation to ARM64, 60/120 FPS Impeller rendering, sound null safety, 100% logic sharing.',
      'React Native (JS bridge serialization bottleneck); Dual Native (2x development cost, logic divergence).'
    ],
    [
      'State Management',
      'flutter_bloc / Cubit',
      'Predictable unidirectional streams, immutable state snapshots, exceptional testability with bloc_test.',
      'Riverpod (less structured enterprise convention); Provider (too minimal); GetX (memory leaks, anti-patterns).'
    ],
    [
      'Persistence & Cloud',
      'Cloud Firestore',
      'Sub-8ms local offline cache reads, seamless cloud sync, path-level declarative security rules.',
      'PostgreSQL/Node.js (onerous custom sync engine); SQLite (no automated multi-device cloud synchronization).'
    ],
    [
      'User Authentication',
      'Firebase Auth',
      'Secure OAuth token lifecycle, seamless Google Sign-In federation, automated session restoration.',
      'Custom JWT Server (vulnerable to secret leakage, burdensome token rotation infrastructure).'
    ],
    [
      'Secret Storage',
      'flutter_secure_storage',
      'Hardware-backed Keystore AES-GCM-256 (Android) & iOS Keychain; zero plaintext disk exposure.',
      'SharedPreferences (unencrypted plaintext XML); Hive (software keys easily extracted via APK decompilation).'
    ],
    [
      'Biometric Ingestion',
      'Google Health API v4 + Fitness REST',
      'Granular sleep stages, high-res intraday PPG, automatic aggregation buckets, high rate limits.',
      'Legacy Fitbit API (deprecated, restrictive quotas, poor UX); Local Accelerometer (inaccurate, drains battery).'
    ],
    [
      'Data Visualization',
      'FL Chart',
      'Native Skia/Impeller GPU rendering, touch cursor callbacks, gradient fills, zero bridge overhead.',
      'WebView / Chart.js (high memory footprint, jerky touch response, breaks 60 FPS scroll).'
    ],
    [
      'Application Routing',
      'GoRouter',
      'Declarative URL routing, state-driven navigation guards, deep linking, nested shell routes.',
      'Navigator 1.0 (imperative, error-prone backstack management, difficult route guarding).'
    ]
  ];
  elements.push(createMatrixTable(techMatrixHeaders, techMatrixRows, [18, 22, 35, 25]));

  return elements;
}

module.exports = { getChapter3 };
