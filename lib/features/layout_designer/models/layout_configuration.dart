enum LayoutBoxType { details, barcode }

enum LayoutTextStyle { normal, bold }

class LayoutBox {
  final double x;
  final double y;
  final double width;
  final double height;

  const LayoutBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  LayoutBox copyWith({double? x, double? y, double? width, double? height}) {
    return LayoutBox(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory LayoutBox.fromJson(Map<String, dynamic> json) {
    return LayoutBox(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 100,
      height: (json['height'] as num?)?.toDouble() ?? 100,
    );
  }
}

class LayoutConfiguration {
  static const double pageWidth = 595.28;
  static const double pageHeight = 841.89;

  final LayoutBox detailsBox;
  final LayoutBox barcodeBox;
  final LayoutBoxType selectedBox;

  final double movementStep;
  final double detailsFontSize;
  final double fieldSpacing;

  final bool showBarcodeNumber;
  final LayoutTextStyle textStyle;

  final bool applyDetailsToAll;
  final bool applyBarcodeToAll;

  /// 1-based PDF page currently being edited.
  final int selectedPageNumber;

  /// Individual barcode positions, keyed by 1-based PDF page number.
  final Map<int, LayoutBox> barcodePageOverrides;

  const LayoutConfiguration({
    this.detailsBox = const LayoutBox(x: 35, y: 280, width: 335, height: 180),
    this.barcodeBox = const LayoutBox(x: 390, y: 325, width: 165, height: 48),
    this.selectedBox = LayoutBoxType.details,
    this.movementStep = 2,
    this.detailsFontSize = 10,
    this.fieldSpacing = 2,
    this.showBarcodeNumber = false,
    this.textStyle = LayoutTextStyle.bold,
    this.applyDetailsToAll = true,
    this.applyBarcodeToAll = true,
    this.selectedPageNumber = 1,
    this.barcodePageOverrides = const {},
  });

  LayoutBox barcodeBoxForPage(int pageNumber) {
    return barcodePageOverrides[pageNumber] ?? barcodeBox;
  }

  LayoutConfiguration copyWith({
    LayoutBox? detailsBox,
    LayoutBox? barcodeBox,
    LayoutBoxType? selectedBox,
    double? movementStep,
    double? detailsFontSize,
    double? fieldSpacing,
    bool? showBarcodeNumber,
    LayoutTextStyle? textStyle,
    bool? applyDetailsToAll,
    bool? applyBarcodeToAll,
    int? selectedPageNumber,
    Map<int, LayoutBox>? barcodePageOverrides,
  }) {
    return LayoutConfiguration(
      detailsBox: detailsBox ?? this.detailsBox,
      barcodeBox: barcodeBox ?? this.barcodeBox,
      selectedBox: selectedBox ?? this.selectedBox,
      movementStep: movementStep ?? this.movementStep,
      detailsFontSize: detailsFontSize ?? this.detailsFontSize,
      fieldSpacing: fieldSpacing ?? this.fieldSpacing,
      showBarcodeNumber: showBarcodeNumber ?? this.showBarcodeNumber,
      textStyle: textStyle ?? this.textStyle,
      applyDetailsToAll: applyDetailsToAll ?? this.applyDetailsToAll,
      applyBarcodeToAll: applyBarcodeToAll ?? this.applyBarcodeToAll,
      selectedPageNumber: selectedPageNumber ?? this.selectedPageNumber,
      barcodePageOverrides: barcodePageOverrides ?? this.barcodePageOverrides,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'detailsBox': detailsBox.toJson(),
      'barcodeBox': barcodeBox.toJson(),
      'selectedBox': selectedBox.name,
      'movementStep': movementStep,
      'detailsFontSize': detailsFontSize,
      'fieldSpacing': fieldSpacing,
      'showBarcodeNumber': showBarcodeNumber,
      'textStyle': textStyle.name,
      'applyDetailsToAll': applyDetailsToAll,
      'applyBarcodeToAll': applyBarcodeToAll,
      'selectedPageNumber': selectedPageNumber,
      'barcodePageOverrides': barcodePageOverrides.map(
        (page, box) => MapEntry(page.toString(), box.toJson()),
      ),
    };
  }

  factory LayoutConfiguration.fromJson(Map<String, dynamic> json) {
    const defaults = LayoutConfiguration();

    final overrides = <int, LayoutBox>{};
    final rawOverrides = json['barcodePageOverrides'];

    if (rawOverrides is Map) {
      for (final entry in rawOverrides.entries) {
        final page = int.tryParse(entry.key.toString());
        final value = entry.value;

        if (page != null && page > 0 && value is Map) {
          overrides[page] = LayoutBox.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      }
    }

    return LayoutConfiguration(
      detailsBox: json['detailsBox'] is Map
          ? LayoutBox.fromJson(
              Map<String, dynamic>.from(json['detailsBox'] as Map),
            )
          : defaults.detailsBox,
      barcodeBox: json['barcodeBox'] is Map
          ? LayoutBox.fromJson(
              Map<String, dynamic>.from(json['barcodeBox'] as Map),
            )
          : defaults.barcodeBox,
      selectedBox: LayoutBoxType.values.firstWhere(
        (value) => value.name == json['selectedBox'],
        orElse: () => defaults.selectedBox,
      ),
      movementStep:
          (json['movementStep'] as num?)?.toDouble() ?? defaults.movementStep,
      detailsFontSize:
          (json['detailsFontSize'] as num?)?.toDouble() ??
          defaults.detailsFontSize,
      fieldSpacing:
          (json['fieldSpacing'] as num?)?.toDouble() ?? defaults.fieldSpacing,
      showBarcodeNumber:
          json['showBarcodeNumber'] as bool? ?? defaults.showBarcodeNumber,
      textStyle: LayoutTextStyle.values.firstWhere(
        (value) => value.name == json['textStyle'],
        orElse: () => defaults.textStyle,
      ),
      applyDetailsToAll:
          json['applyDetailsToAll'] as bool? ?? defaults.applyDetailsToAll,
      applyBarcodeToAll:
          json['applyBarcodeToAll'] as bool? ?? defaults.applyBarcodeToAll,
      selectedPageNumber:
          (json['selectedPageNumber'] as num?)?.toInt() ??
          defaults.selectedPageNumber,
      barcodePageOverrides: overrides,
    );
  }
}
