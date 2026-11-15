import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

import '../models/excel_data.dart';

class ExcelService {
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

  List<String> getWorksheetNames(Uint8List bytes) {
    final workbook = decodeWorkbook(bytes);
    return workbook.tables.keys.toList();
  }

  ExcelImportData importWorksheet({
    required Uint8List bytes,
    required String fileName,
    required String sheetName,
    int headerRowIndex = 0,
  }) {
    final workbook = decodeWorkbook(bytes);
    final sheet = workbook.tables[sheetName];

    if (sheet == null) {
      throw Exception('Worksheet "$sheetName" was not found.');
    }

    final sourceRows = sheet.rows;

    if (sourceRows.isEmpty ||
        headerRowIndex < 0 ||
        headerRowIndex >= sourceRows.length) {
      throw Exception('The selected worksheet has no valid header row.');
    }

    // Read headers.
    final rawHeaders = sourceRows[headerRowIndex].map(_cellToText).toList();

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

    final importedRows = <List<String>>[];
    final warnings = <String>[];

    // Read candidate records after the header row.
    for (
      var rowIndex = headerRowIndex + 1;
      rowIndex < sourceRows.length;
      rowIndex++
    ) {
      final sourceRow = sourceRows[rowIndex];

      final row = List<String>.generate(headers.length, (columnIndex) {
        if (columnIndex >= sourceRow.length) {
          return '';
        }

        return _cellToText(sourceRow[columnIndex]);
      });

      // Ignore completely empty rows.
      if (row.every((value) => value.isEmpty)) {
        continue;
      }

      // Preserve partially filled rows and report missing values.
      final emptyColumns = <String>[];

      for (var i = 0; i < row.length; i++) {
        if (row[i].isEmpty) {
          emptyColumns.add(headers[i]);
        }
      }

      if (emptyColumns.isNotEmpty) {
        warnings.add(
          'Row ${rowIndex + 1}: Empty values in '
          '${emptyColumns.join(', ')}.',
        );
      }

      importedRows.add(row);
    }

    if (importedRows.isEmpty) {
      throw Exception('No candidate records found in this worksheet.');
    }

    return ExcelImportData(
      fileName: fileName,
      sheetName: sheetName,
      headers: headers,
      rows: importedRows,
      warnings: warnings,
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
