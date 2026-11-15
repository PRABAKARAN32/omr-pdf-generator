import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../job_management/models/job_info.dart';
import '../../job_management/services/job_storage_service.dart';

final jobStorageServiceProvider = Provider<JobStorageService>((ref) {
  return JobStorageService();
});

final savedJobsProvider = FutureProvider<List<JobInfo>>((ref) async {
  final storage = ref.watch(jobStorageServiceProvider);

  return storage.getSavedJobs();
});
