import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/layout_configuration.dart';

final layoutConfigurationProvider =
    NotifierProvider<LayoutConfigurationNotifier, LayoutConfiguration>(
      LayoutConfigurationNotifier.new,
    );

class LayoutConfigurationNotifier extends Notifier<LayoutConfiguration> {
  @override
  LayoutConfiguration build() {
    return const LayoutConfiguration();
  }

  int get selectedPage => state.selectedPageNumber;

  void reset() {
    state = const LayoutConfiguration();
  }

  void selectPage(int pageNumber) {
    if (pageNumber < 1 || pageNumber == state.selectedPageNumber) {
      return;
    }

    state = state.copyWith(selectedPageNumber: pageNumber);
  }

  void selectBox(LayoutBoxType type) {
    state = state.copyWith(selectedBox: type);
  }

  LayoutBox getBoxForPage(LayoutBoxType type, int pageNumber) {
    if (type == LayoutBoxType.details) {
      return state.detailsBox;
    }

    return state.barcodeBoxForPage(pageNumber);
  }

  void moveBox(
    LayoutBoxType type, {
    double dx = 0,
    double dy = 0,
    int? pageNumber,
  }) {
    final page = pageNumber ?? state.selectedPageNumber;
    final currentBox = getBoxForPage(type, page);

    final maxX = (LayoutConfiguration.pageWidth - currentBox.width).clamp(
      0.0,
      LayoutConfiguration.pageWidth,
    );

    final maxY = (LayoutConfiguration.pageHeight - currentBox.height).clamp(
      0.0,
      LayoutConfiguration.pageHeight,
    );

    final updatedBox = currentBox.copyWith(
      x: (currentBox.x + dx).clamp(0.0, maxX).toDouble(),
      y: (currentBox.y + dy).clamp(0.0, maxY).toDouble(),
    );

    if (type == LayoutBoxType.details) {
      state = state.copyWith(detailsBox: updatedBox);
      return;
    }

    _saveBarcodeBox(updatedBox, page);
  }

  void resizeBox(
    LayoutBoxType type, {
    double widthDelta = 0,
    double heightDelta = 0,
    int? pageNumber,
  }) {
    final page = pageNumber ?? state.selectedPageNumber;
    final currentBox = getBoxForPage(type, page);

    const minimumDimension = 30.0;

    final width = (currentBox.width + widthDelta)
        .clamp(minimumDimension, LayoutConfiguration.pageWidth)
        .toDouble();

    final height = (currentBox.height + heightDelta)
        .clamp(minimumDimension, LayoutConfiguration.pageHeight)
        .toDouble();

    final updatedBox = currentBox.copyWith(
      width: width,
      height: height,
      x: currentBox.x.clamp(0.0, LayoutConfiguration.pageWidth - width),
      y: currentBox.y.clamp(0.0, LayoutConfiguration.pageHeight - height),
    );

    if (type == LayoutBoxType.details) {
      state = state.copyWith(detailsBox: updatedBox);
      return;
    }

    _saveBarcodeBox(updatedBox, page);
  }

  void updateSelectedBoxDimensions({double? width, double? height}) {
    final type = state.selectedBox;
    final page = state.selectedPageNumber;
    final current = getBoxForPage(type, page);

    resizeBox(
      type,
      widthDelta: width == null ? 0 : width - current.width,
      heightDelta: height == null ? 0 : height - current.height,
      pageNumber: page,
    );
  }

  void _saveBarcodeBox(LayoutBox box, int page) {
    if (state.applyBarcodeToAll) {
      state = state.copyWith(
        barcodeBox: box,
        barcodePageOverrides: <int, LayoutBox>{},
      );
      return;
    }

    final overrides = Map<int, LayoutBox>.from(state.barcodePageOverrides);

    overrides[page] = box;

    state = state.copyWith(barcodePageOverrides: overrides);
  }

  void resetBarcodePositionForPage(int pageNumber) {
    if (pageNumber < 1) return;

    final overrides = Map<int, LayoutBox>.from(state.barcodePageOverrides);

    overrides.remove(pageNumber);

    state = state.copyWith(barcodePageOverrides: overrides);
  }

  void applyBarcodePositionToAllPages(int pageNumber) {
    final selectedBox = state.barcodeBoxForPage(pageNumber);

    state = state.copyWith(
      barcodeBox: selectedBox,
      barcodePageOverrides: <int, LayoutBox>{},
      applyBarcodeToAll: true,
    );
  }

  void updateMovementStep(double value) {
    if (value <= 0) return;
    state = state.copyWith(movementStep: value);
  }

  void updateDetailsFontSize(double value) {
    if (value <= 0) return;
    state = state.copyWith(detailsFontSize: value);
  }

  /// Blank lines between the detail fields, in steps of 0.1.
  /// Always kept between 0.0 and 5.0.
  void updateLineSpacing(double value) {
    // Round to one decimal so values like 1.2000000000000002 never appear.
    final rounded = (value * 10).round() / 10;

    final lines = rounded
        .clamp(
          LayoutConfiguration.minLineSpacing,
          LayoutConfiguration.maxLineSpacing,
        )
        .toDouble();

    if ((lines - state.lineSpacing).abs() < 0.0001) return;

    state = state.copyWith(lineSpacing: lines);
  }

  void updateShowBarcodeNumber(bool value) {
    state = state.copyWith(showBarcodeNumber: value);
  }

  void updateTextStyle(LayoutTextStyle value) {
    state = state.copyWith(textStyle: value);
  }

  void updateApplyDetailsToAll(bool value) {
    state = state.copyWith(applyDetailsToAll: value);
  }

  void updateApplyBarcodeToAll(bool value) {
    if (value) {
      final selectedBox = state.barcodeBoxForPage(state.selectedPageNumber);

      state = state.copyWith(
        applyBarcodeToAll: true,
        barcodeBox: selectedBox,
        barcodePageOverrides: <int, LayoutBox>{},
      );
    } else {
      state = state.copyWith(applyBarcodeToAll: false);
    }
  }
}