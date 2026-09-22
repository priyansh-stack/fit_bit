const fs = require('fs');
const path = require('path');
const {
  Paragraph,
  TextRun,
  HeadingLevel,
  Table,
  TableRow,
  TableCell,
  WidthType,
  BorderStyle,
  AlignmentType,
  ShadingType,
  PageBreak,
  ImageRun
} = require('C:/Users/PriyanshuKumar/.gemini/antigravity-ide/brain/6bd7368d-94f0-4349-a1f4-1ca924a7fe56/scratch/node_modules/docx');

// Professional Enterprise Palette
const PRIMARY_COLOR = '1E3A8A';   // Deep Navy / Midnight Blue
const SECONDARY_COLOR = '0D9488'; // Deep Teal
const ACCENT_COLOR = '2563EB';    // Royal Blue
const DARK_NEUTRAL = '1E293B';    // Slate 800
const LIGHT_BG = 'F8FAFC';        // Slate 50
const MUTED_TEXT = '64748B';      // Slate 500
const BORDER_COLOR = 'CBD5E1';    // Slate 300
const TABLE_HEADER_BG = '1E293B'; // Dark Slate
const CALLOUT_BG = 'F0FDF4';      // Soft Mint / Light Emerald
const CODE_BG = '0F172A';         // Terminal Dark Slate

function createDocTitle(text) {
  return new Paragraph({
    text: text,
    heading: HeadingLevel.TITLE,
    alignment: AlignmentType.CENTER,
    spacing: { before: 600, after: 200 },
    run: { font: 'Calibri', size: 52, bold: true, color: PRIMARY_COLOR }
  });
}

function createSubtitle(text) {
  return new Paragraph({
    text: text,
    alignment: AlignmentType.CENTER,
    spacing: { before: 100, after: 360 },
    run: { font: 'Calibri', size: 24, italics: true, color: MUTED_TEXT }
  });
}

function createChapterHeading(chapterNumber, title) {
  return new Paragraph({
    pageBreakBefore: true,
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 400, after: 200 },
    children: [
      new TextRun({
        text: `CHAPTER ${chapterNumber}: `,
        font: 'Calibri',
        size: 32,
        bold: true,
        color: SECONDARY_COLOR
      }),
      new TextRun({
        text: title,
        font: 'Calibri',
        size: 32,
        bold: true,
        color: PRIMARY_COLOR
      })
    ]
  });
}

function createSectionHeading(title) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 320, after: 140 },
    children: [
      new TextRun({
        text: title,
        font: 'Calibri',
        size: 26,
        bold: true,
        color: PRIMARY_COLOR
      })
    ]
  });
}

function createSubSectionHeading(title) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3,
    spacing: { before: 240, after: 100 },
    children: [
      new TextRun({
        text: title,
        font: 'Calibri',
        size: 22,
        bold: true,
        color: SECONDARY_COLOR
      })
    ]
  });
}

function createBody(text, options = {}) {
  return new Paragraph({
    alignment: AlignmentType.JUSTIFIED,
    spacing: { before: 60, after: 120, line: 276 },
    children: [
      new TextRun({
        text: text,
        font: 'Calibri',
        size: 22,
        color: DARK_NEUTRAL,
        bold: options.bold || false,
        italics: options.italics || false
      })
    ]
  });
}

function createBullet(text, boldPrefix = '') {
  const children = [];
  if (boldPrefix) {
    children.push(new TextRun({
      text: boldPrefix,
      font: 'Calibri',
      size: 22,
      bold: true,
      color: DARK_NEUTRAL
    }));
  }
  children.push(new TextRun({
    text: text,
    font: 'Calibri',
    size: 22,
    color: DARK_NEUTRAL
  }));

  return new Paragraph({
    bullet: { level: 0 },
    spacing: { before: 40, after: 60, line: 260 },
    children: children
  });
}

function createSubBullet(text, boldPrefix = '') {
  const children = [];
  if (boldPrefix) {
    children.push(new TextRun({
      text: boldPrefix,
      font: 'Calibri',
      size: 21,
      bold: true,
      color: DARK_NEUTRAL
    }));
  }
  children.push(new TextRun({
    text: text,
    font: 'Calibri',
    size: 21,
    color: DARK_NEUTRAL
  }));

  return new Paragraph({
    bullet: { level: 1 },
    spacing: { before: 30, after: 50, line: 250 },
    children: children
  });
}

function createCallout(title, body, bg = 'EFF6FF', borderColor = PRIMARY_COLOR) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      new TableRow({
        children: [
          new TableCell({
            shading: { type: ShadingType.CLEAR, fill: bg },
            borders: {
              left: { style: BorderStyle.SINGLE, size: 24, color: borderColor },
              top: { style: BorderStyle.NONE },
              right: { style: BorderStyle.NONE },
              bottom: { style: BorderStyle.NONE }
            },
            margins: { top: 140, bottom: 140, left: 200, right: 140 },
            children: [
              new Paragraph({
                spacing: { before: 0, after: 40 },
                children: [
                  new TextRun({ text: title, bold: true, font: 'Calibri', size: 22, color: borderColor })
                ]
              }),
              new Paragraph({
                spacing: { before: 0, after: 0, line: 260 },
                children: [
                  new TextRun({ text: body, font: 'Calibri', size: 21, color: DARK_NEUTRAL })
                ]
              })
            ]
          })
        ]
      })
    ]
  });
}

function createFormulaBox(formulaName, formulaEquation, explanation) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      new TableRow({
        children: [
          new TableCell({
            shading: { type: ShadingType.CLEAR, fill: 'F8FAFC' },
            borders: {
              left: { style: BorderStyle.SINGLE, size: 18, color: SECONDARY_COLOR },
              top: { style: BorderStyle.SINGLE, size: 6, color: BORDER_COLOR },
              right: { style: BorderStyle.SINGLE, size: 6, color: BORDER_COLOR },
              bottom: { style: BorderStyle.SINGLE, size: 6, color: BORDER_COLOR }
            },
            margins: { top: 140, bottom: 140, left: 180, right: 140 },
            children: [
              new Paragraph({
                spacing: { before: 0, after: 60 },
                children: [
                  new TextRun({ text: `Mathematical Specification: ${formulaName}`, bold: true, font: 'Calibri', size: 22, color: SECONDARY_COLOR })
                ]
              }),
              new Paragraph({
                alignment: AlignmentType.CENTER,
                spacing: { before: 80, after: 100 },
                children: [
                  new TextRun({ text: formulaEquation, bold: true, font: 'Consolas', size: 24, color: PRIMARY_COLOR })
                ]
              }),
              new Paragraph({
                spacing: { before: 40, after: 0, line: 260 },
                children: [
                  new TextRun({ text: 'Parameter Definitions: ', bold: true, font: 'Calibri', size: 20, color: MUTED_TEXT }),
                  new TextRun({ text: explanation, font: 'Calibri', size: 20, color: DARK_NEUTRAL })
                ]
              })
            ]
          })
        ]
      })
    ]
  });
}

function createDiagramBlock(asciiDiagram) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      new TableRow({
        children: [
          new TableCell({
            shading: { type: ShadingType.CLEAR, fill: CODE_BG },
            borders: {
              left: { style: BorderStyle.SINGLE, size: 12, color: SECONDARY_COLOR },
              top: { style: BorderStyle.NONE },
              right: { style: BorderStyle.NONE },
              bottom: { style: BorderStyle.NONE }
            },
            margins: { top: 140, bottom: 140, left: 160, right: 140 },
            children: [
              new Paragraph({
                spacing: { before: 0, after: 0 },
                children: [
                  new TextRun({
                    text: asciiDiagram,
                    font: 'Consolas',
                    size: 17,
                    color: '38BDF8' // Light Sky Blue
                  })
                ]
              })
            ]
          })
        ]
      })
    ]
  });
}

function createCodeBlock(codeText, languageLabel = 'DART') {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      new TableRow({
        children: [
          new TableCell({
            shading: { type: ShadingType.CLEAR, fill: CODE_BG },
            borders: {
              left: { style: BorderStyle.SINGLE, size: 12, color: ACCENT_COLOR },
              top: { style: BorderStyle.NONE },
              right: { style: BorderStyle.NONE },
              bottom: { style: BorderStyle.NONE }
            },
            margins: { top: 120, bottom: 120, left: 160, right: 140 },
            children: [
              new Paragraph({
                spacing: { before: 0, after: 40 },
                children: [
                  new TextRun({ text: `[${languageLabel}]`, bold: true, font: 'Consolas', size: 16, color: '94A3B8' })
                ]
              }),
              new Paragraph({
                spacing: { before: 0, after: 0 },
                children: [
                  new TextRun({
                    text: codeText,
                    font: 'Consolas',
                    size: 17,
                    color: 'E2E8F0'
                  })
                ]
              })
            ]
          })
        ]
      })
    ]
  });
}

function createMatrixTable(headers, rowsData, colWidthsPct = []) {
  const tableRows = [];

  tableRows.push(
    new TableRow({
      tableHeader: true,
      children: headers.map((h, i) => new TableCell({
        width: colWidthsPct[i] ? { size: colWidthsPct[i], type: WidthType.PERCENTAGE } : { size: Math.floor(100 / headers.length), type: WidthType.PERCENTAGE },
        shading: { type: ShadingType.CLEAR, fill: TABLE_HEADER_BG },
        margins: { top: 120, bottom: 120, left: 120, right: 120 },
        children: [
          new Paragraph({
            alignment: AlignmentType.LEFT,
            children: [
              new TextRun({ text: h, bold: true, font: 'Calibri', size: 20, color: 'FFFFFF' })
            ]
          })
        ]
      }))
    })
  );

  rowsData.forEach((row, rowIndex) => {
    const isEven = rowIndex % 2 === 0;
    const bg = isEven ? 'FFFFFF' : LIGHT_BG;
    tableRows.push(
      new TableRow({
        children: row.map((cellText, cellIndex) => new TableCell({
          width: colWidthsPct[cellIndex] ? { size: colWidthsPct[cellIndex], type: WidthType.PERCENTAGE } : { size: Math.floor(100 / headers.length), type: WidthType.PERCENTAGE },
          shading: { type: ShadingType.CLEAR, fill: bg },
          borders: {
            top: { style: BorderStyle.SINGLE, size: 4, color: BORDER_COLOR },
            bottom: { style: BorderStyle.SINGLE, size: 4, color: BORDER_COLOR },
            left: { style: BorderStyle.SINGLE, size: 4, color: BORDER_COLOR },
            right: { style: BorderStyle.SINGLE, size: 4, color: BORDER_COLOR }
          },
          margins: { top: 100, bottom: 100, left: 120, right: 120 },
          children: [
            new Paragraph({
              children: [
                new TextRun({ text: cellText, font: 'Calibri', size: 19, color: DARK_NEUTRAL })
              ]
            })
          ]
        }))
      })
    );
  });

  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: tableRows
  });
}

function createFigure(imageRelativePath, figureNumber, captionText, width = 210, height = 466) {
  const fullPath = path.resolve(__dirname, imageRelativePath);
  if (!fs.existsSync(fullPath)) {
    console.warn('Image not found:', fullPath);
    return [];
  }
  const imgBuffer = fs.readFileSync(fullPath);
  return [
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 240, after: 80 },
      children: [
        new ImageRun({
          data: imgBuffer,
          transformation: { width: width, height: height }
        })
      ]
    }),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 40, after: 240 },
      children: [
        new TextRun({
          text: `Figure ${figureNumber}: `,
          bold: true,
          font: 'Calibri',
          size: 19,
          color: SECONDARY_COLOR
        }),
        new TextRun({
          text: captionText,
          font: 'Calibri',
          size: 19,
          italics: true,
          color: DARK_NEUTRAL
        })
      ]
    })
  ];
}

function createPageBreak() {
  return new Paragraph({
    children: [new PageBreak()]
  });
}

module.exports = {
  createDocTitle,
  createSubtitle,
  createChapterHeading,
  createSectionHeading,
  createSubSectionHeading,
  createBody,
  createBullet,
  createSubBullet,
  createCallout,
  createFormulaBox,
  createDiagramBlock,
  createCodeBlock,
  createMatrixTable,
  createFigure,
  createPageBreak,
  PRIMARY_COLOR,
  SECONDARY_COLOR,
  DARK_NEUTRAL,
  BORDER_COLOR,
  LIGHT_BG
};
