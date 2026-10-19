import 'package:atba/models/torbox_api_response.dart';
import 'package:atba/services/jobs_update_service.dart';
import 'package:atba/services/torbox_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

class FakeJobsApi extends TorboxAPI {
  FakeJobsApi() : super(secureStorageService: MemorySecureStorage());
  int requests = 0;
  @override
  Future<TorboxAPIResponse> getJobStatusById(int jobId) async {
    requests++;
    if (requests == 1) return TorboxAPIResponse(success: false, detail: '503');
    return TorboxAPIResponse(
      success: true,
      detail: '',
      data: {
        'id': jobId,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
        'auth_id': 'example',
        'hash': 'example',
        'type': 'torrent',
        'integration': 'google',
        'file_id': 1,
        'zip': false,
        'progress': requests == 2 ? 0.5 : 1.0,
        'detail': '',
        'download_url': null,
        'status': requests == 2 ? 'uploading' : 'completed',
        'task_id': 'example',
        'file_name': 'file.zip',
      },
    );
  }
}

void main() {
  test('integration job recovers after a transient failure, reaches completion and stops', () {
    fakeAsync((clock) {
      final api = FakeJobsApi();
      final events = <Map<String, dynamic>>[];
      var closed = false;
      JobsUpdateService(api)
          .monitorJob(7)
          .listen(events.add, onDone: () => closed = true);
      clock.flushMicrotasks();
      expect(events.single['type'], 'retrying');
      clock.elapse(const Duration(seconds: 8));
      expect(
        (events.last['updatedItem'] as JobQueueStatusResponse).progress,
        0.5,
      );
      clock.elapse(const Duration(seconds: 6));
      expect(
        (events.last['updatedItem'] as JobQueueStatusResponse).status,
        JobQueueStatus.completed,
      );
      expect(closed, isTrue);
      clock.elapse(const Duration(minutes: 5));
      expect(api.requests, 3);
    });
  });
  test('cancelling a monitor prevents any further scheduled request', () {
    fakeAsync((clock) {
      final api = FakeJobsApi();
      final subscription = JobsUpdateService(api).monitorJob(7).listen((_) {});
      clock.flushMicrotasks();
      subscription.cancel();
      clock.flushMicrotasks();
      clock.elapse(const Duration(minutes: 5));
      expect(api.requests, 1);
    });
  });
}
