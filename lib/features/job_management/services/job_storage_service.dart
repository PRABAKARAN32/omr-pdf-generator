import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/job_info.dart';

class JobStorageService {
  static const String _rootFolder = 'OMR_PDF_Generator';
  static const String _jobsFolder = 'jobs';

  Future<Directory> _getJobsDirectory() async {
    final appDirectory = await getApplicationSupportDirectory();

    final jobsDirectory = Directory(
      '${appDirectory.path}/$_rootFolder/$_jobsFolder',
    );

    if (!await jobsDirectory.exists()) {
      await jobsDirectory.create(recursive: true);
    }

    return jobsDirectory;
  }

  void _validateJobId(String jobId) {
    if (jobId.isEmpty ||
        jobId.contains('/') ||
        jobId.contains(r'\') ||
        jobId == '.' ||
        jobId == '..') {
      throw ArgumentError('Invalid job ID.');
    }
  }

  Future<Directory> _getJobDirectory(String jobId) async {
    _validateJobId(jobId);

    final jobsDirectory = await _getJobsDirectory();
    return Directory('${jobsDirectory.path}/$jobId');
  }

  /// Saves the PDF and all data required to preserve the completed job.
  Future<void> saveCompletedJob({
    required JobInfo job,
    required Uint8List pdfBytes,
    required List<Map<String, String>> candidateData,
    required Map<String, dynamic> clientDetails,
    required Map<String, dynamic> barcodeConfiguration,
    required Map<String, dynamic> layoutConfiguration,
  }) async {
    if (pdfBytes.isEmpty) {
      throw ArgumentError('Cannot save an empty PDF.');
    }

    final jobDirectory = await _getJobDirectory(job.id);

    if (await jobDirectory.exists()) {
      throw StateError('A job with this ID already exists.');
    }

    await jobDirectory.create(recursive: true);

    try {
      await File('${jobDirectory.path}/${job.pdfFileName}')
          .writeAsBytes(pdfBytes, flush: true);

      await _writeJson('${jobDirectory.path}/job_info.json', job.toJson());

      await _writeJson(
        '${jobDirectory.path}/candidate_data.json',
        candidateData,
      );

      await _writeJson(
        '${jobDirectory.path}/client_details.json',
        clientDetails,
      );

      await _writeJson(
        '${jobDirectory.path}/barcode_configuration.json',
        barcodeConfiguration,
      );

      await _writeJson(
        '${jobDirectory.path}/layout_configuration.json',
        layoutConfiguration,
      );
    } catch (_) {
      if (await jobDirectory.exists()) {
        await jobDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> _writeJson(String path, Object data) async {
    final file = File(path);

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
  }

  Future<List<JobInfo>> getSavedJobs() async {
    final jobsDirectory = await _getJobsDirectory();
    final entities = await jobsDirectory.list(followLinks: false).toList();

    final jobs = <JobInfo>[];

    for (final entity in entities) {
      if (entity is! Directory) continue;

      final infoFile = File('${entity.path}/job_info.json');

      if (!await infoFile.exists()) continue;

      try {
        final content = await infoFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        jobs.add(JobInfo.fromJson(json));
      } catch (_) {
        // Ignore incomplete or corrupted job records.
      }
    }

    jobs.sort((a, b) {
      final aDate = a.generatedAt ?? a.orderDate;
      final bDate = b.generatedAt ?? b.orderDate;
      return bDate.compareTo(aDate);
    });

    return jobs;
  }

  Future<Uint8List> getPdfBytes(JobInfo job) async {
    final jobDirectory = await _getJobDirectory(job.id);
    final pdfFile = File('${jobDirectory.path}/${job.pdfFileName}');

    if (!await pdfFile.exists()) {
      throw FileSystemException(
        'The saved PDF could not be found.',
        pdfFile.path,
      );
    }

    return pdfFile.readAsBytes();
  }

  Future<Map<String, dynamic>> getJobData(String jobId, String fileName) async {
    final jobDirectory = await _getJobDirectory(jobId);
    final file = File('${jobDirectory.path}/$fileName');

    if (!await file.exists()) {
      throw FileSystemException('Job data file not found.', file.path);
    }

    final decoded = jsonDecode(await file.readAsString());

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const FormatException('Unexpected job data format.');
  }

  Future<void> deleteJob(String jobId) async {
    final jobDirectory = await _getJobDirectory(jobId);

    if (await jobDirectory.exists()) {
      await jobDirectory.delete(recursive: true);
    }
  }
}
