class ExcelImportData {
  final String fileName;
  final String sheetName;
  final List<String> headers;
  final List<List<String>> rows;

  /// Only the first few warnings are stored (to save memory).
  final List<String> warnings;

  /// Real number of rows that had empty values.
  final int totalWarnings;

  final Set<int> includedColumns;

  const ExcelImportData({
    required this.fileName,
    required this.sheetName,
    required this.headers,
    required this.rows,
    required this.warnings,
    required this.includedColumns,
    this.totalWarnings = 0,
  });

  int get recordCount => rows.length;

  int get columnCount => headers.length;

  ExcelImportData copyWith({
    String? fileName,
    String? sheetName,
    List<String>? headers,
    List<List<String>>? rows,
    List<String>? warnings,
    int? totalWarnings,
    Set<int>? includedColumns,
  }) {
    return ExcelImportData(
      fileName: fileName ?? this.fileName,
      sheetName: sheetName ?? this.sheetName,
      headers: headers ?? this.headers,
      rows: rows ?? this.rows,
      warnings: warnings ?? this.warnings,
      totalWarnings: totalWarnings ?? this.totalWarnings,
      includedColumns: includedColumns ?? this.includedColumns,
    );
  }
}