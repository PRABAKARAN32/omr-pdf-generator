import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../barcode/models/barcode_configuration.dart';
import '../../excel_import/models/excel_data.dart';
import '../../layout_designer/models/layout_configuration.dart';
import 'pdf_generation_service.dart';

final pdfBatchServiceProvider = Provider<PdfBatchService>(
  (ref) => PdfBatchService(),
);

class PdfCancelledException implements Exception {
  const PdfCancelledException();

  @override
  String toString() => 'PDF generation was cancelled.';
}

/// Generates PDFs in small chunks inside background isolates so that
/// memory stays flat and the UI never freezes, even for 10 lakh records.
class PdfBatchService {
  /// Candidates (= pages) per PDF file.
  static const int chunkSize = 5000;

  /// Number of candidates shown in the preview screen.
  static const int previewCount = 5;

  int get _parallelJobs => max(1, min(4, Platform.numberOfProcessors ~/ 2));

  int fileCountFor(int totalRecords) => (totalRecords / chunkSize).ceil();

  String _fileName(int from, int to) {
    final first = (from + 1).toString().padLeft(7, '0');
    final last = to.toString().padLeft(7, '0');
    return 'OMR_$first-$last.pdf';
  }

  /// Name of the first PDF file of a job (used by the dashboard preview).
  String firstFileName(int totalRecords) {
    return _fileName(0, min(chunkSize, totalRecords));
  }

  void _validate(ExcelImportData? data, BarcodeConfiguration barcode) {
    if (data == null || data.rows.isEmpty) {
      throw Exception('Please import candidate data first.');
    }

    if (data.includedColumns.isEmpty) {
      throw Exception('Please select at least one Excel column.');
    }

    if (barcode.startingNumber.trim().isEmpty) {
      throw Exception('Please configure the starting barcode number.');
    }
  }

  List<Map<String, String>> _candidates(ExcelImportData data, int from, int to) {
    final columns = data.includedColumns.toList()..sort();

    return [
      for (var i = from; i < to; i++)
        {
          for (final c in columns)
            if (c >= 0 && c < data.headers.length)
              data.headers[c]: c < data.rows[i].length ? data.rows[i][c] : '',
        },
    ];
  }

  List<String> _barcodeValues(BarcodeConfiguration barcode, int from, int to) {
    final start = BigInt.tryParse(barcode.startingNumber);

    if (start == null || start < BigInt.zero) {
      throw Exception('Invalid starting barcode number.');
    }

    final width = barcode.startingNumber.length;
    final values = <String>[];

    for (var i = from; i < to; i++) {
      final value = (start + BigInt.from(i)).toString();

      if (barcode.format == BarcodeFormat.code32 && value.length > 8) {
        throw Exception('Code 32 barcode sequence exceeds 8 digits.');
      }

      if (value.length > 18) {
        throw Exception('Barcode sequence exceeds 18 digits.');
      }

      values.add(value.padLeft(width, '0'));
    }

    return values;
  }

  /// Small PDF with the first few candidates, for the preview screen.
  Future<Uint8List> generatePreview({
    required ExcelImportData? data,
    required BarcodeConfiguration barcode,
    required LayoutConfiguration layout,
  }) async {
    _validate(data, barcode);

    final count = min(previewCount, data!.recordCount);

    return _runPreviewInIsolate(
      _candidates(data, 0, count),
      _barcodeValues(barcode, 0, count),
      barcode,
      layout,
    );
  }

  /// Writes the complete job as many small PDF files into [outDir].
  Future<void> generateToFolder({
    required Directory outDir,
    required ExcelImportData? data,
    required BarcodeConfiguration barcode,
    required LayoutConfiguration layout,
    required void Function(int done, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    _validate(data, barcode);

    final excel = data!;
    await outDir.create(recursive: true);

    final total = excel.recordCount;
    final starts = <int>[for (var from = 0; from < total; from += chunkSize) from];

    var nextChunk = 0;
    var doneRecords = 0;
    var failed = false;

    Future<void> worker() async {
      while (!failed && !isCancelled()) {
        final chunkIndex = nextChunk++;
        if (chunkIndex >= starts.length) return;

        final from = starts[chunkIndex];
        final to = min(from + chunkSize, total);
        final path =
            '${outDir.path}${Platform.pathSeparator}${_fileName(from, to)}';

        try {
          await _writeChunkInIsolate(
            path,
            _candidates(excel, from, to),
            _barcodeValues(barcode, from, to),
            barcode,
            layout,
          );
        } catch (_) {
          failed = true;
          rethrow;
        }

        doneRecords += to - from;
        onProgress(doneRecords, total);
      }
    }

    await Future.wait(List.generate(_parallelJobs, (_) => worker()));

    if (isCancelled()) {
      throw const PdfCancelledException();
    }
  }
}

// ---------------------------------------------------------------------------
// Top-level helpers. They are kept outside the class so the closures sent to
// the isolate capture only the small values they need (not the whole app data).
// ---------------------------------------------------------------------------

Future<Uint8List> _runPreviewInIsolate(
  List<Map<String, String>> candidates,
  List<String> codes,
  BarcodeConfiguration barcode,
  LayoutConfiguration layout,
) {
  return Isolate.run(
    () => PdfGenerationService().generate(
      candidates: candidates,
      barcodeValues: codes,
      barcodeConfiguration: barcode,
      layout: layout,
    ),
  );
}

Future<void> _writeChunkInIsolate(
  String path,
  List<Map<String, String>> candidates,
  List<String> codes,
  BarcodeConfiguration barcode,
  LayoutConfiguration layout,
) {
  return Isolate.run(() async {
    final bytes = await PdfGenerationService().generate(
      candidates: candidates,
      barcodeValues: codes,
      barcodeConfiguration: barcode,
      layout: layout,
    );

    await File(path).writeAsBytes(bytes, flush: true);
  });
}