import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/excel_data.dart';
import '../services/excel_service.dart';

final excelServiceProvider = Provider<ExcelService>((ref) {
  return ExcelService();
});

class ExcelImportState {
  final String? fileName;
  final Uint8List? fileBytes;
  final List<String> worksheetNames;
  final ExcelImportData? importedData;
  final String? error;

  const ExcelImportState({
    this.fileName,
    this.fileBytes,
    this.worksheetNames = const [],
    this.importedData,
    this.error,
  });

  ExcelImportState copyWith({
    String? fileName,
    Uint8List? fileBytes,
    List<String>? worksheetNames,
    ExcelImportData? importedData,
    String? error,
    bool clearError = false,
  }) {
    return ExcelImportState(
      fileName: fileName ?? this.fileName,
      fileBytes: fileBytes ?? this.fileBytes,
      worksheetNames: worksheetNames ?? this.worksheetNames,
      importedData: importedData ?? this.importedData,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final excelProvider = NotifierProvider<ExcelImportNotifier, ExcelImportState>(
  ExcelImportNotifier.new,
);

class ExcelImportNotifier extends Notifier<ExcelImportState> {
  @override
  ExcelImportState build() {
    return const ExcelImportState();
  }

  /// Imports an .xlsx or .csv file in a background isolate.
  Future<void> selectWorkbook({
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      debugPrint('IMPORT: Starting $fileName (${bytes.length} bytes)');

      final result = await importFileInBackground(
        bytes: bytes,
        fileName: fileName,
      );

      debugPrint('IMPORT: Records = ${result.data.recordCount}');
      debugPrint('IMPORT: Headers = ${result.data.headers.length}');
      debugPrint('IMPORT: Warnings = ${result.data.totalWarnings}');

      state = ExcelImportState(
        fileName: fileName,
        fileBytes: bytes,
        worksheetNames: result.sheetNames,
        importedData: result.data,
      );
    } catch (error, stackTrace) {
      debugPrint('IMPORT ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      state = ExcelImportState(
        fileName: fileName,
        fileBytes: bytes,
        error: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void toggleColumn(int columnIndex) {
    final data = state.importedData;

    if (data == null || columnIndex < 0 || columnIndex >= data.headers.length) {
      return;
    }

    final included = Set<int>.from(data.includedColumns);

    if (included.contains(columnIndex)) {
      included.remove(columnIndex);
    } else {
      included.add(columnIndex);
    }

    state = state.copyWith(
      importedData: data.copyWith(includedColumns: included),
    );
  }

  void selectAllColumns() {
    final data = state.importedData;
    if (data == null) return;

    state = state.copyWith(
      importedData: data.copyWith(
        includedColumns: Set<int>.from(
          List.generate(data.headers.length, (index) => index),
        ),
      ),
    );
  }

  void clearSelection() {
    final data = state.importedData;
    if (data == null) return;

    state = state.copyWith(
      importedData: data.copyWith(includedColumns: <int>{}),
    );
  }

  void reset() {
    state = const ExcelImportState();
  }
}