import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../barcode/models/barcode_configuration.dart';
import '../../barcode/providers/barcode_configuration_provider.dart';
import '../../client/providers/job_session_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../excel_import/providers/excel_provider.dart';
import '../../job_management/models/job_info.dart';
import '../../layout_designer/providers/layout_configuration_provider.dart';
import '../services/pdf_batch_service.dart';

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
  bool _cancelRequested = false;
  int _doneRecords = 0;
  int _totalRecords = 0;

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

      final future = _generatePreview();

      setState(() {
        _pdfFuture = future;
      });
    });
  }

  /// Builds a small PDF with only the first few candidates.
  Future<Uint8List> _generatePreview() {
    return ref.read(pdfBatchServiceProvider).generatePreview(
      data: ref.read(excelProvider).importedData,
      barcode: ref.read(barcodeConfigurationProvider),
      layout: ref.read(layoutConfigurationProvider),
    );
  }

  void _retry() {
    if (_isSaving) return;

    final future = _generatePreview();

    setState(() {
      _pdfFuture = future;
    });
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _safeName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return cleaned.isEmpty ? 'Client' : cleaned;
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _generateAllPdfs() async {
    if (_isSaving) return;

    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a folder for the PDF files',
    );

    if (folder == null || !mounted) return;

    final clientDetails = ref.read(jobSessionProvider);
    final excelState = ref.read(excelProvider);
    final excelData = excelState.importedData;
    final fileBytes = excelState.fileBytes;
    final barcodeConfig = ref.read(barcodeConfigurationProvider);
    final layoutConfig = ref.read(layoutConfigurationProvider);

    if (clientDetails == null || excelData == null || fileBytes == null) {
      _showSnack('Job or candidate details are missing.', color: Colors.red);
      return;
    }

    final batchService = ref.read(pdfBatchServiceProvider);

    setState(() {
      _isSaving = true;
      _cancelRequested = false;
      _doneRecords = 0;
      _totalRecords = excelData.recordCount;
    });

    try {
      final now = DateTime.now();

      final outDir = Directory(
        '$folder${Platform.pathSeparator}'
        'OMR_${_safeName(clientDetails.clientName)}_'
        '${now.year}${_two(now.month)}${_two(now.day)}_'
        '${_two(now.hour)}${_two(now.minute)}',
      );

      await batchService.generateToFolder(
        outDir: outDir,
        data: excelData,
        barcode: barcodeConfig,
        layout: layoutConfig,
        isCancelled: () => _cancelRequested,
        onProgress: (done, total) {
          if (!mounted) return;

          setState(() {
            _doneRecords = done;
            _totalRecords = total;
          });
        },
      );

      final job = JobInfo(
        id: clientDetails.jobId,
        clientName: clientDetails.clientName,
        orderDate: clientDetails.orderDate,
        generatedAt: DateTime.now(),
        recordCount: excelData.recordCount,
        barcodeFormat: barcodeConfig.format.label,
        pdfFileName: batchService.firstFileName(excelData.recordCount),
        outputFolder: outDir.path,
      );

      await ref.read(jobStorageServiceProvider).saveCompletedJob(
        job: job,
        sourceFileName: excelState.fileName ?? 'candidates.xlsx',
        sourceFileBytes: fileBytes,
        clientDetails: clientDetails.toJson(),
        barcodeConfiguration: barcodeConfig.toJson(),
        layoutConfiguration: layoutConfig.toJson(),
      );

      ref.invalidate(savedJobsProvider);

      if (!mounted) return;

      final fileCount = batchService.fileCountFor(excelData.recordCount);

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
            title: const Text('PDFs Saved Successfully!'),
            content: Text(
              'Your PDF files were saved to:\n${outDir.path}\n\n'
              'Client: ${clientDetails.clientName}\n'
              'Candidates: ${excelData.recordCount}\n'
              'PDF files: $fileCount '
              '(up to ${PdfBatchService.chunkSize} candidates each)',
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
      if (error is PdfCancelledException) {
        _showSnack('Generation cancelled. Files already written were kept.');
      } else {
        _showSnack('PDF generation failed: $error', color: Colors.red);
      }
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
          Text('Generating preview...'),
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
      allowPrinting: false,
      allowSharing: false,
      canChangePageFormat: false,
      canChangeOrientation: false,
      pdfFileName: 'OMR_Preview.pdf',
    );
  }

  Widget _buildProgress() {
    final value = _totalRecords == 0 ? null : _doneRecords / _totalRecords;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: value),
          const SizedBox(height: 6),
          Text(
            _cancelRequested
                ? 'Cancelling...'
                : 'Generated $_doneRecords of $_totalRecords candidates',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
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
                onPressed: _isSaving ? null : widget.onBack,
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
                label: const Text('Refresh preview'),
              ),
              const SizedBox(width: 10),
              if (_isSaving) ...[
                OutlinedButton(
                  onPressed: _cancelRequested
                      ? null
                      : () {
                          setState(() {
                            _cancelRequested = true;
                          });
                        },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
              ],
              FilledButton.icon(
                onPressed: pdfReady && !_isSaving ? _generateAllPdfs : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(_isSaving ? 'Generating...' : 'Generate all PDFs'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The preview shows only the first ${PdfBatchService.previewCount} '
            'candidates. "Generate all PDFs" saves every candidate '
            '(one page each) into PDF files of '
            '${PdfBatchService.chunkSize} candidates.',
          ),
          const SizedBox(height: 16),
          if (_isSaving) _buildProgress(),
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