import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';

class ExcelService {
  /// Generates a binary Excel buffer from a list of transaction document maps.
  static List<int>? exportTransactions({
    required List<Map<String, dynamic>> transactions,
  }) {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Transactions'];
    excel.delete('Sheet1');

    sheetObject.appendRow([
      TextCellValue('Date'),
      TextCellValue('Type'),
      TextCellValue('Category'),
      TextCellValue('Account'),
      TextCellValue('To Account'),
      TextCellValue('Amount'),
      TextCellValue('Notes'),
      TextCellValue('Description'),
      TextCellValue('Fees'),
    ]);

    for (var tx in transactions) {
      final dynamic dateVal = tx['date'];
      DateTime date;
      if (dateVal is DateTime) {
        date = dateVal;
      } else {
        date = DateTime.now();
      }

      sheetObject.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(date)),
        TextCellValue(tx['type']?.toString() ?? ''),
        TextCellValue(tx['category_name']?.toString() ?? ''),
        TextCellValue(tx['account_name']?.toString() ?? ''),
        TextCellValue(tx['to_account_name']?.toString() ?? ''),
        DoubleCellValue(double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0),
        TextCellValue(tx['notes']?.toString() ?? ''),
        TextCellValue(tx['description']?.toString() ?? ''),
        DoubleCellValue(double.tryParse(tx['fees']?.toString() ?? '0') ?? 0.0),
      ]);
    }

    return excel.encode();
  }

  /// Parses binary Excel buffer into clean list of raw transaction maps.
  static List<Map<String, dynamic>> parseExcel(List<int> bytes) {
    var excel = Excel.decodeBytes(bytes);
    List<Map<String, dynamic>> parsedRows = [];

    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table];
      if (sheet == null) continue;

      for (int r = 1; r < sheet.maxRows; r++) {
        var row = sheet.rows[r];
        if (row.isEmpty || row[0] == null) continue;

        final String dateStr = row[0]?.value?.toString() ?? '';
        final String type = row[1]?.value?.toString() ?? 'Expense';
        final String catName = row[2]?.value?.toString() ?? 'General';
        final String accName = row[3]?.value?.toString() ?? 'Cash';
        final String toAccName = row[4]?.value?.toString() ?? '';
        final double amount = double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0.0;
        final String notes = row[6]?.value?.toString() ?? '';
        final String description = row[7]?.value?.toString() ?? '';
        final double fees = double.tryParse(row[8]?.value?.toString() ?? '0') ?? 0.0;

        if (amount <= 0) continue;

        DateTime date;
        try {
          date = DateTime.parse(dateStr);
        } catch (_) {
          date = DateTime.now();
        }

        parsedRows.add({
          'date': date,
          'type': type,
          'category_name': catName,
          'account_name': accName,
          'to_account_name': toAccName,
          'amount': amount,
          'notes': notes,
          'description': description,
          'fees': fees,
        });
      }
    }

    return parsedRows;
  }
}
