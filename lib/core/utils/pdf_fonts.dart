import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Raw Arial font bytes. Plain data, so it can be sent to a background
/// isolate (background isolates cannot read Flutter assets themselves).
class PdfFontBytes {
  final Uint8List regular;
  final Uint8List bold;

  const PdfFontBytes({required this.regular, required this.bold});
}

class PdfFonts {
  PdfFonts._();

  static const String regularAsset = 'assets/google_fonts/Arimo-Regular.ttf';
  static const String boldAsset = 'assets/google_fonts/Arimo-Bold.ttf';

  static PdfFontBytes? _cache;

  /// Loads Arial (regular + bold) once and keeps it in memory.
  static Future<PdfFontBytes> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    try {
      final regular = await rootBundle.load(regularAsset);
      final bold = await rootBundle.load(boldAsset);

      final fonts = PdfFontBytes(
        regular: regular.buffer.asUint8List(
          regular.offsetInBytes,
          regular.lengthInBytes,
        ),
        bold: bold.buffer.asUint8List(bold.offsetInBytes, bold.lengthInBytes),
      );

      _cache = fonts;
      return fonts;
    } catch (_) {
      throw Exception(
        'Font files were not found. Copy Arimo-Regular.ttf and Arimo-Bold.ttf '
        'into assets/google_fonts/ and restart the app.',
      );
    }
  }
}