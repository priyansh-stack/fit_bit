const fs = require('fs');
const path = require('path');
const FitbitPDFEngine = require('./fitbit_pdf_engine');
const renderPart1 = require('./chapters_p1');
const renderPart2 = require('./chapters_p2');
const renderPart3 = require('./chapters_p3');
const renderPart4 = require('./chapters_p4');

const outputPath = path.resolve(__dirname, '../docs/Fitbit_Health_Dashboard_Comprehensive_Architecture_Guide.pdf');

// Ensure output directory exists
const docsDir = path.dirname(outputPath);
if (!fs.existsSync(docsDir)) {
  fs.mkdirSync(docsDir, { recursive: true });
}

console.log('Initializing FitbitPDFEngine for Full Platform Architecture Manual (Build 2)...');
const engine = new FitbitPDFEngine(outputPath);

// =========================================================================
// FRONTMATTER
// =========================================================================
console.log('Rendering Cover Page...');
engine.addCoverPage(
  'FITBIT HEALTH INTELLIGENCE DASHBOARD',
  'Enterprise Architectural Specification, Mathematical Normalization Formulations, Data Pipeline Engineering & Verification Manual',
  'v1.0.0 Production Release (Build 2)',
  'September 2026',
  'Mobile Systems Architects, Biomedical Engineers, Security Officers & Clinical Telemetry Teams'
);

console.log('Rendering Executive Manifesto...');
engine.addExecutiveManifesto();

console.log('Rendering System Architecture Overview...');
engine.addSystemArchitectureOverview();

console.log('Rendering Table of Contents (Parts I - IV)...');
const tocSections = [
  {
    partTitle: 'TABLE OF CONTENTS: PART I',
    partSubtitle: 'Architecture Foundations, Clean Design & Algorithmic Engines',
    partDesc: 'Part I details the clinical problem space, four-tier Clean Architecture, core technology decisions, mathematical formulas, and presentation modules.',
    chapters: [
      { num: 1, title: 'Industry Context, Problem Space & Strategic Imperative', subtitle: 'The Fragmented Wearable Ecosystem & The Biometric Integrity Crisis', sectionTag: 'Section 1' },
      { num: 2, title: 'Clean Architecture Blueprint & Reactive State Machines', subtitle: 'Multi-Tier Dependency Inversion, Layer Decoupling & Finite State Machines', sectionTag: 'Section 2' },
      { num: 3, title: 'Technology Stack & Architectural Decisions', subtitle: 'Flutter 3.x, flutter_bloc, Cloud Firestore, Hardware KeyStore & FL Chart', sectionTag: 'Section 3' },
      { num: 4, title: 'Algorithmic & Normalization Engines', subtitle: 'Circadian BMR Proration, Restorative Sleep, Tri-Factor Readiness & AHA Zones', sectionTag: 'Section 4' },
      { num: 5, title: 'Domain Data Models & Structural Schemas', subtitle: 'BiometricAggregates, Intraday Samples, Sleep Stages & Journal Models', sectionTag: 'Section 5' },
      { num: 6, title: 'Core Application Feature Modules', subtitle: 'Clinical Command HUD, Intraday PPG, Sleep Architecture, AZM Strain & PDF', sectionTag: 'Section 6' },
    ],
    callout: { type: 'INFO', title: 'Algorithmic Focus Notice', text: 'Chapters 4 and 5 provide explicit mathematical proofs for circadian BMR pacing, resting heart rate baselines, and sleep stage architecture.' }
  },
  {
    partTitle: 'TABLE OF CONTENTS: PART II',
    partSubtitle: 'AI Health Coach, Pipelines, Engineering Matrix & Verification',
    partDesc: 'Part II covers the Gemini AI Health Coach, Google Health API v4 sync pipelines, cryptographic security, the 20-action matrix, 45 test suites, and roadmap.',
    chapters: [
      { num: 7, title: 'Fitbit AI Health Coach & Conversational Intelligence', subtitle: 'Gemini 2.5 Flash & Pro Dual Engine, Grounded Telemetry & Private Coaching Library', sectionTag: 'Section 7' },
      { num: 8, title: 'Biometric Ingestion & Synchronization Pipelines', subtitle: 'Google Health API v4, OAuth 2.0 PKCE, Single-Flight Mutex & Offline Resilience', sectionTag: 'Section 8' },
      { num: 9, title: 'Cryptographic Security, Privacy & Regulatory Compliance', subtitle: 'Android KeyStore AES-GCM-256, Zero-Knowledge Vault, Firestore Rules & HIPAA', sectionTag: 'Section 9' },
      { num: 10, title: 'CI/CD Automation, Release Engineering & Binary Optimization', subtitle: 'GitHub Actions Matrix, ProGuard/R8 Obfuscation & ARM64 Tree Shaking', sectionTag: 'Section 10' },
      { num: 11, title: 'Master Action-by-Action Engineering & Evolution Matrix', subtitle: 'Complete Record of 20 Critical Engineering Actions & Bug Eradications', sectionTag: 'Section 11' },
      { num: 12, title: 'Verification Matrix, Testing Automation & Quality Assurance', subtitle: '45 Comprehensive Automated Test Suites, Cubit Mocks & 100% Pass Rate', sectionTag: 'Section 12' },
      { num: 13, title: 'Strategic Roadmap, Clinical Evolution & Engineering Sign-Off', subtitle: 'Edge On-Device ML, Multimodal Biosignals & Final Production Verification Seal', sectionTag: 'Section 13' },
    ],
    callout: { type: 'SECURITY', title: 'Production Certification Standard', text: 'Chapters 9, 11, and 12 detail the cryptographic enclave standards, ProGuard/R8 rules, and 45 automated test suites required for production sign-off.' }
  },
  {
    partTitle: 'TABLE OF CONTENTS: PART III',
    partSubtitle: 'Data Quality, Resilience, Telemetry & Performance Engineering',
    partDesc: 'Part III covers physiological anomaly detection, offline-first sync protocols, structured observability, battery preservation, accessibility, and API contracts.',
    chapters: [
      { num: 14, title: 'Data Quality, Validation & Physiological Integrity', subtitle: 'Ingestion Anomaly Detection, Strongly-Typed Entities & Plausibility Rules', sectionTag: 'Section 14' },
      { num: 15, title: 'Offline-First Synchronization & Conflict Resolution', subtitle: 'Three-Tier Storage Hierarchy, LWW Tiebreakers & FIFO Mutation Queues', sectionTag: 'Section 15' },
      { num: 16, title: 'Observability, Diagnostics & Operational Telemetry', subtitle: 'Structured JSON Logging, 60/120 FPS Monitoring & Synthetic Probes', sectionTag: 'Section 16' },
      { num: 17, title: 'Performance, Battery & Rendering Engineering', subtitle: 'Impeller GPU Shaders, Subscription Hygiene & WorkManager Batching', sectionTag: 'Section 17' },
      { num: 18, title: 'Accessibility, UX Resilience & Information Hierarchy', subtitle: 'WCAG 2.1 AA Compliance, Screen Reader Semantics & Dynamic Text Scaling', sectionTag: 'Section 18' },
      { num: 19, title: 'API Contracts, Mapping & Versioning Strategy', subtitle: 'Google Health API v4 DTOs, Semantic Versioning & Backoff Quotas', sectionTag: 'Section 19' },
    ],
    callout: { type: 'CLINICAL', title: 'Data Quality & Performance Focus', text: 'Chapters 14 and 17 document physiological bounds checking [30..220 BPM] and sub-16ms Impeller rendering budgets.' }
  },
  {
    partTitle: 'TABLE OF CONTENTS: PART IV & APPENDIX',
    partSubtitle: 'Disaster Recovery, Threat Modeling, Runbooks & Acceptance Criteria',
    partDesc: 'Part IV covers FMEA disaster recovery, STRIDE threat models, 7-day staged store rollout, privacy analytics, engineering runbooks, and Appendix A.',
    chapters: [
      { num: 20, title: 'Disaster Recovery & Operational Resilience', subtitle: 'FMEA Analysis, Zero RPO Local Caches, Backups & Incident Playbooks', sectionTag: 'Section 20' },
      { num: 21, title: 'Threat Modeling & Privacy-by-Design Expansion', subtitle: 'STRIDE Threat Modeling, Data Minimization & OWASP Audits', sectionTag: 'Section 21' },
      { num: 22, title: 'Release Readiness & Store Deployment', subtitle: 'Pre-Release Checklist, Google Play Health Connect & 7-Day Rollout', sectionTag: 'Section 22' },
      { num: 23, title: 'Product Analytics, Experimentation & Feature Governance', subtitle: 'Privacy-Preserving Telemetry, Retention KPIs & Remote Config Gates', sectionTag: 'Section 23' },
      { num: 24, title: 'Implementation Checklist & Engineering Runbook', subtitle: 'Development Setup, Build Commands & On-Call Emergency Runbooks', sectionTag: 'Section 24' },
      { num: 25, title: 'Appendix A: Acronym Glossary & Master Acceptance Criteria', subtitle: 'Comprehensive Acronym Glossary & 15-Point Production Acceptance Matrix', sectionTag: 'Appendix A' },
    ],
    callout: { type: 'DECISION', title: 'Operational Readiness Assurance', text: 'Chapters 20 through 24 and Appendix A establish the operational runbook and verified acceptance criteria for production certification.' }
  }
];

engine.addTableOfContents(tocSections);

// =========================================================================
// RENDER CHAPTERS ACROSS ALL 4 PARTS
// =========================================================================
console.log('Rendering Chapters 1 to 6 (Part I)...');
renderPart1(engine);

console.log('Rendering Chapters 7 to 13 (Part II)...');
renderPart2(engine);

console.log('Rendering Chapters 14 to 19 (Part III)...');
renderPart3(engine);

console.log('Rendering Chapters 20 to 24 & Appendix A (Part IV)...');
renderPart4(engine);

// Finalize Headers, Footers & Save
console.log('Finalizing headers and footers across all pages...');
engine.finalizeHeadersAndFooters();

engine.writeStream.on('finish', () => {
  console.log('\n======================================================');
  console.log('FITBIT PLATFORM ARCHITECTURE MANUAL COMPILED SUCCESSFULLY!');
  console.log(`Total Pages Generated: ${engine.totalPages}`);
  console.log(`Output Path: ${outputPath}`);
  console.log('======================================================\n');

  // Also copy to health project and artifacts
  try {
    const healthDocsDir = 'C:/Users/PriyanshuKumar/health/fitbit_health_dashboard/docs';
    if (!fs.existsSync(healthDocsDir)) fs.mkdirSync(healthDocsDir, { recursive: true });
    fs.copyFileSync(outputPath, path.join(healthDocsDir, 'Fitbit_Health_Dashboard_Comprehensive_Architecture_Guide.pdf'));
    console.log('Copied to health project docs successfully.');
  } catch (err) {
    console.warn('Notice copying to health project:', err.message);
  }

  try {
    const artifactPath = 'C:/Users/PriyanshuKumar/.gemini/antigravity-ide/brain/7f03ceda-4101-41a1-9394-1338c33e949e/Fitbit_Health_Dashboard_Comprehensive_Architecture_Guide.pdf';
    fs.copyFileSync(outputPath, artifactPath);
    console.log('Copied to conversation artifacts successfully.');
  } catch (err) {
    console.warn('Notice copying to artifacts:', err.message);
  }
});
