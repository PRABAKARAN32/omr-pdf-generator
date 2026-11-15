import 'package:flutter/material.dart';

import '../models/layout_configuration.dart';
import '../providers/layout_configuration_provider.dart';

class LayoutControls extends StatelessWidget {
  final LayoutConfiguration configuration;
  final LayoutConfigurationNotifier notifier;
  final List<String> warnings;

  const LayoutControls({
    super.key,
    required this.configuration,
    required this.notifier,
    required this.warnings,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBox = configuration.selectedBox == LayoutBoxType.details
        ? configuration.detailsBox
        : configuration.barcodeBox;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('SELECT BOX'),
        const SizedBox(height: 10),

        SegmentedButton<LayoutBoxType>(
          segments: const [
            ButtonSegment(
              value: LayoutBoxType.details,
              label: Text('Details Box'),
            ),
            ButtonSegment(
              value: LayoutBoxType.barcode,
              label: Text('Barcode Box'),
            ),
          ],
          selected: {configuration.selectedBox},
          onSelectionChanged: (selection) {
            notifier.selectBox(selection.first);
          },
        ),

        const SizedBox(height: 22),

        _sectionTitle('MOVE & RESIZE'),
        const SizedBox(height: 10),

        Row(
          children: [
            const Text('Movement step'),
            const Spacer(),
            Text('${configuration.movementStep.toStringAsFixed(0)} pt'),
          ],
        ),

        Slider(
          value: configuration.movementStep.clamp(1.0, 20.0),
          min: 1,
          max: 20,
          divisions: 19,
          onChanged: notifier.updateMovementStep,
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KEYBOARD SHORTCUTS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              _ShortcutRow(
                shortcut: '↑ ↓ ← →',
                description: 'Move selected box',
              ),
              SizedBox(height: 8),
              _ShortcutRow(
                shortcut: 'Ctrl + ↑',
                description: 'Decrease height',
              ),
              SizedBox(height: 8),
              _ShortcutRow(
                shortcut: 'Ctrl + ↓',
                description: 'Increase height',
              ),
              SizedBox(height: 8),
              _ShortcutRow(shortcut: 'Ctrl + ←', description: 'Decrease width'),
              SizedBox(height: 8),
              _ShortcutRow(shortcut: 'Ctrl + →', description: 'Increase width'),
              SizedBox(height: 10),
              Text(
                'Click a box in the A4 preview first to select it. '
                'You can also drag a box to move it.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        _sectionTitle('BOX DIMENSIONS'),
        const SizedBox(height: 10),

        _dimensionSlider(
          label: 'Width',
          value: selectedBox.width,
          min: 40,
          max: 550,
          onChanged: (value) {
            notifier.updateSelectedBoxDimensions(width: value);
          },
        ),

        _dimensionSlider(
          label: 'Height',
          value: selectedBox.height,
          min: 30,
          max: 400,
          onChanged: (value) {
            notifier.updateSelectedBoxDimensions(height: value);
          },
        ),

        if (configuration.selectedBox == LayoutBoxType.details) ...[
          const SizedBox(height: 12),
          _sectionTitle('DETAILS FONT SIZE'),
          _dimensionSlider(
            label: 'Font size',
            value: configuration.detailsFontSize,
            min: 6,
            max: 24,
            suffix: 'pt',
            onChanged: notifier.updateDetailsFontSize,
          ),
        ],

        const SizedBox(height: 22),

        _sectionTitle('LINE SPACING'),
        const SizedBox(height: 4),
        const Text(
          'Blank lines between the details, for example between Roll '
          'Number, Register Number, DOB and Gender.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 6),

        _lineSpacingControl(),

        const SizedBox(height: 22),

        _sectionTitle('BARCODE NUMBER'),
        const SizedBox(height: 8),

        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Show number')),
            ButtonSegment(value: false, label: Text('Hide number')),
          ],
          selected: {configuration.showBarcodeNumber},
          onSelectionChanged: (selection) {
            notifier.updateShowBarcodeNumber(selection.first);
          },
        ),

        const SizedBox(height: 22),

        _sectionTitle('TEXT STYLE'),
        const SizedBox(height: 8),

        SegmentedButton<LayoutTextStyle>(
          segments: const [
            ButtonSegment(
              value: LayoutTextStyle.normal,
              label: Text('Normal Text'),
            ),
            ButtonSegment(
              value: LayoutTextStyle.bold,
              label: Text('Bold Text'),
            ),
          ],
          selected: {configuration.textStyle},
          onSelectionChanged: (selection) {
            notifier.updateTextStyle(selection.first);
          },
        ),

        const SizedBox(height: 22),

        _sectionTitle('APPLY TO ALL PAGES'),

        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: configuration.applyDetailsToAll,
          title: const Text('Apply Details to all'),
          onChanged: (value) {
            notifier.updateApplyDetailsToAll(value ?? false);
          },
        ),

        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: configuration.applyBarcodeToAll,
          title: const Text('Apply Barcode to all'),
          onChanged: (value) {
            notifier.updateApplyBarcodeToAll(value ?? false);
          },
        ),

        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle('LAYOUT WARNINGS'),
          const SizedBox(height: 8),

          for (final warning in warnings.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(warning, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _lineSpacingControl() {
    const minValue = LayoutConfiguration.minLineSpacing;
    const maxValue = LayoutConfiguration.maxLineSpacing;
    const step = LayoutConfiguration.lineSpacingStep;

    final value = configuration.lineSpacing;
    final divisions = ((maxValue - minValue) / step).round();

    return Column(
      children: [
        Row(
          children: [
            const Text('Spacing between fields'),
            const Spacer(),
            IconButton(
              tooltip: 'Decrease by 0.1',
              visualDensity: VisualDensity.compact,
              onPressed: value <= minValue
                  ? null
                  : () => notifier.updateLineSpacing(value - step),
              icon: const Icon(Icons.remove_circle_outline, size: 20),
            ),
            SizedBox(
              width: 70,
              child: Text(
                '${value.toStringAsFixed(1)} lines',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: 'Increase by 0.1',
              visualDensity: VisualDensity.compact,
              onPressed: value >= maxValue
                  ? null
                  : () => notifier.updateLineSpacing(value + step),
              icon: const Icon(Icons.add_circle_outline, size: 20),
            ),
          ],
        ),
        Slider(
          value: value.clamp(minValue, maxValue),
          min: minValue,
          max: maxValue,
          divisions: divisions,
          label: value.toStringAsFixed(1),
          onChanged: notifier.updateLineSpacing,
        ),
      ],
    );
  }

  Widget _dimensionSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String suffix = 'pt',
    int? divisions,
  }) {
    final safeValue = value.clamp(min, max);

    return Column(
      children: [
        Row(
          children: [
            Text(label),
            const Spacer(),
            Text('${value.toStringAsFixed(0)} $suffix'),
          ],
        ),
        Slider(
          value: safeValue,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String shortcut;
  final String description;

  const _ShortcutRow({required this.shortcut, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 105,
          child: Text(
            shortcut,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(description, style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}