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

  String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return cleaned.isEmpty ? 'candidates' : cleaned;
  }

  Future<Directory> _getJobDirectory(String jobId) async {
    _validateJobId(jobId);

    final jobsDirectory = await _getJobsDirectory();
    return Directory('${jobsDirectory.path}/$jobId');
  }

  /// Saves the job record in a lightweight way.
  ///
  /// The generated PDFs are already in the folder chosen by the user, so
  /// only the original import file and the small configuration files are
  /// stored. Candidate data is NOT duplicated as JSON, which keeps saving
  /// fast and small even for 10 lakh records.
  Future<void> saveCompletedJob({
    required JobInfo job,
    required String sourceFileName,
    required Uint8List sourceFileBytes,
    required Map<String, dynamic> clientDetails,
    required Map<String, dynamic> barcodeConfiguration,
    required Map<String, dynamic> layoutConfiguration,
  }) async {
    final jobDirectory = await _getJobDirectory(job.id);

    if (await jobDirectory.exists()) {
      throw StateError('A job with this ID already exists.');
    }

    await jobDirectory.create(recursive: true);

    try {
      await File(
        '${jobDirectory.path}/source_${_safeFileName(sourceFileName)}',
      ).writeAsBytes(sourceFileBytes, flush: true);

      await _writeJson('${jobDirectory.path}/job_info.json', job.toJson());

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

  /// Returns the first PDF file of the job (used for the dashboard preview).
  Future<Uint8List> getPdfBytes(JobInfo job) async {
    final folder = job.outputFolder;

    File pdfFile;

    if (folder != null) {
      pdfFile = File('$folder${Platform.pathSeparator}${job.pdfFileName}');
    } else {
      // Jobs saved by older versions kept the PDF inside the job folder.
      final jobDirectory = await _getJobDirectory(job.id);
      pdfFile = File('${jobDirectory.path}/${job.pdfFileName}');
    }

    if (!await pdfFile.exists()) {
      throw FileSystemException(
        'The saved PDF could not be found. It may have been moved or deleted.',
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

  /// Removes the job from the app history. PDF files exported to the folder
  /// chosen by the user are not deleted.
  Future<void> deleteJob(String jobId) async {
    final jobDirectory = await _getJobDirectory(jobId);

    if (await jobDirectory.exists()) {
      await jobDirectory.delete(recursive: true);
    }
  }
}