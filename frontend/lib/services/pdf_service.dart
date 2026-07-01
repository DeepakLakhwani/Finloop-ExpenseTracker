import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PdfService {
  static Future<void> generateAndPrintStatement({
    required List<Map<String, dynamic>> transactions,
    required String accountName,
    required DateTime startDate,
    required DateTime endDate,
    required String currencySymbol,
    required bool includeSummary,
  }) async {
    final pdf = pw.Document();

    // Calculate totals
    double totalIncome = 0;
    double totalExpense = 0;
    for (var tx in transactions) {
      final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final type = tx['type']?.toString().toLowerCase() ?? '';
      if (type == 'income') {
        totalIncome += amt;
      } else if (type == 'expense') {
        totalExpense += amt;
      }
    }
    double netSavings = totalIncome - totalExpense;

    final dateFormat = DateFormat('dd MMM yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    // Styled Logo Badge (Vector)
                    pw.Container(
                      width: 40,
                      height: 40,
                      decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF10B981), // Emerald
                        shape: pw.BoxShape.circle,
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'FL',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FINLOOP',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF10B981),
                          ),
                        ),
                        pw.Text(
                          'Track, Budget & Save Smarter',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'FINANCIAL STATEMENT',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Generated: ${dateFormat.format(DateTime.now())}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey300, thickness: 1),
            pw.SizedBox(height: 10),

            // Period & Account Details Info Block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Account: $accountName',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Statement Period: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // Summary cards (rendered only if includeSummary is true)
            if (includeSummary) ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryBox('Total Income', '$currencySymbol${totalIncome.toStringAsFixed(2)}', const PdfColor.fromInt(0xFF10B981)),
                  _buildSummaryBox('Total Expense', '$currencySymbol${totalExpense.toStringAsFixed(2)}', const PdfColor.fromInt(0xFFEF4444)),
                  _buildSummaryBox('Net Savings', '$currencySymbol${netSavings.toStringAsFixed(2)}', netSavings >= 0 ? const PdfColor.fromInt(0xFF10B981) : const PdfColor.fromInt(0xFFEF4444)),
                ],
              ),
              pw.SizedBox(height: 25),
            ] else ...[
              pw.SizedBox(height: 10),
            ],

            // Transactions Table
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1.0),
              ),
              columnWidths: const {
                0: pw.FixedColumnWidth(80), // Date
                1: pw.FixedColumnWidth(100), // Category
                2: pw.FixedColumnWidth(90), // Account
                3: pw.FlexColumnWidth(), // Notes
                4: pw.FixedColumnWidth(90), // Amount
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF10B981), // Emerald
                  ),
                  children: [
                    _buildHeaderCell('Date'),
                    _buildHeaderCell('Category'),
                    _buildHeaderCell('Account'),
                    _buildHeaderCell('Notes'),
                    _buildHeaderCell('Amount', alignRight: true),
                  ],
                ),
                ...transactions.map((tx) {
                  // Parse date
                  final rawDate = tx['date'];
                  DateTime? parsedDate;
                  if (rawDate is DateTime) {
                    parsedDate = rawDate;
                  } else if (rawDate is Timestamp) {
                    parsedDate = rawDate.toDate();
                  } else if (rawDate is String) {
                    parsedDate = DateTime.tryParse(rawDate);
                  }

                  final dateStr = parsedDate != null ? dateFormat.format(parsedDate) : (rawDate?.toString() ?? '');
                  final amtVal = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                  final type = tx['type']?.toString() ?? '';
                  final isIncome = type.toLowerCase() == 'income';
                  final prefix = isIncome ? '+' : '-';
                  final amtColor = isIncome ? const PdfColor.fromInt(0xFF10B981) : const PdfColor.fromInt(0xFFEF4444);

                  return pw.TableRow(
                    children: [
                      _buildDataCell(dateStr),
                      _buildDataCell(tx['category_name']?.toString() ?? ''),
                      _buildDataCell(tx['account_name']?.toString() ?? ''),
                      _buildDataCell(tx['notes']?.toString() ?? tx['description']?.toString() ?? '-'),
                      _buildDataCell('$prefix$currencySymbol${amtVal.toStringAsFixed(2)}', color: amtColor, alignRight: true),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Divider(color: PdfColors.grey200, thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Track budgets, manage expenses & save smarter. Download the Finloop app on the Google Play Store.',
                    style: pw.TextStyle(
                      color: PdfColors.grey500,
                      fontSize: 7.5,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 7.5),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'finloop_statement_${DateFormat('yyyyMMdd').format(startDate)}.pdf',
    );
  }

  static pw.Widget _buildHeaderCell(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Container(
        alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildDataCell(String text, {PdfColor? color, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Container(
        alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            color: color ?? const PdfColor.fromInt(0xFF1F2937),
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryBox(String label, String value, PdfColor color) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF9FAFB),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.fromBorderSide(pw.BorderSide(color: PdfColor.fromInt(0xFFE5E7EB), width: 1)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromInt(0xFF4B5563),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
