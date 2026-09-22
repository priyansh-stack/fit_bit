const { Paragraph, TextRun, AlignmentType, HeadingLevel } = require('C:/Users/PriyanshuKumar/.gemini/antigravity-ide/brain/6bd7368d-94f0-4349-a1f4-1ca924a7fe56/scratch/node_modules/docx');
const {
  createDocTitle,
  createSubtitle,
  createSectionHeading,
  createSubSectionHeading,
  createBody,
  createBullet,
  createCallout,
  createMatrixTable,
  createPageBreak,
  PRIMARY_COLOR,
  SECONDARY_COLOR,
  BORDER_COLOR
} = require('./helpers');

function getFrontmatter() {
  const elements = [];

  // Title Page
  elements.push(createDocTitle('FITBIT HEALTH INTELLIGENCE DASHBOARD'));
  elements.push(createSubtitle('Enterprise Architectural Specification, Mathematical Normalization Formulations, Data Pipeline Engineering & Verification Manual'));

  elements.push(new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 200, after: 400 },
    children: [
      new TextRun({ text: 'DOCUMENT REF: ', bold: true, font: 'Consolas', size: 20, color: SECONDARY_COLOR }),
      new TextRun({ text: 'ENG-SPEC-2026-FHD-001   |   ', font: 'Consolas', size: 20 }),
      new TextRun({ text: 'CLASSIFICATION: ', bold: true, font: 'Consolas', size: 20, color: SECONDARY_COLOR }),
      new TextRun({ text: 'TECHNICAL WHITE PAPER / SYSTEM ARCHITECTURE MANUAL', font: 'Consolas', size: 20 })
    ]
  }));

  elements.push(new Paragraph({
    spacing: { before: 100, after: 300 },
    children: [new TextRun({ text: '_________________________________________________________________________________', color: BORDER_COLOR })]
  }));

  // Metadata Table
  const metaHeaders = ['Specification Attribute', 'Document Detail & System Profile'];
  const metaRows = [
    ['System Name', 'Fitbit Health Intelligence Dashboard & Longitudinal Biometric Platform'],
    ['Software Version', '1.0.0 (Production Release Build 1)'],
    ['Target Run-time OS', 'Android OS (API Level 24 "Nougat" through API Level 34 "Android 14+"), Cross-Platform Flutter Engine'],
    ['Lead Engineering Org', 'Biomedical Systems Engineering & Software Architecture Core Team'],
    ['Primary Data Ingestion', 'Google Health API v4 (REST/Protobuf) & Google Fitness REST API v1'],
    ['Cryptographic Subsystem', 'Android Keystore AES-GCM-256 / iOS Keychain Hardware-Protected Vault'],
    ['Cloud Infrastructure', 'Google Cloud Platform (GCP), Firebase Authentication, Cloud Firestore, Serverless Cloud Functions (Node.js/TypeScript)'],
    ['Automated Test Coverage', '44 Comprehensive Test Suites (Unit, Cubit State, Domain Logic, Repository Mocks, UI Widgets) - 100% Pass Rate'],
    ['Release Binary Profile', 'Universal Release APK (54.4 MB) / Android App Bundle (AAB), ProGuard/R8 Bytecode Obfuscated, 99.5% Tree-Shaken Icons'],
    ['Clinical Frameworks', 'American Heart Association (AHA) Target Heart Rate Zones, Polysomnography Sleep Architecture Standards, Harris-Benedict BMR Principles']
  ];
  elements.push(createMatrixTable(metaHeaders, metaRows, [30, 70]));

  elements.push(new Paragraph({ spacing: { before: 200, after: 200 } }));

  // Document Revision History
  elements.push(createSectionHeading('Document Revision & Change Management Log'));
  const revisionHeaders = ['Rev #', 'Release Date', 'Author / Role', 'Description of Changes & Architectural Scope'];
  const revisionRows = [
    ['1.0.0', 'September 2026', 'Principal Systems Architect', 'Initial complete enterprise architecture manual, biometric formulas, pipeline specs, and verification matrix.'],
    ['0.9.5', 'September 2026', 'Lead Mobile Engineer', 'Documented BMR circadian proration engine and sleep net restorative subtraction algorithms.'],
    ['0.9.0', 'September 2026', 'Security & Cloud Engineer', 'Documented hardware-backed token encryption, Firestore isolation rules, and CI/CD secret sanitization.'],
    ['0.8.0', 'September 2026', 'QA & Verification Lead', 'Formulated comprehensive test strategy, Cubit state verification models, and regression suites.']
  ];
  elements.push(createMatrixTable(revisionHeaders, revisionRows, [10, 15, 25, 50]));

  elements.push(createPageBreak());

  // Executive Overview & Scope
  elements.push(createSectionHeading('Executive Overview & Scope of Technical Manual'));
  elements.push(createBody('This technical specification serves as the definitive reference manual and architectural blueprint for the Fitbit Health Intelligence Dashboard. It details the end-to-end design, implementation mechanics, domain algorithms, security postures, and quality assurance frameworks comprising the application.'));
  elements.push(createBody('The application was engineered to resolve critical vulnerabilities, telemetry inaccuracies, and user experience bottlenecks present across commercial wearable consumer software. By consolidating disparate biometric channels—including intraday photoplethysmography (PPG) heart rate, multi-stage sleep architecture, active zone minutes, step pacing, and caloric expenditure—into a unified, client-driven reactive pipeline, the platform empowers users with actionable, clinically contextualized health intelligence.'));

  elements.push(createCallout(
    'Notice of Medical & Engineering Intent',
    'The algorithmic models detailed herein (including the Readiness Recovery Score, Circadian BMR Proration, and American Heart Association Zone Stratification) are calibrated for physiological health tracking, training optimization, and wellness telemetry. They do not constitute diagnostic medical devices under FDA 21 CFR Part 820. The software implements enterprise-grade information security adhering to HIPAA and GDPR privacy guidelines.'
  ));

  elements.push(createSectionHeading('Document Structural Topology'));
  elements.push(createBody('This volume is organized into twelve exhaustive technical chapters:'));
  elements.push(createBullet('Contextualizes the modern wearable market, details systemic flaws in commercial health trackers, and defines core engineering objectives.', 'Chapter 1 (Problem Space & Strategic Imperative): '));
  elements.push(createBullet('Examines the five structural tiers of Clean Architecture, state flow mechanics, and dependency isolation.', 'Chapter 2 (Clean Architecture Blueprint): '));
  elements.push(createBullet('Presents a comprehensive comparative decision matrix explaining why specific technologies were selected over competing alternatives.', 'Chapter 3 (Technology Stack Decision Matrix): '));
  elements.push(createBullet('Exhaustive mathematical derivations for BMR proration, net restorative sleep, AHA zone metrics, readiness, and coaching.', 'Chapter 4 (Algorithmic & Normalization Engines): '));
  elements.push(createBullet('Formal entity definitions, type invariants, immutability guarantees, and database persistence schemas.', 'Chapter 5 (Domain Entity Specifications): '));
  elements.push(createBullet('Detailed breakdown of each UI module, widget hierarchies, rendering pipelines, and graceful fallback strategies.', 'Chapter 6 (Feature Modules & Presentation): '));
  elements.push(createBullet('OAuth 2.0 PKCE lifecycle, the single-flight asynchronous token mutex, and multi-tier cache-aside caching.', 'Chapter 7 (Hardware & Cloud Data Pipelines): '));
  elements.push(createBullet('Hardware Keystore encryption, zero-knowledge storage, Firestore path isolation, and regulatory compliance.', 'Chapter 8 (Security & Cryptography): '));
  elements.push(createBullet('Automated GitHub Actions workflows, JSON integrity guards, R8 bytecode shrinking, and APK compilation.', 'Chapter 9 (CI/CD & Release Engineering): '));
  elements.push(createBullet('Granular audit of every engineering action, root cause, mechanical fix, and delivered benefit.', 'Chapter 10 (Master Action-by-Action Matrix): '));
  elements.push(createBullet('The 44 automated test suites, boundary condition testing, and regression prevention protocols.', 'Chapter 11 (Verification Strategy & QA): '));
  elements.push(createBullet('Extensibility patterns, future hardware integration protocols, and architectural conclusions.', 'Chapter 12 (Roadmap & Extensibility): '));

  return elements;
}

module.exports = { getFrontmatter };
