enum BarcodeFormat { code32, code39, code128 }

extension BarcodeFormatDetails on BarcodeFormat {
  String get label {
    switch (this) {
      case BarcodeFormat.code32:
        return 'Code 32';
      case BarcodeFormat.code39:
        return 'Code 39';
      case BarcodeFormat.code128:
        return 'Code 128';
    }
  }

  String get value => name;
}

class BarcodeConfiguration {
  final BarcodeFormat format;
  final String startingNumber;

  const BarcodeConfiguration({
    this.format = BarcodeFormat.code128,
    this.startingNumber = '',
  });

  BarcodeConfiguration copyWith({
    BarcodeFormat? format,
    String? startingNumber,
  }) {
    return BarcodeConfiguration(
      format: format ?? this.format,
      startingNumber: startingNumber ?? this.startingNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {'format': format.value, 'startingNumber': startingNumber};
  }
}
