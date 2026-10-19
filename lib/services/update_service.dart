import 'dart:async';

import 'package:atba/models/library_items/downloadable_item.dart';
import 'package:atba/models/library_items/torrent.dart';
import 'package:atba/models/library_items/usenet.dart';
import 'package:atba/models/library_items/webdownload.dart';
import 'package:atba/services/adaptive_poller.dart';
import 'package:atba/services/torbox_service.dart';

/// Compatibility monitor. The main library uses a single bulk list scheduler.
class UpdateService {
  final TorboxAPI _apiService;
  UpdateService(this._apiService);

  Stream<Map<String, dynamic>> monitorItem<T extends DownloadableItem>(
    int itemId,
  ) {
    late final StreamController<Map<String, dynamic>> controller;
    late final AdaptivePoller poller;
    poller = AdaptivePoller(
      poll: () async {
        final response = await switch (T) {
          const (Torrent) => _apiService.getTorrentsList(
            torrentId: itemId,
            bypassCache: true,
          ),
          const (WebDownload) => _apiService.getWebDownloadsList(
            webId: itemId,
            bypassCache: true,
          ),
          const (Usenet) => _apiService.getUsenetDownloadsList(
            usenetId: itemId,
            bypassCache: true,
          ),
          _ => throw UnsupportedError('Tipo de transferencia no soportado.'),
        };
        if (!response.success || response.data == null) {
          throw StateError('Actualización temporalmente no disponible.');
        }
        final json = Map<String, dynamic>.from(response.data as Map);
        final DownloadableItem item = switch (T) {
          const (Torrent) => Torrent.fromJson(json),
          const (WebDownload) => WebDownload.fromJson(json),
          const (Usenet) => Usenet.fromJson(json),
          _ => throw UnsupportedError('Tipo de transferencia no soportado.'),
        };
        if (!controller.isClosed && controller.hasListener) {
          controller.add({'type': 'updated', 'updatedItem': item});
          if (item.downloadFinished) {
            poller.dispose();
            unawaited(controller.close());
          }
        }
        return item.active;
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
