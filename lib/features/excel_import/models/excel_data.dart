class ExcelImportData {
  final String fileName;
  final String sheetName;
  final List<String> headers;
  final List<List<String>> rows;
  final List<String> warnings;
  final Set<int> includedColumns;

  const ExcelImportData({
    required this.fileName,
    required this.sheetName,
    required this.headers,
    required this.rows,
    required this.warnings,
    required this.includedColumns,
  });

  int get recordCount => rows.length;

  int get columnCount => headers.length;

  ExcelImportData copyWith({
    String? fileName,
    String? sheetName,
    List<String>? headers,
    List<List<String>>? rows,
    List<String>? warnings,
    Set<int>? includedColumns,
  }) {
    return ExcelImportData(
      fileName: fileName ?? this.fileName,
      sheetName: sheetName ?? this.sheetName,
      headers: headers ?? this.headers,
      rows: rows ?? this.rows,
      warnings: warnings ?? this.warnings,
      includedColumns: includedColumns ?? this.includedColumns,
    );
  }
}
