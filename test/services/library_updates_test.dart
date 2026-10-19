import 'dart:async';

import 'package:atba/models/torbox_api_response.dart';
import 'package:atba/services/cache/library_item_cache_service.dart';
import 'package:atba/services/library_page_state.dart';
import 'package:atba/services/torbox_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

class FakeLibraryApi extends TorboxAPI {
  FakeLibraryApi() : super(secureStorageService: MemorySecureStorage());
  double progress = 0.1;
  bool fail = false;
  int requests = 0;
  Completer<void>? wait;
  Future<TorboxAPIResponse> _list() async {
    requests++;
    await wait?.future;
    return TorboxAPIResponse(
      success: !fail,
      detail: fail ? '503' : '',
      data: fail ? null : [transferJson(progress: progress)],
    );
  }

  @override
  Future<TorboxAPIResponse> getTorrentsList({
    bool? bypassCache,
    int? torrentId,
    int? offset,
    int? limit,
  }) => _list();
  @override
  Future<TorboxAPIResponse> getWebDownloadsList({
    bool? bypassCache,
    int? webId,
    int? offset,
    int? limit,
  }) => _list();
  @override
  Future<TorboxAPIResponse> getUsenetDownloadsList({
    bool? bypassCache,
    int? usenetId,
    int? offset,
    int? limit,
  }) => _list();
  @override
  Future<TorboxAPIResponse> getQueuedItemsList({
    bool? bypassCache,
    int? id,
    int? offset,
    int? limit,
    FileType? type,
  }) async => TorboxAPIResponse(success: true, detail: '', data: []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Settings.init(cacheProvider: SharePreferenceCache());
  });
  test(
    'progress, completion and same-ID types share a fresh snapshot',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final api = FakeLibraryApi();
      final state = LibraryPageState.withServices(
        apiService: api,
        cacheService: LibraryItemCacheService(database: db),
        autoStart: false,
      );
      await state.initialized;
      await state.refreshAll();
      expect(state.items.length, 3);
      expect(state.findItem('torrent:1')!.progress, 0.1);
      state.toggleSelection(state.findItem('torrent:1')!);
      state.toggleSelection(state.findItem('webdownload:1')!);
      expect(state.selectedItems.length, 2);
      api.progress = 0.7;
      await state.refreshAll();
      expect(state.items.map((i) => i.progress), everyElement(0.7));
      api.fail = true;
      await state.refreshAll();
      expect(state.items.map((i) => i.progress), everyElement(0.7));
      expect(state.isStale, isTrue);
      api.fail = false;
      api.progress = 1;
      await state.refreshAll();
      expect(state.items.every((i) => i.downloadFinished), isTrue);
      expect(state.errorMessage, isNull);
      state.dispose();
      await db.close();
    },
  );
  test(
    'simultaneous refreshes deduplicate, dispose ignores late responses',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final api = FakeLibraryApi()..wait = Completer<void>();
      final state = LibraryPageState.withServices(
        apiService: api,
        cacheService: LibraryItemCacheService(database: db),
        autoStart: false,
      );
      await state.initialized;
      final one = state.refreshAll();
      final two = state.refreshAll();
      expect(api.requests, 3);
      var notifications = 0;
      state.addListener(() => notifications++);
      state.dispose();
      api.wait!.complete();
      await Future.wait([one, two]);
      expect(notifications, 0);
      expect(api.downloadsPageState, isNull);
      await db.close();
    },
  );
  test('lifecycle and visibility control the single scheduler', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final api = FakeLibraryApi();
    final state = LibraryPageState.withServices(
      apiService: api,
      cacheService: LibraryItemCacheService(database: db),
      autoStart: false,
    );
    await state.initialized;
    state.didChangeAppLifecycleState(AppLifecycleState.paused);
    state.setVisible(false);
    expect(api.requests, 0);
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(api.requests, 0);
    state.setVisible(true);
    await state.refreshAll();
    expect(api.requests, 3);
    state.dispose();
    await db.close();
  });
}
