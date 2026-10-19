import 'dart:async';

import 'package:atba/models/torbox_api_response.dart';
import 'package:atba/services/adaptive_poller.dart';
import 'package:atba/services/torbox_service.dart';

class JobsUpdateService {
  final TorboxAPI _apiService;
  static const doneStatuses = {JobQueueStatus.completed, JobQueueStatus.failed};
  JobsUpdateService(this._apiService);

  Stream<Map<String, dynamic>> monitorJob(int jobId) {
    late final StreamController<Map<String, dynamic>> controller;
    late final AdaptivePoller poller;
    poller = AdaptivePoller(
      poll: () async {
        final response = await _apiService.getJobStatusById(jobId);
        if (!response.success || response.data == null) {
          throw StateError('No se pudo consultar el trabajo.');
        }
        final item = JobQueueStatusResponse.fromJson(response.data);
        if (!controller.isClosed && controller.hasListener) {
          controller.add({'type': 'updated', 'updatedItem': item});
          if (doneStatuses.contains(item.status)) {
            poller.dispose();
            unawaited(controller.close());
          }
        }
        return !doneStatuses.contains(item.status);
      },
      onError: (_) {
        if (!controller.isClosed && controller.hasListener) {
          controller.add({'type': 'retrying'});
        }
      },
    );
    controller = StreamController(
      onListen: poller.start,
      onCancel: poller.dispose,
    );
    return controller.stream;
  }
}
