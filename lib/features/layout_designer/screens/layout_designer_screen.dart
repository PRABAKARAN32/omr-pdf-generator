import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../barcode/providers/barcode_configuration_provider.dart';
import '../../excel_import/providers/excel_provider.dart';
import '../models/layout_configuration.dart';
import '../providers/layout_configuration_provider.dart';
import '../providers/layout_warnings_provider.dart';
import '../widgets/a4_page_preview.dart';
import '../widgets/layout_controls.dart';

class LayoutDesignerScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;

  const LayoutDesignerScreen({
    super.key,
    required this.onBack,
    required this.onNext,
  });

  @override
  ConsumerState<LayoutDesignerScreen> createState() =>
      _LayoutDesignerScreenState();
}

class _LayoutDesignerScreenState extends ConsumerState<LayoutDesignerScreen> {
  bool _zoomFirstHalf = false;

  @override
  Widget build(BuildContext context) {
    final configuration = ref.watch(layoutConfigurationProvider);
    final notifier = ref.read(layoutConfigurationProvider.notifier);

    final excelData = ref.watch(excelProvider).importedData;
    final barcodeConfig = ref.watch(barcodeConfigurationProvider);

    final layoutWarnings = ref.watch(layoutWarningsProvider);

    // Convert LayoutWarning objects into strings because
    // LayoutControls currently accepts List<String>.
    final warnings = layoutWarnings.map((warning) {
      return 'Page ${warning.pageNumber}: ${warning.message}';
    }).toList();

    // Build preview details using the first candidate.
    final candidateDetails = <MapEntry<String, String>>[];

    if (excelData != null && excelData.rows.isNotEmpty) {
      final firstCandidate = excelData.rows.first;

      for (final index in excelData.includedColumns) {
        if (index >= excelData.headers.length ||
            index >= firstCandidate.length) {
          continue;
        }

        candidateDetails.add(
          MapEntry(excelData.headers[index], firstCandidate[index]),
        );
      }
    }

    final barcodeValue = barcodeConfig.startingNumber.isEmpty
        ? '50001'
        : barcodeConfig.startingNumber;

    final pageValid =
        _isBoxInsidePage(configuration.detailsBox) &&
        _isBoxInsidePage(configuration.barcodeBox);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Center(
                        child: A4PagePreview(
                          configuration: configuration,
                          candidateDetails: candidateDetails,
                          barcodeValue: barcodeValue,
                          zoomFirstHalf: _zoomFirstHalf,
                          onSelectBox: notifier.selectBox,
                          onMoveBox: (type, dx, dy) {
                            notifier.moveBox(type, dx: dx, dy: dy);
                          },
                          onResizeBox: (type, widthDelta, heightDelta) {
                            notifier.resizeBox(
                              type,
                              widthDelta: widthDelta,
                              heightDelta: heightDelta,
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),

                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child: LayoutControls(
                          configuration: configuration,
                          notifier: notifier,
                          warnings: warnings,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildFooter(context, pageValid),
          ],
        ),
      ),
    );
  }

  bool _isBoxInsidePage(LayoutBox box) {
    return box.x >= 0 &&
        box.y >= 0 &&
        box.width > 0 &&
        box.height > 0 &&
        box.x + box.width <= LayoutConfiguration.pageWidth &&
        box.y + box.height <= LayoutConfiguration.pageHeight;
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PDF Layout Designer',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Position the Details Box and Barcode Box on the A4 page',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          Tooltip(
            message: 'Zoom into the top half of the A4 page',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _zoomFirstHalf,
                  onChanged: (value) {
                    setState(() {
                      _zoomFirstHalf = value ?? false;
                    });
                  },
                ),
                const Text('Zoom first half'),
              ],
            ),
          ),

          const SizedBox(width: 12),

          OutlinedButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool pageValid) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'A4 · Portrait · Measurements in PDF points',
              style: TextStyle(fontSize: 12),
            ),
          ),

          FilledButton.icon(
            onPressed: pageValid ? widget.onNext : null,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Preview PDF'),
          ),
        ],
      ),
    );
  }
}
