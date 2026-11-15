import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../job_management/models/job_info.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  final VoidCallback onNewProject;

  const DashboardScreen({super.key, required this.onNewProject});

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '-';

    final dateText = _formatDate(date);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$dateText  $hour:$minute';
  }

  Future<void> _previewJob(
    BuildContext context,
    WidgetRef ref,
    JobInfo job,
  ) async {
    try {
      final storage = ref.read(jobStorageServiceProvider);
      final bytes = await storage.getPdfBytes(job);

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            child: SizedBox(
              width: 950,
              height: 750,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            job.clientName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close preview',
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: PdfPreview(
                      build: (format) async => bytes,
                      allowPrinting: true,
                      allowSharing: true,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      pdfFileName: job.pdfFileName,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to preview PDF: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteJob(
    BuildContext context,
    WidgetRef ref,
    JobInfo job,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Job'),
        content: Text('Delete "${job.clientName}" and all its saved files?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(jobStorageServiceProvider).deleteJob(job.id);
      ref.invalidate(savedJobsProvider);
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete job: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildJobList(
    BuildContext context,
    WidgetRef ref,
    List<JobInfo> jobs,
  ) {
    if (jobs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No saved jobs found.'),
            SizedBox(height: 4),
            Text(
              'Completed PDF jobs will appear here.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'CLIENT NAME',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'DATE OF DOWNLOAD',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'CANDIDATES',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 180,
                child: Text(
                  'ACTIONS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: jobs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final job = jobs[index];

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.clientName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Barcode: ${job.barcodeFormat}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(_formatDateTime(job.generatedAt)),
                    ),
                    Expanded(flex: 1, child: Text(job.recordCount.toString())),
                    SizedBox(
                      width: 180,
                      child: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Preview saved PDF',
                            onPressed: () {
                              _previewJob(context, ref, job);
                            },
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                              color: Colors.blue,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete job',
                            onPressed: () {
                              _deleteJob(context, ref, job);
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(savedJobsProvider);

    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Unable to load jobs: $error'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => ref.invalidate(savedJobsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (jobs) {
        final totalCandidates = jobs.fold<int>(
          0,
          (total, job) => total + job.recordCount,
        );

        final totalPdfs = jobs.where((job) => job.generatedAt != null).length;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Dashboard',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => ref.invalidate(savedJobsProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onNewProject,
                    icon: const Icon(Icons.add),
                    label: const Text('New Project'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _stat('Saved Jobs', jobs.length.toString()),
                  _stat('Candidates', totalCandidates.toString()),
                  _stat('PDFs Downloaded', totalPdfs.toString()),
                ],
              ),
              const SizedBox(height: 25),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'JOB HISTORY',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(child: _buildJobList(context, ref, jobs)),
            ],
          ),
        );
      },
    );
  }
}
