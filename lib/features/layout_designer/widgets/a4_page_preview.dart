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

class A4PagePreview extends StatefulWidget {
  final LayoutConfiguration configuration;
  final List<MapEntry<String, String>> candidateDetails;
  final String barcodeValue;

  final ValueChanged<LayoutBoxType> onSelectBox;
  final BoxMoveCallback onMoveBox;
  final BoxResizeCallback onResizeBox;

  /// When true the page is shown larger (zoomed in) and can be scrolled
  /// vertically with the side scroll bar or the mouse wheel.
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
  State<A4PagePreview> createState() => _A4PagePreviewState();
}

class _A4PagePreviewState extends State<A4PagePreview> {
  static const double _scrollBarSpace = 16;

  final ScrollController _scrollController = ScrollController();

  /// True while a box is being dragged, so the page does not scroll at the
  /// same time.
  bool _isDraggingBox = false;

  @override
  void didUpdateWidget(covariant A4PagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Back to the normal view: start from the top of the page again.
    if (oldWidget.zoomFirstHalf &&
        !widget.zoomFirstHalf &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _endDrag() {
    if (_isDraggingBox && mounted) {
      setState(() {
        _isDraggingBox = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final zoomed = widget.zoomFirstHalf;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Normal view: the whole page fits in the available area.
        // Zoomed view: the top half fills the available height, so the page
        // is taller than the area and is scrolled with the side bar.
        final visiblePageHeightPoints = zoomed
            ? LayoutConfiguration.pageHeight / 2
            : LayoutConfiguration.pageHeight;

        final availableWidth =
            constraints.maxWidth - (zoomed ? _scrollBarSpace : 0);

        final widthScale = availableWidth / LayoutConfiguration.pageWidth;
        final heightScale = constraints.maxHeight / visiblePageHeightPoints;

        final scale = widthScale < heightScale ? widthScale : heightScale;

        final pageWidth = LayoutConfiguration.pageWidth * scale;
        final fullPageHeight = LayoutConfiguration.pageHeight * scale;

        return Focus(
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Builder(
            builder: (focusContext) {
              return Scrollbar(
                controller: _scrollController,
                thumbVisibility: zoomed,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: _isDraggingBox
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: _buildPage(
                        focusContext: focusContext,
                        scale: scale,
                        pageWidth: pageWidth,
                        pageHeight: fullPageHeight,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPage({
    required BuildContext focusContext,
    required double scale,
    required double pageWidth,
    required double pageHeight,
  }) {
    final configuration = widget.configuration;

    return Container(
      width: pageWidth,
      height: pageHeight,
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
              widget.zoomFirstHalf
                  ? 'A4 PREVIEW · ZOOMED (scroll for the full page)'
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
            selected: configuration.selectedBox == LayoutBoxType.details,
            child: _buildDetailsContent(scale),
          ),

          _buildPositionedBox(
            context: focusContext,
            box: configuration.barcodeBoxForPage(
              configuration.selectedPageNumber,
            ),
            type: LayoutBoxType.barcode,
            scale: scale,
            selected: configuration.selectedBox == LayoutBoxType.barcode,
            child: _buildBarcodeContent(scale),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isControlPressed = HardwareKeyboard.instance.isControlPressed;

    final selectedType = widget.configuration.selectedBox;
    final step = widget.configuration.movementStep;

    if (key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }

    if (isControlPressed) {
      switch (key) {
        case LogicalKeyboardKey.arrowUp:
          widget.onResizeBox(selectedType, 0, -step);
          break;
        case LogicalKeyboardKey.arrowDown:
          widget.onResizeBox(selectedType, 0, step);
          break;
        case LogicalKeyboardKey.arrowLeft:
          widget.onResizeBox(selectedType, -step, 0);
          break;
        case LogicalKeyboardKey.arrowRight:
          widget.onResizeBox(selectedType, step, 0);
          break;
      }
    } else {
      switch (key) {
        case LogicalKeyboardKey.arrowUp:
          widget.onMoveBox(selectedType, 0, -step);
          break;
        case LogicalKeyboardKey.arrowDown:
          widget.onMoveBox(selectedType, 0, step);
          break;
        case LogicalKeyboardKey.arrowLeft:
          widget.onMoveBox(selectedType, -step, 0);
          break;
        case LogicalKeyboardKey.arrowRight:
          widget.onMoveBox(selectedType, step, 0);
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
      // Listener (not GestureDetector): dragging a box never fights with the
      // page scrolling.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          Focus.of(context).requestFocus();
          widget.onSelectBox(type);

          if (!_isDraggingBox) {
            setState(() {
              _isDraggingBox = true;
            });
          }
        },
        onPointerMove: (event) {
          widget.onMoveBox(
            type,
            event.delta.dx / scale,
            event.delta.dy / scale,
          );
        },
        onPointerUp: (_) => _endDrag(),
        onPointerCancel: (_) => _endDrag(),
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
    final configuration = widget.configuration;
    final candidateDetails = widget.candidateDetails;
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

    // Same calculation the PDF uses, so the preview matches the real PDF.
    final gap =
        LayoutConfiguration.lineSpacingInPoints(
          configuration.lineSpacing,
          configuration.detailsFontSize,
        ) *
        scale;

    // The scroll view (scrolling disabled) only prevents the debug
    // "RenderFlex overflowed" error when a large spacing is chosen. The
    // surrounding ClipRect hides whatever does not fit in the box.
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < candidateDetails.length; i++) ...[
            SizedBox(
              width: double.infinity,
              child: Text(
                '${candidateDetails[i].key} : ${candidateDetails[i].value}',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),
            ),
            if (i != candidateDetails.length - 1) SizedBox(height: gap),
          ],
        ],
      ),
    );
  }

  Widget _buildBarcodeContent(double scale) {
    final configuration = widget.configuration;

    const bars = <int>[
      2, 1, 3, 1, 1, 2, 2, 1, 3, 1, 2, 2, 1, 3, 1, 2,
      1, 1, 3, 2, 2, 1, 1, 3, 2, 1, 2, 3, 1, 1, 2, 2,
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
              widget.barcodeValue,
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