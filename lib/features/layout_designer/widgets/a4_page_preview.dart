import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/layout_configuration.dart';

typedef BoxMoveCallback = void Function(
  LayoutBoxType type,
  double dx,
  double dy,
);

typedef BoxResizeCallback = void Function(
  LayoutBoxType type,
  double widthDelta,
  double heightDelta,
);

class A4PagePreview extends StatelessWidget {
  final LayoutConfiguration configuration;
  final List<MapEntry<String, String>> candidateDetails;
  final String barcodeValue;

  final ValueChanged<LayoutBoxType> onSelectBox;
  final BoxMoveCallback onMoveBox;
  final BoxResizeCallback onResizeBox;

  final bool zoomFirstHalf;

  const A4PagePreview({
    super.key,
    required this.configuration,
    required this.candidateDetails,
    required this.barcodeValue,
    required this.onSelectBox,
    required this.onMoveBox,
    required this.onResizeBox,
    this.zoomFirstHalf = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // In zoom mode, fit the top half of the A4 page
        // into the available preview area.
        final visiblePageHeightPoints = zoomFirstHalf
            ? LayoutConfiguration.pageHeight / 2
            : LayoutConfiguration.pageHeight;

        final widthScale = constraints.maxWidth / LayoutConfiguration.pageWidth;

        final heightScale = constraints.maxHeight / visiblePageHeightPoints;

        final scale = widthScale < heightScale ? widthScale : heightScale;

        final pageWidth = LayoutConfiguration.pageWidth * scale;
        final fullPageHeight = LayoutConfiguration.pageHeight * scale;

        final visiblePageHeight = visiblePageHeightPoints * scale;

        return Center(
          child: Focus(
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: Builder(
              builder: (focusContext) {
                return ClipRect(
                  child: SizedBox(
                    width: pageWidth,
                    height: visiblePageHeight,
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minWidth: pageWidth,
                      maxWidth: pageWidth,
                      minHeight: fullPageHeight,
                      maxHeight: fullPageHeight,
                      child: Container(
                        width: pageWidth,
                        height: fullPageHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 8 * scale,
                              top: 8 * scale,
                              child: Text(
                                zoomFirstHalf
                                    ? 'A4 PREVIEW · TOP HALF'
                                    : 'A4 PREVIEW',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 9 * scale,
                                ),
                              ),
                            ),

                            _buildPositionedBox(
                              context: focusContext,
                              box: configuration.detailsBox,
                              type: LayoutBoxType.details,
                              scale: scale,
                              selected:
                                  configuration.selectedBox ==
                                  LayoutBoxType.details,
                              child: _buildDetailsContent(scale),
                            ),

                            _buildPositionedBox(
                              context: focusContext,
                              box: configuration.barcodeBoxForPage(
                                configuration.selectedPageNumber,
                              ),
                              type: LayoutBoxType.barcode,
                              scale: scale,
                              selected:
                                  configuration.selectedBox ==
                                  LayoutBoxType.barcode,
                              child: _buildBarcodeContent(scale),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isControlPressed = HardwareKeyboard.instance.isControlPressed;

    final selectedType = configuration.selectedBox;
    final step = configuration.movementStep;

    if (key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }

    if (isControlPressed) {
      switch (key) {
        case LogicalKeyboardKey.arrowUp:
          onResizeBox(selectedType, 0, -step);
          break;
        case LogicalKeyboardKey.arrowDown:
          onResizeBox(selectedType, 0, step);
          break;
        case LogicalKeyboardKey.arrowLeft:
          onResizeBox(selectedType, -step, 0);
          break;
        case LogicalKeyboardKey.arrowRight:
          onResizeBox(selectedType, step, 0);
          break;
      }
    } else {
      switch (key) {
        case LogicalKeyboardKey.arrowUp:
          onMoveBox(selectedType, 0, -step);
          break;
        case LogicalKeyboardKey.arrowDown:
          onMoveBox(selectedType, 0, step);
          break;
        case LogicalKeyboardKey.arrowLeft:
          onMoveBox(selectedType, -step, 0);
          break;
        case LogicalKeyboardKey.arrowRight:
          onMoveBox(selectedType, step, 0);
          break;
      }
    }

    return KeyEventResult.handled;
  }

  Widget _buildPositionedBox({
    required BuildContext context,
    required LayoutBox box,
    required LayoutBoxType type,
    required double scale,
    required bool selected,
    required Widget child,
  }) {
    return Positioned(
      left: box.x * scale,
      top: box.y * scale,
      width: box.width * scale,
      height: box.height * scale,
      child: GestureDetector(
        onTap: () {
          Focus.of(context).requestFocus();
          onSelectBox(type);
        },
        onPanStart: (_) {
          Focus.of(context).requestFocus();
          onSelectBox(type);
        },
        onPanUpdate: (details) {
          onMoveBox(type, details.delta.dx / scale, details.delta.dy / scale);
        },
        child: Container(
          padding: EdgeInsets.all(6 * scale),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: selected ? Colors.blue : Colors.grey.shade500,
              width: selected ? 2 : 1,
            ),
          ),
          child: ClipRect(child: child),
        ),
      ),
    );
  }

  Widget _buildDetailsContent(double scale) {
    final isBold = configuration.textStyle == LayoutTextStyle.bold;

    if (candidateDetails.isEmpty) {
      return const Text(
        'No candidate data available',
        maxLines: 1,
        softWrap: false,
        style: TextStyle(color: Colors.grey),
      );
    }

    final fontSize = configuration.detailsFontSize * scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final field in candidateDetails)
          SizedBox(
            width: double.infinity,
            child: Text(
              '${field.key} : ${field.value}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBarcodeContent(double scale) {
    const bars = <int>[
      2,
      1,
      3,
      1,
      1,
      2,
      2,
      1,
      3,
      1,
      2,
      2,
      1,
      3,
      1,
      2,
      1,
      1,
      3,
      2,
      2,
      1,
      1,
      3,
      2,
      1,
      2,
      3,
      1,
      1,
      2,
      2,
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < bars.length; i++)
                Expanded(
                  flex: bars[i],
                  child: Container(
                    color: i.isEven ? Colors.black : Colors.white,
                  ),
                ),
            ],
          ),
        ),
        if (configuration.showBarcodeNumber)
          Padding(
            padding: EdgeInsets.only(top: 4 * scale),
            child: Text(
              barcodeValue,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 10 * scale,
                fontWeight: configuration.textStyle == LayoutTextStyle.bold
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
      ],
    );
  }
}
