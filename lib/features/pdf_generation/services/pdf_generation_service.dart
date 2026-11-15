import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../barcode/models/barcode_configuration.dart';
import '../../layout_designer/models/layout_configuration.dart';

class PdfGenerationService {
  static const double _contentPadding = 6.0;
  static const double _labelValueGap = 3.0;

  Future<Uint8List> generate({
    required List<Map<String, String>> candidates,
    required List<String> barcodeValues,
    required BarcodeConfiguration barcodeConfiguration,
    required LayoutConfiguration layout,
  }) async {
    if (candidates.isEmpty) {
      throw ArgumentError('There are no candidate records to generate.');
    }

    if (candidates.length != barcodeValues.length) {
      throw ArgumentError('Candidate count and barcode count do not match.');
    }

    if (barcodeConfiguration.format == BarcodeFormat.code32) {
      throw UnsupportedError(
        'Code 32 encoding is not implemented yet. '
        'Please select Code 39 or Code 128.',
      );
    }

    final document = pw.Document();

    final regularFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final selectedFont = layout.textStyle == LayoutTextStyle.bold
        ? boldFont
        : regularFont;

    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      final barcodeValue = barcodeValues[index];
      final pageNumber = index + 1;

      final detailsBox = layout.detailsBox;
      final barcodeBox = layout.barcodeBoxForPage(pageNumber);

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Stack(
              children: [
                pw.Positioned(
                  left: detailsBox.x,
                  top: detailsBox.y,
                  child: pw.SizedBox(
                    width: detailsBox.width,
                    height: detailsBox.height,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(_contentPadding),
                      child: _buildDetails(
                        candidate: candidate,
                        font: selectedFont,
                        fontSize: layout.detailsFontSize,
                        spacing: layout.fieldSpacing,
                      ),
                    ),
                  ),
                ),
                pw.Positioned(
                  left: barcodeBox.x,
                  top: barcodeBox.y,
                  child: pw.SizedBox(
                    width: barcodeBox.width,
                    height: barcodeBox.height,
                    child: _buildBarcode(
                      value: barcodeValue,
                      format: barcodeConfiguration.format,
                      font: selectedFont,
                      showNumber: layout.showBarcodeNumber,
                      boxWidth: barcodeBox.width,
                      boxHeight: barcodeBox.height,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return document.save();
  }

  pw.Widget _buildDetails({
    required Map<String, String> candidate,
    required pw.Font font,
    required double fontSize,
    required double spacing,
  }) {
    final fields = candidate.entries.toList();

    if (fields.isEmpty) {
      return pw.Text(
        'No candidate details',
        style: pw.TextStyle(font: font, fontSize: fontSize),
      );
    }

    final textStyle = pw.TextStyle(font: font, fontSize: fontSize);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        for (var index = 0; index < fields.length; index++) ...[
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(text: '${fields[index].key} :', style: textStyle),
                pw.TextSpan(
                  text: fields[index].value.isEmpty
                      ? ''
                      : ' ${fields[index].value}',
                  style: textStyle,
                ),
              ],
            ),
          ),
          if (index != fields.length - 1) pw.SizedBox(height: spacing),
        ],
      ],
    );
  }

  pw.Widget _buildBarcode({
    required String value,
    required BarcodeFormat format,
    required pw.Font font,
    required bool showNumber,
    required double boxWidth,
    required double boxHeight,
  }) {
    final barcode = _getBarcodeType(format);

    final numberHeight = showNumber ? 18.0 : 0.0;
    final barcodeHeight = (boxHeight - numberHeight).clamp(20.0, boxHeight);

    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.SizedBox(
          width: boxWidth,
          height: barcodeHeight,
          child: pw.BarcodeWidget(
            barcode: barcode,
            data: value,
            drawText: false,
            color: PdfColors.black,
            backgroundColor: PdfColors.white,
          ),
        ),
        if (showNumber)
          pw.SizedBox(
            height: numberHeight,
            child: pw.Center(
              child: pw.Text(
                value,
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }

  pw.Barcode _getBarcodeType(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.code32:
        throw UnsupportedError('Code 32 encoding is not implemented.');

      case BarcodeFormat.code39:
        return pw.Barcode.code39();

      case BarcodeFormat.code128:
        return pw.Barcode.code128();
    }
  }
}
