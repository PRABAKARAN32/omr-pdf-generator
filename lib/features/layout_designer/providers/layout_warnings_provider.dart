import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../excel_import/providers/excel_provider.dart';
import '../models/layout_configuration.dart';
import 'layout_configuration_provider.dart';

class LayoutWarning {
  final int pageNumber;
  final String message;

  const LayoutWarning({required this.pageNumber, required this.message});
}

final layoutWarningsProvider = Provider<List<LayoutWarning>>((ref) {
  final configuration = ref.watch(layoutConfigurationProvider);
  final excelData = ref.watch(excelProvider).importedData;

  if (excelData == null || excelData.rows.isEmpty) {
    return const [];
  }

  final warnings = <LayoutWarning>[];

  final detailsBox = configuration.detailsBox;
  final fontSize = configuration.detailsFontSize;
  final fontWeight = configuration.textStyle == LayoutTextStyle.bold
      ? FontWeight.bold
      : FontWeight.normal;

  const padding = 12.0;

  final availableWidth = detailsBox.width - padding;
  final availableHeight = detailsBox.height - padding;

  final selectedColumns = excelData.includedColumns.toList()..sort();

  if (selectedColumns.isEmpty) {
    return const [
      LayoutWarning(
        pageNumber: 1,
        message: 'No fields selected for the Details Box.',
      ),
    ];
  }

  for (var rowIndex = 0; rowIndex < excelData.rows.length; rowIndex++) {
    final pageNumber = rowIndex + 1;
    final candidate = excelData.rows[rowIndex];

    final barcodeBox = configuration.barcodeBoxForPage(pageNumber);

    // Check physical intersection between the two boxes.
    final boxesOverlap =
        detailsBox.x < barcodeBox.x + barcodeBox.width &&
        detailsBox.x + detailsBox.width > barcodeBox.x &&
        detailsBox.y < barcodeBox.y + barcodeBox.height &&
        detailsBox.y + detailsBox.height > barcodeBox.y;

    if (boxesOverlap) {
      warnings.add(
        LayoutWarning(
          pageNumber: pageNumber,
          message: 'Details Box and Barcode Box overlap.',
        ),
      );
    }

    var requiredHeight = 0.0;

    for (final columnIndex in selectedColumns) {
      if (columnIndex >= excelData.headers.length ||
          columnIndex >= candidate.length) {
        continue;
      }

      final label = excelData.headers[columnIndex];
      final value = candidate[columnIndex];

      // Measure the label and value separately so the value can
      // wrap without being measured as one unbreakable line.
      final labelPainter = TextPainter(
        text: TextSpan(
          text: '$label : ',
          style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final valueWidth = availableWidth - labelPainter.width;

      if (valueWidth <= 0) {
        warnings.add(
          LayoutWarning(
            pageNumber: pageNumber,
            message: 'Field "$label" leaves no space for its value.',
          ),
        );
        continue;
      }

      final valuePainter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: valueWidth);

      final lineHeight = valuePainter.height > labelPainter.height
          ? valuePainter.height
          : labelPainter.height;

      requiredHeight += lineHeight + configuration.fieldSpacing;
    }

    if (requiredHeight > availableHeight) {
      warnings.add(
        LayoutWarning(
          pageNumber: pageNumber,
          message:
              'Candidate details require '
              '${requiredHeight.toStringAsFixed(1)} pt, '
              'but only ${availableHeight.toStringAsFixed(1)} pt is available.',
        ),
      );
    }

    if (warnings.length >= 500) {
      warnings.add(
        const LayoutWarning(
          pageNumber: 1,
          message: 'Additional warnings were omitted.',
        ),
      );
      break;
    }
  }

  return warnings;
});
