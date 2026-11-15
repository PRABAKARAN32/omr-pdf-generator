import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../barcode/models/barcode_configuration.dart';
import '../../barcode/providers/barcode_configuration_provider.dart';
import '../../client/providers/job_session_provider.dart';
import '../../excel_import/providers/excel_provider.dart';
import '../../layout_designer/providers/layout_configuration_provider.dart';
import '../services/pdf_generation_service.dart';

final pdfGenerationServiceProvider = Provider<PdfGenerationService>(
  (ref) => PdfGenerationService(),
);

final pdfProvider = NotifierProvider<PdfNotifier, AsyncValue<Uint8List?>>(
  PdfNotifier.new,
);

class PdfNotifier extends Notifier<AsyncValue<Uint8List?>> {
  @override
  AsyncValue<Uint8List?> build() {
    return const AsyncData(null);
  }

  Future<Uint8List> generatePdf() async {
    state = const AsyncLoading();

    try {
      final excelData = ref.read(excelProvider).importedData;
      final barcodeConfig = ref.read(barcodeConfigurationProvider);
      final layoutConfig = ref.read(layoutConfigurationProvider);
      final clientDetails = ref.read(jobSessionProvider);

      if (clientDetails == null) {
        throw Exception('Client details are missing.');
      }

      if (excelData == null || excelData.rows.isEmpty) {
        throw Exception('Please import candidate data first.');
      }

      if (barcodeConfig.startingNumber.trim().isEmpty) {
        throw Exception('Please configure the starting barcode number.');
      }

      final includedIndexes = excelData.includedColumns.toList()..sort();

      if (includedIndexes.isEmpty) {
        throw Exception('Please select at least one Excel column.');
      }

      final candidates = <Map<String, String>>[];

      for (final row in excelData.rows) {
        final candidate = <String, String>{};

        for (final columnIndex in includedIndexes) {
          if (columnIndex < 0 || columnIndex >= excelData.headers.length) {
            continue;
          }

          final header = excelData.headers[columnIndex];
          final value = columnIndex < row.length ? row[columnIndex] : '';

          candidate[header] = value;
        }

        candidates.add(candidate);
      }

      final barcodeValues = _generateBarcodeValues(
        barcodeConfig,
        candidates.length,
      );

      final service = ref.read(pdfGenerationServiceProvider);

      final bytes = await service.generate(
        candidates: candidates,
        barcodeValues: barcodeValues,
        barcodeConfiguration: barcodeConfig,
        layout: layoutConfig,
      );

      state = AsyncData(bytes);
      return bytes;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  List<String> _generateBarcodeValues(
    BarcodeConfiguration configuration,
    int count,
  ) {
    final start = BigInt.tryParse(configuration.startingNumber);

    if (start == null || start < BigInt.zero) {
      throw Exception('Invalid starting barcode number.');
    }

    final originalWidth = configuration.startingNumber.length;
    final values = <String>[];

    for (var index = 0; index < count; index++) {
      final value = (start + BigInt.from(index)).toString();

      if (configuration.format == BarcodeFormat.code32 && value.length > 8) {
        throw Exception('Code 32 barcode sequence exceeds 8 digits.');
      }

      if (value.length > 18) {
        throw Exception('Barcode sequence exceeds 18 digits.');
      }

      values.add(value.padLeft(originalWidth, '0'));
    }

    if (values.toSet().length != values.length) {
      throw Exception('Duplicate barcode values were generated.');
    }

    return values;
  }

  void clear() {
    state = const AsyncData(null);
  }
}
