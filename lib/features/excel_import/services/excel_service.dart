import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

import '../models/excel_data.dart';

class ExcelImportResult {
  final List<String> sheetNames;
  final ExcelImportData data;

  const ExcelImportResult({required this.sheetNames, required this.data});
}

/// Runs the whole import in a background isolate so the UI never freezes.
Future<ExcelImportResult> importFileInBackground({
  required Uint8List bytes,
  required String fileName,
}) {
  return Isolate.run(
    () => ExcelService().importFile(bytes: bytes, fileName: fileName),
  );
}

class ExcelService {
  /// Maximum number of warning messages kept in memory.
  static const int _maxStoredWarnings = 200;

  ExcelImportResult importFile({
    required Uint8List bytes,
    required String fileName,
  }) {
    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.csv')) {
      return importCsv(bytes: bytes, fileName: fileName);
    }

    if (lowerName.endsWith('.xlsx')) {
      return importXlsx(bytes: bytes, fileName: fileName);
    }

    throw Exception('Unsupported file type. Please select an .xlsx or .csv file.');
  }

  // ---------------------------------------------------------------------
  // XLSX
  // ---------------------------------------------------------------------

  Excel decodeWorkbook(Uint8List bytes) {
    final inputArchive = ZipDecoder().decodeBytes(bytes);
    final outputArchive = Archive();

    for (final file in inputArchive.files) {
      if (file.isFile && file.name == 'xl/_rels/workbook.xml.rels') {
        final xml = utf8.decode(file.content);

        final correctedXml = xml.replaceAllMapped(
          RegExp(r'Target="/xl/([^"]+)"'),
          (match) => 'Target="${match[1]}"',
        );

        final correctedBytes = utf8.encode(correctedXml);

        outputArchive.addFile(
          ArchiveFile(file.name, correctedBytes.length, correctedBytes),
        );
      } else {
        outputArchive.addFile(file);
      }
    }

    final correctedBytes = ZipEncoder().encode(outputArchive);

    if (correctedBytes == null) {
      throw Exception('Failed to normalize Excel workbook.');
    }

    return Excel.decodeBytes(correctedBytes);
  }

  /// Decodes the workbook ONCE and imports its first worksheet.
  ExcelImportResult importXlsx({
    required Uint8List bytes,
    required String fileName,
  }) {
    final workbook = decodeWorkbook(bytes);
    final sheetNames = workbook.tables.keys.toList();

    if (sheetNames.isEmpty) {
      throw Exception('No worksheets found in this workbook.');
    }

    final sheetName = sheetNames.first;
    final sheet = workbook.tables[sheetName];

    if (sheet == null) {
      throw Exception('Worksheet "$sheetName" was not found.');
    }

    final source = sheet.rows.map(
      (row) => <String>[for (final cell in row) _cellToText(cell)],
    );

    final data = _buildImportData(
      source: source,
      fileName: fileName,
      sheetName: sheetName,
    );

    return ExcelImportResult(sheetNames: sheetNames, data: data);
  }

  // ---------------------------------------------------------------------
  // CSV (recommended for very large files)
  // ---------------------------------------------------------------------

  ExcelImportResult importCsv({
    required Uint8List bytes,
    required String fileName,
  }) {
    var text = utf8.decode(bytes, allowMalformed: true);

    // Remove the UTF-8 BOM that Excel adds.
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }

    final delimiter = _detectDelimiter(text);
    final rows = parseCsv(text, delimiter);

    final data = _buildImportData(
      source: rows,
      fileName: fileName,
      sheetName: 'CSV',
    );

    return ExcelImportResult(sheetNames: const ['CSV'], data: data);
  }

  String _detectDelimiter(String text) {
    final newline = text.indexOf('\n');
    final firstLine = newline == -1 ? text : text.substring(0, newline);

    final commas = ','.allMatches(firstLine).length;
    final semicolons = ';'.allMatches(firstLine).length;
    final tabs = '\t'.allMatches(firstLine).length;

    if (semicolons > commas && semicolons >= tabs) return ';';
    if (tabs > commas && tabs > semicolons) return '\t';
    return ',';
  }

  /// Small CSV parser that supports quoted values, escaped quotes ("")
  /// and line breaks inside quotes.
  static List<List<String>> parseCsv(String text, String delimiter) {
    const quote = 0x22;
    const cr = 0x0D;
    const lf = 0x0A;

    final delimiterCode = delimiter.codeUnitAt(0);
    final rows = <List<String>>[];

    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var index = 0;
    final length = text.length;

    void endField() {
      row.add(field.toString().trim());
      field.clear();
    }

    void endRow() {
      endField();
      rows.add(row);
      row = <String>[];
    }

    while (index < length) {
      final code = text.codeUnitAt(index);

      if (inQuotes) {
        if (code == quote) {
          if (index + 1 < length && text.codeUnitAt(index + 1) == quote) {
            field.writeCharCode(quote);
            index++;
          } else {
            inQuotes = false;
          }
        } else {
          field.writeCharCode(code);
        }
      } else if (code == quote) {
        inQuotes = true;
      } else if (code == delimiterCode) {
        endField();
      } else if (code == lf) {
        endRow();
      } else if (code == cr) {
        if (index + 1 < length && text.codeUnitAt(index + 1) == lf) {
          index++;
        }
        endRow();
      } else {
        field.writeCharCode(code);
      }

      index++;
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      endRow();
    }

    return rows;
  }

  // ---------------------------------------------------------------------
  // Shared logic
  // ---------------------------------------------------------------------

  /// Builds the import data in one pass. The first row is the header row.
  ExcelImportData _buildImportData({
    required Iterable<List<String>> source,
    required String fileName,
    required String sheetName,
  }) {
    final iterator = source.iterator;

    if (!iterator.moveNext()) {
      throw Exception('The selected worksheet has no valid header row.');
    }

    final rawHeaders = iterator.current;

    if (rawHeaders.every((header) => header.isEmpty)) {
      throw Exception('The selected header row is empty.');
    }

    // Generate unique column names.
    final headers = <String>[];
    final headerCounts = <String, int>{};

    for (var i = 0; i < rawHeaders.length; i++) {
      var header = rawHeaders[i];

      if (header.isEmpty) {
        header = 'Column ${i + 1}';
      }

      final count = (headerCounts[header] ?? 0) + 1;
      headerCounts[header] = count;

      if (count > 1) {
        header = '$header ($count)';
      }

      headers.add(header);
    }

    final columnCount = headers.length;
    final importedRows = <List<String>>[];
    final warnings = <String>[];
    var totalWarnings = 0;
    var rowNumber = 1;

    while (iterator.moveNext()) {
      rowNumber++;
      final sourceRow = iterator.current;

      // Reuse the row list when it already has the right length.
      final row = sourceRow.length == columnCount
          ? sourceRow
          : List<String>.generate(
              columnCount,
              (i) => i < sourceRow.length ? sourceRow[i] : '',
              growable: false,
            );

      // Ignore completely empty rows.
      if (row.every((value) => value.isEmpty)) {
        continue;
      }

      // Keep partially filled rows and report missing values.
      var hasEmpty = false;

      for (var i = 0; i < columnCount; i++) {
        if (row[i].isEmpty) {
          hasEmpty = true;
          break;
        }
      }

      if (hasEmpty) {
        totalWarnings++;

        if (warnings.length < _maxStoredWarnings) {
          final emptyColumns = <String>[
            for (var i = 0; i < columnCount; i++)
              if (row[i].isEmpty) headers[i],
          ];

          warnings.add(
            'Row $rowNumber: Empty values in ${emptyColumns.join(', ')}.',
          );
        }
      }

      importedRows.add(row);
    }

    if (importedRows.isEmpty) {
      throw Exception('No candidate records found in this worksheet.');
    }

    final hidden = totalWarnings - warnings.length;

    if (hidden > 0) {
      warnings.add('...and $hidden more rows with empty values.');
    }

    return ExcelImportData(
      fileName: fileName,
      sheetName: sheetName,
      headers: headers,
      rows: importedRows,
      warnings: warnings,
      totalWarnings: totalWarnings,
      includedColumns: Set<int>.from(
        List.generate(headers.length, (index) => index),
      ),
    );
  }

  String _cellToText(Data? cell) {
    if (cell == null || cell.value == null) {
      return '';
    }

    return cell.value.toString().trim();
  }
}