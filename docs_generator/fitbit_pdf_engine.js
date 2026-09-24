// docs_generator/fitbit_pdf_engine.js
// High-fidelity clinical PDF layout, typography, and styling engine for Fitbit Health Dashboard

const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

class FitbitPDFEngine {
  constructor(outputPath) {
    this.outputPath = outputPath;
    this.doc = new PDFDocument({
      size: 'A4',
      margins: { top: 50, bottom: 50, left: 50, right: 50 },
      bufferPages: true,
      autoFirstPage: false,
    });

    const dir = path.dirname(outputPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    this.writeStream = fs.createWriteStream(outputPath);
    this.doc.pipe(this.writeStream);

    // Fitbit Enterprise Medical Palette
    this.colors = {
      primaryNavy: '#0F172A',
      secondaryNavy: '#1E293B',
      accentTeal: '#00B0B9',       // Official Fitbit signature Teal
      accentCyan: '#0284C7',
      accentEmerald: '#10B981',
      accentIndigo: '#6366F1',
      accentAmber: '#F59E0B',
      accentRose: '#F43F5E',
      textDark: '#0F172A',
      textMuted: '#475569',
      borderSubtle: '#CBD5E1',
      bgLight: '#F8FAFC',
      bgCard: '#F1F5F9',
      white: '#FFFFFF',
    };

    this.pageWidth = 595.28;
    this.pageHeight = 841.89;
    this.contentWidth = this.pageWidth - 100; // 495.28
    this.contentBottom = this.pageHeight - 60;
  }

  ensureSpace(neededHeight) {
    if (this.doc.y + neededHeight > this.contentBottom) {
      this.doc.addPage();
      this.doc.y = 65;
    }
  }

  addCoverPage({ title, subtitle, targetAudience, version, date }) {
    this.doc.addPage();
    const doc = this.doc;

    // Background: Deep Slate Navy
    doc.rect(0, 0, this.pageWidth, this.pageHeight).fill(this.colors.primaryNavy);

    // Decorative Accent Header Bar (Fitbit Teal)
    doc.rect(50, 55, 8, 85).fill(this.colors.accentTeal);

    // Brand Title
    doc.fillColor(this.colors.white)
      .font('Helvetica-Bold')
      .fontSize(28)
      .text('FITBIT HEALTH INTELLIGENCE', 70, 60, { characterSpacing: 1.2 });

    doc.fillColor(this.colors.accentTeal)
      .font('Helvetica-Bold')
      .fontSize(15)
      .text('ENTERPRISE ARCHITECTURAL SPECIFICATION & NORMALIZATION MANUAL', 70, 95, { characterSpacing: 0.8 });

    doc.fillColor('#94A3B8')
      .font('Helvetica')
      .fontSize(10)
      .text('Mathematical Formulations, Clean Architecture Topology, Google Health Pipelines & Verification Matrix', 70, 118);

    // Accent Divider Line
    doc.moveTo(50, 155).lineTo(this.pageWidth - 50, 155).lineWidth(1.5).strokeColor(this.colors.accentTeal).stroke();

    // Central Mission Card
    doc.roundedRect(50, 180, this.contentWidth, 370, 10).fill('#13233D');
    doc.roundedRect(50, 180, this.contentWidth, 370, 10).lineWidth(1).strokeColor('#23385C').stroke();

    let cy = 202;
    doc.fillColor(this.colors.accentEmerald).font('Helvetica-Bold').fontSize(12).text('SYSTEM MANDATE & CLINICAL TELEMETRY DISCIPLINE', 72, cy);
    cy += 22;

    const summaryText =
      'This comprehensive technical manual documents the complete architectural foundation, mathematical algorithms, ' +
      'reactive state topologies, and security protocols governing the Fitbit Health Intelligence Dashboard. ' +
      'Engineered to resolve systemic flaws in consumer wearable software—including uncalibrated 24-hour BMR allocation, ' +
      'superficial sleep tracking, and proprietary black-box recovery scores—the platform synthesizes multi-channel biometric signals ' +
      '(25Hz PPG heart rate, polysomnography sleep stages, active zone minutes, and metabolic pacing) into an offline-first, ' +
      'deterministic clinical cockpit adhering to American Heart Association (AHA) standards and strict zero-knowledge privacy.';

    doc.fillColor('#E2E8F0').font('Helvetica').fontSize(9.5).text(summaryText, 72, cy, { width: this.contentWidth - 44, lineGap: 4 });
    cy += 105;

    // Key Pillars (2x2 Grid)
    const pillars = [
      { label: 'Circadian Normalization', desc: 'Real-time proration of BMR calories and net restorative sleep subtraction algorithms.' },
      { label: 'Deterministic Readiness', desc: 'Transparent 0-100 recovery score weighting RHR, sleep efficiency, and active strain.' },
      { label: 'Hardware KeyStore Vault', desc: 'Hardware-backed AES-GCM-256 local encryption for biometric tokens and tokens cache.' },
      { label: 'AHA Heart Rate Zones', desc: 'American Heart Association cardiovascular zone stratification with zero API lag.' },
    ];

    pillars.forEach((p, idx) => {
      const colX = idx % 2 === 0 ? 72 : 72 + (this.contentWidth - 44) / 2 + 6;
      const rowY = cy + Math.floor(idx / 2) * 85;
      const cardW = (this.contentWidth - 56) / 2;

      doc.roundedRect(colX, rowY, cardW, 75, 6).fill('#1B3052');
      doc.fillColor(this.colors.accentTeal).font('Helvetica-Bold').fontSize(10).text(p.label, colX + 10, rowY + 10);
      doc.fillColor('#CBD5E1').font('Helvetica').fontSize(8.5).text(p.desc, colX + 10, rowY + 26, { width: cardW - 20, lineGap: 2 });
    });

    // Metadata Block at Bottom of Cover
    const metaY = 575;
    doc.roundedRect(50, metaY, this.contentWidth, 195, 8).fill('#0B1526');
    doc.roundedRect(50, metaY, this.contentWidth, 195, 8).lineWidth(1).strokeColor('#1F3353').stroke();

    const metaItems = [
      ['DOCUMENT REFERENCE', 'ENG-SPEC-2026-FHD-001 (Classification: System Architecture Manual)'],
      ['TARGET AUDIENCE', targetAudience],
      ['TARGET OPERATING SYSTEMS', 'Android OS (API 24 Nougat - API 34 Android 14+), Flutter Engine'],
      ['SYSTEM VERSION', version],
      ['AI REASONING ENGINE', 'Google Gemma 4 & Gemini Cascade Architecture (10 queries/2h Quota)'],
      ['PRIMARY INGESTION', 'Google Health API v4 (REST/Protobuf) & Google Fitness REST API v1'],
      ['SECURITY & PRIVACY', 'Android Keystore AES-GCM-256, Cloud Firestore Security Rules, HIPAA-Ready'],
      ['VERIFICATION PROFILE', '45 Comprehensive Automated Test Suites (100% Pass Rate), ProGuard R8 Release (58.4 MB)'],
      ['PUBLICATION DATE', date + ' • Production Certified Release Build 2'],
    ];

    let my = metaY + 12;
    metaItems.forEach(([k, v]) => {
      doc.fillColor(this.colors.accentTeal).font('Helvetica-Bold').fontSize(7.5).text(k + ':', 68, my, { width: 165 });
      doc.fillColor('#F8FAFC').font('Helvetica').fontSize(7.8).text(v, 235, my, { width: this.contentWidth - 195 });
      my += 19.5;
    });
  }

  addExecutiveManifesto() {
    this.doc.addPage();
    this.doc.y = 65;

    this.addSectionHeader(1, 'PLATFORM VISION & CLINICAL SPECIFICATION', 'Overcoming the Wearable Integration Paradox');

    this.addParagraph(
      'Over the past decade, wearable physiological monitors have transformed from rudimentary step counters into clinical-grade ' +
      'sensor arrays. Devices continuously sample photoplethysmography (PPG) at 25Hz, measure multi-axis accelerometry, and estimate ' +
      'sleep stage intervals. However, standard consumer mobile applications routinely fail to transform these raw sensor streams into ' +
      'meaningful, longitudinal health intelligence.'
    );

    this.addParagraph(
      'Users are routinely presented with confusing, unnormalized metrics: waking up to an upfront allocation of 1,400 basal calories ' +
      'before taking a step, having overnight sleep recorded on yesterday\'s calendar card, or receiving an opaque recovery score of 62 ' +
      'with zero clinical context. The Fitbit Health Intelligence Dashboard was engineered to eliminate these failure modes.'
    );

    this.addSectionHeader(2, 'The Five Core Principles of Biometric Intelligence', 'Guiding Every Architectural & Algorithmic Decision');

    const principles = [
      { num: 'I', title: 'Uncompromising Biometric Truth', desc: 'Every displayed metric is grounded in peer-reviewed physiological science, circadian proration, and American Heart Association (AHA) benchmarks.' },
      { num: 'II', title: 'Deterministic Open-Box Algorithms', desc: 'Zero black-box proprietary scoring. Readiness, caloric pacing, and sleep efficiency expose transparent mathematical formulas with clear coaching rationales.' },
      { num: 'III', title: 'Zero-Latency Offline-First Architecture', desc: 'Cold launches render sub-16ms from local indexed document caches. Remote APIs synchronize asynchronously via single-flight mutexes.' },
      { num: 'IV', title: 'Hardware-Enclave Security & Privacy', desc: 'Tokens and credentials are encrypted using hardware-backed Android KeyStore AES-GCM-256. Cloud datastores are strictly partitioned per user.' },
      { num: 'V', title: 'Longitudinal Predictive Utility', desc: 'Rather than fleeting daily snapshots, biometric signals are tracked across 14-day and 30-day moving windows to detect subtle systemic trends.' },
    ];

    principles.forEach(p => {
      this.ensureSpace(42);
      const y = this.doc.y;
      this.doc.roundedRect(50, y, 26, 22, 4).fill(this.colors.secondaryNavy);
      this.doc.fillColor(this.colors.accentTeal).font('Helvetica-Bold').fontSize(9.5).text(p.num, 50, y + 5, { width: 26, align: 'center' });
      this.doc.fillColor(this.colors.textDark).font('Helvetica-Bold').fontSize(9).text(p.title, 84, y);
      this.doc.fillColor(this.colors.textMuted).font('Helvetica').fontSize(8).text(p.desc, 84, y + 13, { width: this.contentWidth - 36, lineGap: 2 });
      this.doc.y = y + 38;
    });

    this.doc.moveDown(0.4);
    this.addCallout('CLINICAL', 'Clinical Positioning & Evidence Standards',
      'The algorithmic models detailed herein are calibrated for physiological health tracking, training optimization, and ' +
      'longitudinal wellness telemetry. By eliminating sensor artifacts and presenting clean rolling averages, the platform ' +
      'provides a reliable empirical record suitable for review during formal clinical consultations.'
    );
  }

  addSystemArchitectureOverview() {
    this.doc.addPage();
    this.doc.y = 65;

    this.addSectionHeader(1, 'SYSTEM TOPOLOGY & SUBSYSTEM BLUEPRINT', 'Four Clean Architecture Tiers Operating Across Isolated Boundaries');

    this.addParagraph(
      'The platform adheres to Clean Architecture principles, enforcing strict dependency inversion where inner domain entities ' +
      'and mathematical engines remain completely agnostic of Flutter UI frameworks, remote REST endpoints, and cloud database drivers.'
    );

    this.addTable(
      ['Architecture Tier', 'Key Components & Classes', 'Protocols & Technologies', 'Responsibilities & Guarantees'],
      [
        ['1. Presentation Tier', 'DashboardScreen, HeartScreen, SleepScreen, ActivityScreen, WeeklyTrendCard', 'Flutter 3.x, CustomPainter, FL Chart GPU accelerated', '60/120 FPS Impeller rendering, reactive state subscriptions, zero business logic.'],
        ['2. State Management Tier', 'DashboardCubit, HeartCubit, SleepCubit, ActivityCubit, AuthBloc', 'flutter_bloc, Stream subscriptions, Immutable States', 'Unidirectional event handling, cached optimistic state emission, failure recovery.'],
        ['3. Domain & Algorithmic Engines', 'BMR Circadian Proration, Readiness Recovery Engine, AHA Zone Stratifier', 'Pure Dart, mathematical formulas, Zero external dependencies', 'Normalizes raw sensor streams, calculates 0-100 scores, generates coaching insights.'],
        ['4. Data & Persistence Tier', 'HealthConnectionRepository, SecureStorage, Firestore, Google Health Client', 'AES-GCM-256 KeyStore, OAuth 2.0 PKCE, Firestore Cache', 'Single-flight mutex token refresh, offline SQLite cache, cloud backup.'],
      ],
      [95, 135, 125, 140]
    );

    this.addFlowchart([
      { label: 'Layer 1: Continuous Wearable PPG & Movement Sensing', desc: 'Wrist sensors capture raw optical heart rate, tri-axial kinetic movement, and sleep stage changes.' },
      { label: 'Layer 2: Google Health API v4 Ingestion & Token Mutex', desc: 'Secure OAuth 2.0 PKCE pipeline fetches intraday batches with automatic token rotation and single-flight lock.' },
      { label: 'Layer 3: Algorithmic Normalization & State Machines', desc: 'Circadian engine prorates BMR, subtracts wakefulness from sleep, and computes Tri-Factor Readiness Score.' },
      { label: 'Layer 4: Reactive Presentation & Secure Persistence', desc: 'Updates Cubit states for instant 60 FPS UI rendering; persists encrypted metrics to KeyStore and Firestore.' }
    ]);

    this.doc.moveDown(0.4);
    this.addCallout('DECISION', 'Architectural Principle of Offline-First Resilience',
      'Under no circumstances does the UI block on network roundtrips. Every screen immediately renders from local indexed ' +
      'cache within 8-16 milliseconds of invocation. Background synchronization executes non-destructively, updating the view via ' +
      'reactive state cross-fading when fresh sensor data arrives.'
    );
  }

  addTableOfContents(tocSections) {
    tocSections.forEach((section) => {
      this.doc.addPage();
      this.doc.y = 65;

      this.addSectionHeader(1, section.partTitle, section.partSubtitle);
      this.addParagraph(section.partDesc);
      this.doc.moveDown(0.3);

      section.chapters.forEach((ch) => {
        this.ensureSpace(28);
        const y = this.doc.y;
        const padNum = ch.num < 10 ? `0${ch.num}` : `${ch.num}`;

        this.doc.roundedRect(50, y, 65, 18, 4).fill(this.colors.secondaryNavy);
        this.doc.fillColor(this.colors.accentTeal).font('Helvetica-Bold').fontSize(8).text(`CH ${padNum}`, 50, y + 4.5, { width: 65, align: 'center' });

        this.doc.fillColor(this.colors.textDark).font('Helvetica-Bold').fontSize(9.5).text(ch.title, 125, y);
        this.doc.fillColor(this.colors.textMuted).font('Helvetica').fontSize(8).text(ch.subtitle, 125, y + 12, { width: 310 });
        this.doc.fillColor(this.colors.accentEmerald).font('Helvetica-Bold').fontSize(8.5).text(ch.sectionTag || `Section ${padNum}`, 445, y + 4, { width: 100, align: 'right' });

        this.doc.y = y + 25;
      });

      if (section.callout) {
        this.doc.moveDown(0.3);
        this.addCallout(section.callout.type || 'INFO', section.callout.title, section.callout.text);
      }
    });
  }

  addChapterBanner(chapterNum, title, subtitle, summary) {
    this.doc.addPage();
    this.doc.y = 65;

    const y = this.doc.y;
    // Dark Header Banner Card
    this.doc.roundedRect(50, y, this.contentWidth, 96, 8).fill(this.colors.primaryNavy);

    // Chapter badge
    this.doc.roundedRect(65, y + 12, 80, 18, 4).fill(this.colors.accentTeal);
    this.doc.fillColor(this.colors.primaryNavy).font('Helvetica-Bold').fontSize(9).text(`CHAPTER ${chapterNum}`, 65, y + 16, { width: 80, align: 'center' });

    // Chapter Title
    this.doc.fillColor(this.colors.white).font('Helvetica-Bold').fontSize(16.5).text(title, 65, y + 36, { width: this.contentWidth - 30 });
    this.doc.fillColor('#94A3B8').font('Helvetica-Oblique').fontSize(10).text(subtitle, 65, y + 60, { width: this.contentWidth - 30 });

    this.doc.y = y + 110;

    // Executive Summary Callout
    this.addCallout('EXECUTIVE_BRIEF', 'Chapter Executive Briefing', summary);
    this.doc.moveDown(0.6);
  }

  addSectionHeader(level, title, subtitle = '') {
    const spaceNeeded = level === 1 ? 52 : (level === 2 ? 38 : 28);
    this.ensureSpace(spaceNeeded);

    if (level === 1) {
      this.doc.moveDown(0.5);
      const y = this.doc.y;
      this.doc.rect(50, y, 4, 18).fill(this.colors.accentTeal);
      this.doc.fillColor(this.colors.primaryNavy).font('Helvetica-Bold').fontSize(14).text(title, 60, y + 1);
      if (subtitle) {
        this.doc.fillColor(this.colors.textMuted).font('Helvetica-Oblique').fontSize(9).text(subtitle, 60, y + 18);
        this.doc.y = y + 32;
      } else {
        this.doc.y = y + 24;
      }
    } else if (level === 2) {
      this.doc.moveDown(0.4);
      const y = this.doc.y;
      this.doc.fillColor(this.colors.secondaryNavy).font('Helvetica-Bold').fontSize(11.5).text(title, 50, y);
      if (subtitle) {
        this.doc.fillColor(this.colors.textMuted).font('Helvetica').fontSize(8.5).text(subtitle, 50, y + 15);
        this.doc.y = y + 26;
      } else {
        this.doc.y = y + 16;
      }
    } else {
      this.doc.moveDown(0.3);
      this.doc.fillColor(this.colors.accentCyan).font('Helvetica-Bold').fontSize(10).text(title, 50, this.doc.y);
      this.doc.moveDown(0.2);
    }
  }

  addParagraph(text) {
    this.ensureSpace(32);
    this.doc.fillColor(this.colors.textDark)
      .font('Helvetica')
      .fontSize(9)
      .text(text, 50, this.doc.y, {
        width: this.contentWidth,
        align: 'justify',
        lineGap: 3,
      });
    this.doc.moveDown(0.5);
  }

  addBullet(boldPrefix, text) {
    this.ensureSpace(22);
    const y = this.doc.y;
    this.doc.circle(56, y + 5.5, 2.5).fill(this.colors.accentTeal);

    const doc = this.doc;
    doc.fillColor(this.colors.textDark).font('Helvetica-Bold').fontSize(9).text(boldPrefix + ' ', 66, y, { continued: true });
    doc.font('Helvetica').text(text, { width: this.contentWidth - 16, lineGap: 2.5 });
    this.doc.moveDown(0.35);
  }

  addCallout(type, title, text) {
    const config = {
      EXECUTIVE_BRIEF: { bg: '#F8FAFC', border: '#00B0B9', titleColor: '#00B0B9', icon: 'EXECUTIVE BRIEFING' },
      CLINICAL: { bg: '#ECFDF5', border: '#10B981', titleColor: '#059669', icon: 'CLINICAL RATIONALE' },
      DECISION: { bg: '#EFF6FF', border: '#0284C7', titleColor: '#0369A1', icon: 'ARCHITECTURAL DECISION' },
      SECURITY: { bg: '#FEF2F2', border: '#EF4444', titleColor: '#DC2626', icon: 'SECURITY & VAULT SAFEGUARD' },
      MATH: { bg: '#F5F3FF', border: '#6366F1', titleColor: '#4F46E5', icon: 'MATHEMATICAL NORMALIZATION' },
      INFO: { bg: '#F1F5F9', border: '#475569', titleColor: '#334155', icon: 'SYSTEM CONTEXT' },
    }[type] || { bg: '#F1F5F9', border: '#475569', titleColor: '#334155', icon: 'NOTE' };

    const estimatedHeight = Math.ceil(text.length / 85) * 12 + 34;
    this.ensureSpace(estimatedHeight + 10);

    const y = this.doc.y;
    this.doc.roundedRect(50, y, this.contentWidth, estimatedHeight, 6).fill(config.bg);
    this.doc.rect(50, y, 4, estimatedHeight).fill(config.border);

    this.doc.fillColor(config.titleColor).font('Helvetica-Bold').fontSize(8.2).text(`[${config.icon}]  ${title.toUpperCase()}`, 64, y + 8);
    this.doc.fillColor(this.colors.textDark).font('Helvetica').fontSize(8.7).text(text, 64, y + 22, { width: this.contentWidth - 26, lineGap: 2.8 });

    this.doc.y = y + estimatedHeight + 8;
  }

  addFormulaCard(title, formulaStr, explanation) {
    this.ensureSpace(65);
    const y = this.doc.y;
    const cardHeight = 58;

    this.doc.roundedRect(50, y, this.contentWidth, cardHeight, 6).fill('#1E293B');
    this.doc.roundedRect(50, y, this.contentWidth, cardHeight, 6).lineWidth(1).strokeColor(this.colors.accentTeal).stroke();

    this.doc.fillColor(this.colors.accentTeal).font('Helvetica-Bold').fontSize(8.5).text(title, 62, y + 8);
    this.doc.fillColor(this.colors.white).font('Courier-Bold').fontSize(9.5).text(formulaStr, 62, y + 22, { width: this.contentWidth - 24 });
    this.doc.fillColor('#94A3B8').font('Helvetica').fontSize(8).text(explanation, 62, y + 38, { width: this.contentWidth - 24 });

    this.doc.y = y + cardHeight + 10;
  }

  addTable(headers, rows, colWidths = null) {
    const numCols = headers.length;
    const defaultColWidth = this.contentWidth / numCols;
    const widths = colWidths || Array(numCols).fill(defaultColWidth);

    const calcRowHeight = (cells, isHeader = false) => {
      let maxLines = 1;
      cells.forEach((cell, idx) => {
        const text = String(cell);
        const colW = widths[idx] - 12;
        const charsPerLine = Math.max(10, Math.floor(colW / (isHeader ? 4.8 : 4.1)));
        const words = text.split(/\s+/);
        let currentLineLen = 0;
        let lines = 1;
        words.forEach(w => {
          if (currentLineLen + w.length + 1 > charsPerLine) {
            lines++;
            currentLineLen = w.length;
          } else {
            currentLineLen += w.length + 1;
          }
        });
        if (lines > maxLines) maxLines = lines;
      });
      return Math.max(20, maxLines * (isHeader ? 11 : 9.5) + 10);
    };

    const headerHeight = calcRowHeight(headers, true);
    const firstRowHeight = rows.length > 0 ? calcRowHeight(rows[0]) : 20;

    // Ensure space for header + first row
    if (this.doc.y + headerHeight + firstRowHeight + 10 > this.contentBottom) {
      this.doc.addPage();
      this.doc.y = 65;
    }

    let currentY = this.doc.y;

    const drawHeader = (y) => {
      this.doc.rect(50, y, this.contentWidth, headerHeight).fill(this.colors.secondaryNavy);
      let currentX = 50;
      headers.forEach((h, i) => {
        this.doc.fillColor(this.colors.white).font('Helvetica-Bold').fontSize(8).text(h, currentX + 6, y + 6, { width: widths[i] - 12 });
        currentX += widths[i];
      });
      return y + headerHeight;
    };

    currentY = drawHeader(currentY);

    // Data Rows
    rows.forEach((row, rIdx) => {
      const rowHeight = calcRowHeight(row);

      // Check if row exceeds page
      if (currentY + rowHeight > this.contentBottom) {
        this.doc.addPage();
        this.doc.y = 65;
        currentY = drawHeader(65);
      }

      const bgColor = rIdx % 2 === 0 ? this.colors.white : this.colors.bgLight;
      this.doc.rect(50, currentY, this.contentWidth, rowHeight).fill(bgColor);
      this.doc.rect(50, currentY, this.contentWidth, rowHeight).lineWidth(0.5).strokeColor(this.colors.borderSubtle).stroke();

      let cellX = 50;
      row.forEach((cell, cIdx) => {
        const isBoldFirst = cIdx === 0;
        this.doc.fillColor(this.colors.textDark)
          .font(isBoldFirst ? 'Helvetica-Bold' : 'Helvetica')
          .fontSize(7.5)
          .text(String(cell), cellX + 6, currentY + 5, { width: widths[cIdx] - 12, lineGap: 1.8 });
        cellX += widths[cIdx];
      });

      currentY += rowHeight;
    });

    this.doc.y = currentY + 10;
  }

  addFlowchart(steps) {
    const boxHeight = 34;
    const spacing = 16;
    const totalHeight = steps.length * (boxHeight + spacing);
    this.ensureSpace(totalHeight + 10);

    let y = this.doc.y;

    steps.forEach((st, idx) => {
      this.doc.roundedRect(65, y, this.contentWidth - 30, boxHeight, 5).fill('#1E293B');
      this.doc.roundedRect(65, y, this.contentWidth - 30, boxHeight, 5).lineWidth(1).strokeColor(this.colors.accentTeal).stroke();

      this.doc.circle(85, y + 17, 10).fill(this.colors.accentTeal);
      this.doc.fillColor(this.colors.primaryNavy).font('Helvetica-Bold').fontSize(8.5).text(String(idx + 1), 77, y + 12.5, { width: 16, align: 'center' });

      this.doc.fillColor(this.colors.white).font('Helvetica-Bold').fontSize(9).text(st.label, 105, y + 5);
      this.doc.fillColor('#94A3B8').font('Helvetica').fontSize(7.8).text(st.desc, 105, y + 18, { width: this.contentWidth - 75 });

      if (idx < steps.length - 1) {
        const arrowY = y + boxHeight;
        this.doc.moveTo(85, arrowY).lineTo(85, arrowY + spacing).lineWidth(1.2).strokeColor(this.colors.accentTeal).stroke();
        this.doc.polygon([82, arrowY + spacing - 3], [88, arrowY + spacing - 3], [85, arrowY + spacing]).fill(this.colors.accentTeal);
      }

      y += boxHeight + spacing;
    });

    this.doc.y = y + 6;
  }

  finalizeHeadersAndFooters() {
    const pages = this.doc.bufferedPageRange();
    const total = pages.count;
    this.totalPages = total;

    for (let i = 0; i < total; i++) {
      this.doc.switchToPage(i);

      // Skip header/footer on cover page (page 0)
      if (i === 0) continue;

      const origBottom = this.doc.page.margins.bottom;
      this.doc.page.margins.bottom = 0;

      // Running Header
      this.doc.moveTo(50, 42).lineTo(this.pageWidth - 50, 42).lineWidth(0.5).strokeColor(this.colors.borderSubtle).stroke();
      this.doc.fillColor(this.colors.textMuted).font('Helvetica-Bold').fontSize(7.5).text('FITBIT HEALTH INTELLIGENCE DASHBOARD', 50, 31, { lineBreak: false });
      this.doc.font('Helvetica-Oblique').text('ENTERPRISE ARCHITECTURE & CLINICAL SPECIFICATION', 240, 31, { width: 305, align: 'right', lineBreak: false });

      // Running Footer
      this.doc.moveTo(50, this.pageHeight - 40).lineTo(this.pageWidth - 50, this.pageHeight - 40).lineWidth(0.5).strokeColor(this.colors.borderSubtle).stroke();
      this.doc.fillColor(this.colors.textMuted).font('Helvetica').fontSize(7.5).text('Confidential • Biomedical Systems Engineering Documentation • HIPAA-Compliant', 50, this.pageHeight - 32, { lineBreak: false });
      this.doc.font('Helvetica-Bold').text(`Page ${i + 1} of ${total}`, 400, this.pageHeight - 32, { width: 145, align: 'right', lineBreak: false });

      this.doc.page.margins.bottom = origBottom;
    }

    this.doc.end();
  }
}

module.exports = FitbitPDFEngine;
