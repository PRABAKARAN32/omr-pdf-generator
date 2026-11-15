import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/excel_provider.dart';

class ExcelImportScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;

  const ExcelImportScreen({
    super.key,
    required this.onBack,
    required this.onNext,
  });

  @override
  ConsumerState<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends ConsumerState<ExcelImportScreen> {
  bool isPickingFile = false;

  Future<void> _pickExcelFile() async {
    if (isPickingFile) return;

    setState(() {
      isPickingFile = true;
    });

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (!mounted || file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      ref
          .read(excelProvider.notifier)
          .selectWorkbook(fileName: file.name, bytes: bytes);

      final state = ref.read(excelProvider);

      if (state.error != null) {
        _showMessage(state.error!);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('File selection failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          isPickingFile = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildFieldSelection() {
    final data = ref.watch(excelProvider).importedData;

    if (data == null) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(excelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select fields to include',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            TextButton(
              onPressed: notifier.selectAllColumns,
              child: const Text('Select All'),
            ),
            TextButton(
              onPressed: notifier.clearSelection,
              child: const Text('Clear All'),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: List.generate(data.headers.length, (index) {
            return SizedBox(
              width: 210,
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  data.headers[index],
                  overflow: TextOverflow.ellipsis,
                ),
                value: data.includedColumns.contains(index),
                onChanged: (_) => notifier.toggleColumn(index),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDataPreview() {
    final data = ref.watch(excelProvider).importedData;

    if (data == null) {
      return const Center(
        child: Text('Select an Excel file to preview its data.'),
      );
    }

    final includedColumns = data.includedColumns.toList()..sort();

    if (includedColumns.isEmpty) {
      return const Center(
        child: Text('Select at least one field to display the preview.'),
      );
    }

    if (data.rows.isEmpty) {
      return const Center(child: Text('No candidate records found.'));
    }

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: includedColumns.map((index) {
            return DataColumn(label: Text(data.headers[index]));
          }).toList(),
          rows: data.rows.map((row) {
            return DataRow(
              cells: includedColumns.map((index) {
                return DataCell(Text(index < row.length ? row[index] : ''));
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWarnings() {
    final data = ref.watch(excelProvider).importedData;

    if (data == null || data.warnings.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      title: Text(
        '${data.warnings.length} validation warning(s)',
        style: const TextStyle(color: Colors.orange),
      ),
      children: data.warnings.map((warning) {
        return ListTile(
          dense: true,
          leading: const Icon(Icons.warning_amber, color: Colors.orange),
          title: Text(warning),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(excelProvider);
    final data = state.importedData;

    final canContinue = data != null && data.includedColumns.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back to New Job',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              const Text(
                'Excel Import',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              ElevatedButton.icon(
                onPressed: isPickingFile ? null : _pickExcelFile,
                icon: const Icon(Icons.upload_file),
                label: Text(isPickingFile ? 'Loading...' : 'Select Excel File'),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  state.fileName ?? 'No file selected',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!, style: const TextStyle(color: Colors.red)),
          ],

          if (data != null) ...[
            const SizedBox(height: 20),

            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                Text('Records: ${data.recordCount}'),
                Text('Excel Fields: ${data.columnCount}'),
                Text('Selected Fields: ${data.includedColumns.length}'),
              ],
            ),

            const SizedBox(height: 20),
            _buildFieldSelection(),
            const Divider(height: 30),

            const Text(
              'Candidate Data Preview',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),
            Expanded(child: _buildDataPreview()),
            _buildWarnings(),
          ] else ...[
            const Expanded(
              child: Center(
                child: Text('Upload an Excel file to get started.'),
              ),
            ),
          ],

          const SizedBox(height: 12),

          Row(
            children: [
              OutlinedButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: canContinue ? widget.onNext : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next: Barcode'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
