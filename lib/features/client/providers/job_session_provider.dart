import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/job_client_details.dart';

final jobSessionProvider =
    NotifierProvider<JobSessionNotifier, JobClientDetails?>(
      JobSessionNotifier.new,
    );

class JobSessionNotifier extends Notifier<JobClientDetails?> {
  @override
  JobClientDetails? build() {
    return null;
  }

  void startJob({required String clientName, required DateTime orderDate}) {
    state = JobClientDetails(
      jobId: const Uuid().v4(),
      clientName: clientName.trim(),
      orderDate: orderDate,
      createdAt: DateTime.now(),
    );
  }

  void clearSession() {
    state = null;
  }
}
