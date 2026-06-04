import React from 'react';
import {
  Document,
  Page,
  Text,
  View,
  StyleSheet,
  Font,
  pdf,
} from '@react-pdf/renderer';
import { DistrictSummary, FieldHealthData, UpazilaBreakdown } from './api';

// Register Noto Sans Bengali font to support Bengali rendering in PDF canvas
Font.register({
  family: 'NotoSansBengali',
  src: '/fonts/NotoSansBengali-Regular.ttf', // Local self-hosted TTF
  fontWeight: 'normal',
});

Font.register({
  family: 'NotoSansBengaliBold',
  src: '/fonts/NotoSansBengali-Bold.ttf', // Local self-hosted TTF
  fontWeight: 'bold',
});

// Premium styling for the administrative PDF layout
const styles = StyleSheet.create({
  page: {
    fontFamily: 'NotoSansBengali',
    padding: 40,
    fontSize: 10,
    color: '#1a202c',
    backgroundColor: '#ffffff',
  },
  header: {
    flexDirection: 'column',
    alignItems: 'center',
    marginBottom: 20,
    borderBottomWidth: 2,
    borderBottomColor: '#00450d',
    paddingBottom: 15,
  },
  govTitle: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#00450d',
    marginBottom: 4,
    textTransform: 'uppercase',
  },
  deptTitle: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#1b5e20',
    marginBottom: 6,
  },
  subtitle: {
    fontSize: 9,
    color: '#718096',
  },
  reportMeta: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 20,
    paddingBottom: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
  },
  metaText: {
    fontSize: 8,
    color: '#4a5568',
  },
  sectionTitle: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#00450d',
    marginBottom: 10,
    marginTop: 15,
    borderLeftWidth: 3,
    borderLeftColor: '#00450d',
    paddingLeft: 8,
  },
  
  // KPI Grid Cards
  grid: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 20,
  },
  card: {
    width: '23%',
    padding: 10,
    borderRadius: 6,
    backgroundColor: '#f7fafc',
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  cardLabel: {
    fontSize: 8,
    color: '#718096',
    marginBottom: 4,
  },
  cardValue: {
    fontSize: 13,
    fontWeight: 'bold',
    color: '#00450d',
  },
  
  // Table Styling
  table: {
    width: '100%',
    borderWidth: 1,
    borderColor: '#e2e8f0',
    borderRadius: 4,
    overflow: 'hidden',
    marginBottom: 20,
  },
  tableRow: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
    minHeight: 24,
    alignItems: 'center',
  },
  tableHeader: {
    backgroundColor: '#00450d',
    borderBottomColor: '#00450d',
    color: '#ffffff',
  },
  tableCell: {
    flex: 1,
    padding: 6,
    fontSize: 8,
    textAlign: 'center',
  },
  tableCellLeft: {
    flex: 1,
    padding: 6,
    fontSize: 8,
    textAlign: 'left',
  },
  
  // Stressed alert colors
  redText: {
    color: '#ba1a1a',
    fontWeight: 'bold',
  },
  yellowText: {
    color: '#b7791f',
    fontWeight: 'bold',
  },
  greenText: {
    color: '#1b5e20',
  },
  
  // Red Alert Section
  alertCard: {
    padding: 8,
    marginBottom: 6,
    borderRadius: 4,
    backgroundColor: '#fff5f5',
    borderWidth: 1,
    borderColor: '#fed7d7',
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  alertLeft: {
    flexDirection: 'column',
  },
  alertRight: {
    flexDirection: 'column',
    alignItems: 'flex-end',
  },
  alertFarmer: {
    fontSize: 9,
    fontWeight: 'bold',
    color: '#2d3748',
  },
  alertPhone: {
    fontSize: 8,
    color: '#ba1a1a',
    marginTop: 2,
  },
  alertLocation: {
    fontSize: 8,
    color: '#718096',
    marginTop: 2,
  },
  footer: {
    position: 'absolute',
    bottom: 25,
    left: 40,
    right: 40,
    borderTopWidth: 1,
    borderTopColor: '#e2e8f0',
    paddingTop: 10,
    flexDirection: 'row',
    justifyContent: 'space-between',
    fontSize: 7,
    color: '#a0aec0',
  },
});

interface PDFReportProps {
  district: string;
  summary: DistrictSummary;
  upazilaBreakdown: UpazilaBreakdown[];
  redAlertFields: FieldHealthData[];
  generatedAt: string;
}

// React PDF Document Component
export const DistrictPDFReport: React.FC<PDFReportProps> = ({
  district,
  summary,
  upazilaBreakdown,
  redAlertFields,
  generatedAt,
}) => {
  return (
    <Document>
      <Page size="A4" style={styles.page}>
        
        {/* Government Letterhead */}
        <View style={styles.header}>
          <Text style={styles.govTitle}>গণপ্রজাতন্ত্রী বাংলাদেশ সরকার</Text>
          <Text style={styles.deptTitle}>কৃষি সম্প্রসারণ অধিদপ্তর (DAE)</Text>
          <Text style={styles.subtitle}>
            আকাশি স্যাটেলাইট শস্য পর্যবেক্ষণ ও সতর্কীকরণ ইউনিট — জেলা প্রতিবেদন
          </Text>
        </View>

        {/* Metadata Details */}
        <View style={styles.reportMeta}>
          <Text style={styles.metaText}>জেলা: {district}</Text>
          <Text style={styles.metaText}>অঞ্চল কোড: DAE-{district.toUpperCase()}</Text>
          <Text style={styles.metaText}>প্রস্তুতকরণের তারিখ: {generatedAt}</Text>
        </View>

        {/* 1. Crop Health Summary Section */}
        <Text style={styles.sectionTitle}>১. শস্যের সার্বিক অবস্থা সংক্ষেপ</Text>
        <View style={styles.grid}>
          <View style={styles.card}>
            <Text style={styles.cardLabel}>মোট কৃষক সংখ্যা</Text>
            <Text style={styles.cardValue}>{summary.farmer_count} জন</Text>
          </View>
          <View style={styles.card}>
            <Text style={styles.cardLabel}>মোট জমি মনিটরকৃত</Text>
            <Text style={styles.cardValue}>{summary.field_count} টি</Text>
          </View>
          <View style={styles.card}>
            <Text style={styles.cardLabel}>গড় NDVI সূচক</Text>
            <Text style={styles.cardValue}>{summary.avg_ndvi ?? 'N/A'}</Text>
          </View>
          <View style={styles.card}>
            <Text style={styles.cardLabel}>লাল সতর্কতা জমি</Text>
            <Text style={[styles.cardValue, styles.redText]}>{summary.red_fields} টি</Text>
          </View>
        </View>

        {/* 2. Upazila breakdown summary table */}
        <Text style={styles.sectionTitle}>২. উপজেলা ভিত্তিক শস্যের স্বাস্থ্য ও ফসল বিভাজন</Text>
        <View style={styles.table}>
          <View style={[styles.tableRow, styles.tableHeader]}>
            <Text style={[styles.tableCell, { flex: 1.5, fontWeight: 'bold' }]}>উপজেলা</Text>
            <Text style={[styles.tableCell, { fontWeight: 'bold' }]}>মোট জমি</Text>
            <Text style={[styles.tableCell, { fontWeight: 'bold' }]}>সুস্থ জমি</Text>
            <Text style={[styles.tableCell, { fontWeight: 'bold' }]}>সতর্কতা জমি</Text>
            <Text style={[styles.tableCell, { fontWeight: 'bold', color: '#ffd600' }]}>ঝুঁকিপূর্ণ জমি</Text>
            <Text style={[styles.tableCell, { fontWeight: 'bold' }]}>ক্ষতিগ্রস্ত (%)</Text>
          </View>
          {upazilaBreakdown.map((row, idx) => {
            const pct = row.field_count > 0 
              ? ((row.red_fields / row.field_count) * 100).toFixed(1) 
              : '0.0';
            return (
              <View style={styles.tableRow} key={idx}>
                <Text style={[styles.tableCellLeft, { flex: 1.5, fontWeight: 'bold' }]}>{row.upazila}</Text>
                <Text style={styles.tableCell}>{row.field_count}</Text>
                <Text style={[styles.tableCell, styles.greenText]}>{row.green_fields}</Text>
                <Text style={[styles.tableCell, styles.yellowText]}>{row.yellow_fields}</Text>
                <Text style={[styles.tableCell, styles.redText]}>{row.red_fields}</Text>
                <Text style={[styles.tableCell, styles.redText]}>{pct}%</Text>
              </View>
            );
          })}
        </View>

        {/* 3. Red Alert Farmer Registry Section */}
        <Text style={styles.sectionTitle}>৩. জরুরি লাল-সতর্কতা প্রাপ্ত খামারী রেজিস্ট্রি</Text>
        {redAlertFields.length === 0 ? (
          <Text style={{ fontSize: 9, color: '#718096', fontStyle: 'italic', padding: 10 }}>
            বর্তমানে কোনো লাল-সতর্কতা প্রাপ্ত ঝুঁকিপূর্ণ খামার নেই।
          </Text>
        ) : (
          redAlertFields.slice(0, 5).map((field, idx) => (
            <View style={styles.alertCard} key={idx}>
              <View style={styles.alertLeft}>
                <Text style={styles.alertFarmer}>
                  কৃষক: {field.farmer_name} ({field.field_name})
                </Text>
                <Text style={styles.alertPhone}>
                  যোগাযোগ: {field.farmer_phone}
                </Text>
                <Text style={styles.alertLocation}>
                  উপজেলা: {field.upazila} | ফসল: {field.crop_type}
                </Text>
              </View>
              <View style={styles.alertRight}>
                <Text style={[styles.cardValue, styles.redText]}>NDVI: {field.ndvi_mean ?? '0.21'}</Text>
                <Text style={{ fontSize: 8, color: '#e53e3e', marginTop: 4 }}>ঝুঁকিপূর্ণ / অতি দুর্বল</Text>
              </View>
            </View>
          ))
        )}

        {/* Print Footer */}
        <View style={styles.footer}>
          <Text>© ২০২৬ আকাশি (Akashi) শস্য নিরাপত্তা প্ল্যাটফর্ম | DAE</Text>
          <Text>অফিসিয়াল ব্যবহারের জন্য শুধুমাত্র | পৃষ্ঠা ১ / ১</Text>
        </View>

      </Page>
    </Document>
  );
};

// Compile and download helper
export async function downloadDistrictPDF(
  district: string,
  summary: DistrictSummary,
  upazilaBreakdown: UpazilaBreakdown[],
  redAlertFields: FieldHealthData[],
  generatedAt: string
): Promise<Blob> {
  const doc = (
    <DistrictPDFReport
      district={district}
      summary={summary}
      upazilaBreakdown={upazilaBreakdown}
      redAlertFields={redAlertFields}
      generatedAt={generatedAt}
    />
  );
  return await pdf(doc).toBlob();
}
