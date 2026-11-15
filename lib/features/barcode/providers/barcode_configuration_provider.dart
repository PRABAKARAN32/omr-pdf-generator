import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/barcode_configuration.dart';

final barcodeConfigurationProvider =
    NotifierProvider<BarcodeConfigurationNotifier, BarcodeConfiguration>(
      BarcodeConfigurationNotifier.new,
    );

class BarcodeConfigurationNotifier extends Notifier<BarcodeConfiguration> {
  @override
  BarcodeConfiguration build() {
    return const BarcodeConfiguration();
  }

  void updateFormat(BarcodeFormat format) {
    state = state.copyWith(format: format);
  }

  void updateStartingNumber(String number) {
    state = state.copyWith(startingNumber: number);
  }

  void reset() {
    state = const BarcodeConfiguration();
  }
}
