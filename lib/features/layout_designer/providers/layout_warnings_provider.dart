import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../excel_import/providers/excel_provider.dart';
import '../models/layout_configuration.dart';
import 'layout_configuration_provider.dart';

class LayoutWarning {
  /// Null means the warning applies to every page.
  final int? pageNumber;
  final String message;

  const LayoutWarning({this.pageNumber, required this.message});

  String get label =>
      pageNumber == null ? message : 'Page $pageNumber: $message';
}

/// The "worst-case candidate": for every column, the longest value found in
/// the whole file. It is calculated only when a new file is imported (it
/// watches only the rows list), so changing layout controls stays instant
/// even with 10 lakh records.
final worstCaseRowProvider = Provider<List<String>?>((ref) {
  final rows = ref.watch(excelProvider.select((s) => s.importedData?.rows));

  if (rows == null || rows.isEmpty) return null;

  final worst = List<String>.filled(rows.first.length, '');

  for (final row in rows) {
    for (var c = 0; c < worst.length && c < row.length; c++) {
      if (row[c].length > worst[c].length) {
        worst[c] = row[c];
      }
    }
  }

  return worst;
});

final layoutWarningsProvider = Provider<List<LayoutWarning>>((ref) {
  final configuration = ref.watch(layoutConfigurationProvider);
  final worstCase = ref.watch(worstCaseRowProvider);

  final headers = ref.watch(
    excelProvider.select((s) => s.importedData?.headers),
  );
  final includedColumns = ref.watch(
    excelProvider.select((s) => s.importedData?.includedColumns),
  );

  if (worstCase == null || headers == null || includedColumns == null) {
    return const [];
  }

  final selectedColumns = includedColumns.toList()..sort();

  if (selectedColumns.isEmpty) {
    return const [
      LayoutWarning(message: 'No fields selected for the Details Box.'),
    ];
  }

  final warnings = <LayoutWarning>[];
  final detailsBox = configuration.detailsBox;

  bool overlaps(LayoutBox a, LayoutBox b) {
    return a.x < b.x + b.width &&
        a.x + a.width > b.x &&
        a.y < b.y + b.height &&
        a.y + a.height > b.y;
  }

  // Box overlap check: the default barcode position + custom page positions.
  if (overlaps(detailsBox, configuration.barcodeBox)) {
    warnings.add(
      const LayoutWarning(message: 'Details Box and Barcode Box overlap.'),
    );
  }

  final overridePages = configuration.barcodePageOverrides.keys.toList()
    ..sort();

  for (final page in overridePages.take(50)) {
    final box = configuration.barcodePageOverrides[page]!;

    if (overlaps(detailsBox, box)) {
      warnings.add(
        LayoutWarning(
          pageNumber: page,
          message: 'Details Box and Barcode Box overlap.',
        ),
      );
    }
  }

  // Text fit check using the worst-case candidate.
  final fontSize = configuration.detailsFontSize;
  final fontWeight = configuration.textStyle == LayoutTextStyle.bold
      ? FontWeight.bold
      : FontWeight.normal;

  const padding = 12.0;

  final availableWidth = detailsBox.width - padding;
  final availableHeight = detailsBox.height - padding;

  var requiredHeight = 0.0;

  for (final columnIndex in selectedColumns) {
    if (columnIndex >= headers.length || columnIndex >= worstCase.length) {
      continue;
    }

    final label = headers[columnIndex];
    final value = worstCase[columnIndex];

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
        LayoutWarning(message: 'Field "$label" leaves no space for its value.'),
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
        message:
            'Longest candidate data needs '
            '${requiredHeight.toStringAsFixed(1)} pt, '
            'but only ${availableHeight.toStringAsFixed(1)} pt is available '
            'in the Details Box.',
      ),
    );
  }

  return warnings;
});