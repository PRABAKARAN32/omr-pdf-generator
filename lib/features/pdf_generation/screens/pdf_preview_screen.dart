import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../barcode/providers/barcode_configuration_provider.dart';
import '../../barcode/models/barcode_configuration.dart';
import '../../client/providers/job_session_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../excel_import/providers/excel_provider.dart';
import '../../job_management/models/job_info.dart';
import '../../layout_designer/providers/layout_configuration_provider.dart';
import '../providers/pdf_provider.dart';

class PdfPreviewScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onDownloadComplete;
  final bool isActive;

  const PdfPreviewScreen({
    super.key,
    required this.onBack,
    required this.onDownloadComplete,
    required this.isActive,
  });

  @override
  ConsumerState<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends ConsumerState<PdfPreviewScreen> {
  Future<Uint8List>? _pdfFuture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    if (widget.isActive) {
      _scheduleGeneration();
    }
  }

  @override
  void didUpdateWidget(covariant PdfPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isActive && widget.isActive) {
      _scheduleGeneration();
    }
  }

  void _scheduleGeneration() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;

      final future = _generate();

      setState(() {
        _pdfFuture = future;
      });
    });
  }

  Future<Uint8List> _generate() {
    return ref.read(pdfProvider.notifier).generatePdf();
  }

  void _retry() {
    if (_isSaving) return;

    final future = _generate();

    setState(() {
      _pdfFuture = future;
    });
  }

  List<Map<String, String>> _buildCandidateData() {
    final excelData = ref.read(excelProvider).importedData;
    final barcodeConfig = ref.read(barcodeConfigurationProvider);

    if (excelData == null) {
      throw Exception('Candidate data is missing.');
    }

    final includedIndexes = excelData.includedColumns.toList()..sort();
    final start = BigInt.tryParse(barcodeConfig.startingNumber);

    if (start == null) {
      throw Exception('Invalid starting barcode number.');
    }

    final originalWidth = barcodeConfig.startingNumber.length;
    final result = <Map<String, String>>[];

    for (var rowIndex = 0; rowIndex < excelData.rows.length; rowIndex++) {
      final candidate = <String, String>{};

      for (final columnIndex in includedIndexes) {
        if (columnIndex < 0 || columnIndex >= excelData.headers.length) {
          continue;
        }

        final header = excelData.headers[columnIndex];
        final value = columnIndex < excelData.rows[rowIndex].length
            ? excelData.rows[rowIndex][columnIndex]
            : '';

        candidate[header] = value;
      }

      final barcodeValue = (start + BigInt.from(rowIndex)).toString().padLeft(
        originalWidth,
        '0',
      );

      candidate['__barcodeValue'] = barcodeValue;
      result.add(candidate);
    }

    return result;
  }

  Future<void> _downloadPdf() async {
    if (_isSaving || _pdfFuture == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final bytes = await _pdfFuture!;

      if (bytes.isEmpty) {
        throw Exception('The generated PDF is empty.');
      }

      if (!mounted) return;

      final savedFile = await FilePicker.saveFile(
        dialogTitle: 'Save OMR Candidate PDF',
        fileName: 'OMR_Candidates.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );

      if (!mounted || savedFile == null) return;

      final clientDetails = ref.read(jobSessionProvider);
      final excelData = ref.read(excelProvider).importedData;
      final barcodeConfig = ref.read(barcodeConfigurationProvider);
      final layoutConfig = ref.read(layoutConfigurationProvider);

      if (clientDetails == null || excelData == null) {
        throw Exception('Job or candidate details are missing.');
      }

      final downloadTime = DateTime.now();
      const pdfFileName = 'OMR_Candidates.pdf';

      final job = JobInfo(
        id: clientDetails.jobId,
        clientName: clientDetails.clientName,
        orderDate: clientDetails.orderDate,
        generatedAt: downloadTime,
        recordCount: excelData.recordCount,
        barcodeFormat: barcodeConfig.format.label,
        pdfFileName: pdfFileName,
      );

      final storage = ref.read(jobStorageServiceProvider);

      await storage.saveCompletedJob(
        job: job,
        pdfBytes: bytes,
        candidateData: _buildCandidateData(),
        clientDetails: clientDetails.toJson(),
        barcodeConfiguration: barcodeConfig.toJson(),
        layoutConfiguration: layoutConfig.toJson(),
      );

      ref.invalidate(savedJobsProvider);

      if (!mounted) return;

      final shouldGoToDashboard = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 52,
            ),
            title: const Text('PDF Saved Successfully!'),
            content: Text(
              'Your PDF has been exported and the complete job '
              'has been saved locally.\n\n'
              'Client: ${clientDetails.clientName}\n'
              'Candidates: ${excelData.recordCount}',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('Go to Dashboard'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      if (shouldGoToDashboard == true) {
        widget.onDownloadComplete();
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saving failed: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Generating candidate PDF...'),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'PDF generation failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(Uint8List bytes) {
    return PdfPreview(
      build: (format) async => bytes,
      allowPrinting: true,
      allowSharing: true,
      canChangePageFormat: false,
      canChangeOrientation: false,
      pdfFileName: 'OMR_Candidates.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pdfReady = _pdfFuture != null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back to layout designer',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PDF Preview',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                onPressed: pdfReady && !_isSaving ? _retry : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerate'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: pdfReady && !_isSaving ? _downloadPdf : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(_isSaving ? 'Saving...' : 'Download PDF'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Review the generated A4 document. '
            'Each candidate occupies one page.',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: !widget.isActive
                ? const Center(
                    child: Text('Complete the layout to generate your PDF.'),
                  )
                : _pdfFuture == null
                ? _buildLoading()
                : FutureBuilder<Uint8List>(
                    future: _pdfFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoading();
                      }

                      if (snapshot.hasError) {
                        return _buildError(snapshot.error!);
                      }

                      final bytes = snapshot.data;

                      if (bytes == null || bytes.isEmpty) {
                        return const Center(
                          child: Text('No PDF data was generated.'),
                        );
                      }

                      return _buildPreview(bytes);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
