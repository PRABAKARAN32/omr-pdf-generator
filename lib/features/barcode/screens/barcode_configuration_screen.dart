import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../excel_import/providers/excel_provider.dart';
import '../models/barcode_configuration.dart';
import '../providers/barcode_configuration_provider.dart';

class BarcodeConfigurationScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;

  const BarcodeConfigurationScreen({
    super.key,
    required this.onBack,
    required this.onNext,
  });

  @override
  ConsumerState<BarcodeConfigurationScreen> createState() =>
      _BarcodeConfigurationScreenState();
}

class _BarcodeConfigurationScreenState
    extends ConsumerState<BarcodeConfigurationScreen> {
  late final TextEditingController _startingNumberController;
  late final ProviderSubscription<BarcodeConfiguration> _subscription;

  @override
  void initState() {
    super.initState();

    final initialConfiguration = ref.read(barcodeConfigurationProvider);

    _startingNumberController = TextEditingController(
      text: initialConfiguration.startingNumber,
    );

    _subscription = ref.listenManual<BarcodeConfiguration>(
      barcodeConfigurationProvider,
      (previous, next) {
        if (_startingNumberController.text != next.startingNumber) {
          _startingNumberController.value = TextEditingValue(
            text: next.startingNumber,
            selection: TextSelection.collapsed(
              offset: next.startingNumber.length,
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription.close();
    _startingNumberController.dispose();
    super.dispose();
  }

  String _formatNumber(BigInt number, int width) {
    return number.toString().padLeft(width, '0');
  }

  String? _validateConfiguration({
    required BarcodeFormat format,
    required String startingNumber,
    required int recordCount,
  }) {
    if (recordCount <= 0) {
      return 'No candidate records are available. Please import Excel data.';
    }

    if (startingNumber.isEmpty) {
      return 'Starting barcode number is required.';
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(startingNumber)) {
      return 'Only numeric starting numbers are supported.';
    }

    if (format == BarcodeFormat.code32 && startingNumber.length > 8) {
      return 'Code 32 supports a maximum of 8 input digits.';
    }

    if (startingNumber.length > 18) {
      return 'Starting number cannot exceed 18 digits.';
    }

    final start = BigInt.tryParse(startingNumber);

    if (start == null) {
      return 'Please enter a valid starting number.';
    }

    final last = start + BigInt.from(recordCount - 1);

    if (format == BarcodeFormat.code32 && last > BigInt.from(99999999)) {
      return 'The generated Code 32 sequence exceeds its 8-digit range.';
    }

    if (last.toString().length > 18) {
      return 'The generated barcode sequence exceeds the supported range.';
    }

    return null;
  }

  void _continue() {
    final configuration = ref.read(barcodeConfigurationProvider);
    final excelData = ref.read(excelProvider).importedData;

    if (excelData == null) {
      _showMessage('Please import Excel data first.');
      return;
    }

    final error = _validateConfiguration(
      format: configuration.format,
      startingNumber: configuration.startingNumber,
      recordCount: excelData.recordCount,
    );

    if (error != null) {
      _showMessage(error);
      return;
    }

    widget.onNext();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildFormatOption({
    required BarcodeFormat format,
    required String description,
    required BarcodeFormat selectedFormat,
    required ValueChanged<BarcodeFormat> onSelected,
  }) {
    final isSelected = selectedFormat == format;

    return InkWell(
      onTap: () => onSelected(format),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<BarcodeFormat>(
              value: format,
              groupValue: selectedFormat,
              onChanged: (value) {
                if (value != null) onSelected(value);
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    format.label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSequencePreview({
    required BarcodeConfiguration configuration,
    required int recordCount,
  }) {
    final startText = configuration.startingNumber;

    if (startText.isEmpty ||
        !RegExp(r'^[0-9]+$').hasMatch(startText) ||
        recordCount <= 0) {
      return const SizedBox.shrink();
    }

    final start = BigInt.tryParse(startText);

    if (start == null) {
      return const SizedBox.shrink();
    }

    final width = configuration.format == BarcodeFormat.code32
        ? 8
        : startText.length;

    final normalizedStart = BigInt.parse(startText.padLeft(width, '0'));

    final last = normalizedStart + BigInt.from(recordCount - 1);

    if (configuration.format == BarcodeFormat.code32 &&
        last > BigInt.from(99999999)) {
      return const SizedBox.shrink();
    }

    if (last.toString().length > 18) {
      return const SizedBox.shrink();
    }

    final firstValue = _formatNumber(normalizedStart, width);
    final lastValue = _formatNumber(last, width);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Barcode Sequence Preview',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Text('First barcode: $firstValue'),
          const SizedBox(height: 6),
          Text('Last barcode: $lastValue'),
          const SizedBox(height: 6),
          Text('Total barcodes: $recordCount'),
          if (configuration.format == BarcodeFormat.code32) ...[
            const SizedBox(height: 8),
            const Text(
              'Code 32 will use an 8-digit numeric input and calculate '
              'its required check digit during barcode encoding.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configuration = ref.watch(barcodeConfigurationProvider);
    final excelData = ref.watch(excelProvider).importedData;
    final recordCount = excelData?.recordCount ?? 0;

    final notifier = ref.read(barcodeConfigurationProvider.notifier);

    final descriptions = {
      BarcodeFormat.code32:
          'Numeric format with an 8-digit data value and check digit.',
      BarcodeFormat.code39: 'Standard alphanumeric barcode format.',
      BarcodeFormat.code128:
          'Compact barcode format for numeric and alphanumeric data.',
    };

    final validationError = _validateConfiguration(
      format: configuration.format,
      startingNumber: configuration.startingNumber,
      recordCount: recordCount,
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Barcode Configuration',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Choose a barcode format and define the starting number.',
            style: TextStyle(color: Colors.grey.shade700),
          ),

          const SizedBox(height: 28),

          const Text(
            '1. Select Barcode Algorithm',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: BarcodeFormat.values.map((format) {
              return _buildFormatOption(
                format: format,
                description: descriptions[format]!,
                selectedFormat: configuration.format,
                onSelected: notifier.updateFormat,
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          const Text(
            '2. Starting Barcode Number',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: 350,
            child: TextField(
              controller: _startingNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(18),
              ],
              decoration: InputDecoration(
                hintText: 'Example: 50001',
                border: const OutlineInputBorder(),
                helperText: configuration.format == BarcodeFormat.code32
                    ? 'Code 32 accepts up to 8 input digits.'
                    : 'Numeric sequence starting value.',
              ),
              onChanged: notifier.updateStartingNumber,
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              const Text(
                'Candidate records:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(recordCount.toString()),
            ],
          ),

          const SizedBox(height: 16),

          _buildSequencePreview(
            configuration: configuration,
            recordCount: recordCount,
          ),

          if (validationError != null) ...[
            const SizedBox(height: 12),
            Text(validationError, style: const TextStyle(color: Colors.red)),
          ],

          const Spacer(),

          Row(
            children: [
              OutlinedButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: validationError == null ? _continue : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next: Layout Designer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
