const fs = require('fs');
const path = require('path');
const {
  Document,
  Packer,
  Paragraph,
  TextRun,
  Header,
  Footer,
  PageNumber,
  AlignmentType
} = require('C:/Users/PriyanshuKumar/.gemini/antigravity-ide/brain/6bd7368d-94f0-4349-a1f4-1ca924a7fe56/scratch/node_modules/docx');

const { DARK_NEUTRAL, BORDER_COLOR } = require('./helpers');
const { getFrontmatter } = require('./frontmatter');
const { getChapter1 } = require('./ch1_problem_space');
const { getChapter2 } = require('./ch2_architecture');
const { getChapter3 } = require('./ch3_tech_stack');
const { getChapter4 } = require('./ch4_algorithmic_engines');
const { getChapter5 } = require('./ch5_domain_schemas');
const { getChapter6 } = require('./ch6_feature_modules');
const { getChapter7 } = require('./ch7_sync_pipelines');
const { getChapter8 } = require('./ch8_security_privacy');
const { getChapter9 } = require('./ch9_cicd_release');
const { getChapter10 } = require('./ch10_engineering_matrix');
const { getChapter11 } = require('./ch11_testing_qa');
const { getChapter12 } = require('./ch12_roadmap_conclusion');

console.log('Assembling Master Architecture Manual (50+ Pages Specification)...');

const allChildren = [];

// Append all chapters
allChildren.push(...getFrontmatter());
allChildren.push(...getChapter1());
allChildren.push(...getChapter2());
allChildren.push(...getChapter3());
allChildren.push(...getChapter4());
allChildren.push(...getChapter5());
allChildren.push(...getChapter6());
allChildren.push(...getChapter7());
allChildren.push(...getChapter8());
allChildren.push(...getChapter9());
allChildren.push(...getChapter10());
allChildren.push(...getChapter11());
allChildren.push(...getChapter12());

console.log(`Total assembled document elements: ${allChildren.length}`);

const doc = new Document({
  styles: {
    default: {
      document: {
        run: { font: 'Calibri', color: DARK_NEUTRAL }
      }
    }
  },
  sections: [
    {
      properties: {
        page: {
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 }
        }
      },
      headers: {
        default: new Header({
          children: [
            new Paragraph({
              alignment: AlignmentType.RIGHT,
              children: [
                new TextRun({
                  text: 'FITBIT HEALTH INTELLIGENCE DASHBOARD — TECHNICAL & ARCHITECTURAL MANUAL',
                  font: 'Calibri',
                  size: 16,
                  color: '94A3B8'
                })
              ]
            })
          ]
        })
      },
      footers: {
        default: new Footer({
          children: [
            new Paragraph({
              alignment: AlignmentType.CENTER,
              children: [
                new TextRun({ text: 'Page ', font: 'Calibri', size: 18, color: '94A3B8' }),
                new TextRun({ children: [PageNumber.CURRENT], font: 'Calibri', size: 18, color: '94A3B8' }),
                new TextRun({ text: ' of ', font: 'Calibri', size: 18, color: '94A3B8' }),
                new TextRun({ children: [PageNumber.TOTAL_PAGES], font: 'Calibri', size: 18, color: '94A3B8' })
              ]
            })
          ]
        })
      },
      children: allChildren
    }
  ]
});

const outputDocxPath = path.resolve(__dirname, '../Fitbit_Health_Dashboard_Comprehensive_Architecture_Guide.docx');
const artifactDocxPath = 'C:/Users/PriyanshuKumar/.gemini/antigravity-ide/brain/6bd7368d-94f0-4349-a1f4-1ca924a7fe56/Fitbit_Health_Dashboard_Comprehensive_Architecture_Guide.docx';

Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(outputDocxPath, buffer);
  console.log(`Successfully generated master Word document at: ${outputDocxPath}`);
  console.log(`Binary size: ${buffer.length} bytes`);

  try {
    fs.writeFileSync(artifactDocxPath, buffer);
    console.log(`Successfully copied to artifacts: ${artifactDocxPath}`);
  } catch (err) {
    console.warn(`Artifact copy notice: ${err.message}`);
  }
}).catch((err) => {
  console.error('Fatal compilation error:', err);
  process.exit(1);
});
