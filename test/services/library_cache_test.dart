import 'dart:convert';
import 'dart:io';

import 'package:atba/models/library_items/torrent.dart';
import 'package:atba/models/library_items/usenet.dart';
import 'package:atba/models/library_items/webdownload.dart';
import 'package:atba/services/cache/library_item_cache_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('same numeric ID persists independently by transfer type', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final cache = LibraryItemCacheService(database: db);
    await cache.saveItems([
      Torrent.fromJson(transferJson()),
      WebDownload.fromJson(transferJson()),
      Usenet.fromJson(transferJson()),
    ]);
    expect(
      (await cache.getAllItems()).map((i) => i.identity).toSet().length,
      3,
    );
    await cache.saveItems([WebDownload.fromJson(transferJson(progress: 0.8))]);
    expect((await cache.getAllItems()).length, 3);
    expect(
      (await cache.getItems([1], itemType: 'webdownload')).single.progress,
      0.8,
    );
    expect(
      (await cache.getItems([1], itemType: 'torrent')).single.progress,
      0.2,
    );
    await cache.deleteItems([1], itemType: 'webdownload');
    expect((await cache.getAllItems()).length, 2);
    await db.close();
  });
  test(
    'v2 migration preserves existing rows and removes global ID uniqueness',
    () async {
      final original = Torrent.fromJson(transferJson()).toJsonGenerated();
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (sqlite) {
            sqlite.execute(
              'CREATE TABLE library_item_cache (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, item_id INTEGER NOT NULL UNIQUE, item_type TEXT NOT NULL, item_json TEXT NOT NULL, last_updated INTEGER NOT NULL)',
            );
            sqlite.execute(
              'INSERT INTO library_item_cache (item_id,item_type,item_json,last_updated) VALUES (?,?,?,?)',
              [1, 'torrent', jsonEncode(original), 1760000000],
            );
            sqlite.execute('PRAGMA user_version = 2');
          },
        ),
      );
      final cache = LibraryItemCacheService(database: db);
      expect((await cache.getAllItems()).single.name, 'Transferencia 1');
      await cache.saveItems([
        Usenet.fromJson(transferJson()),
        WebDownload.fromJson(transferJson()),
      ]);
      expect((await cache.getAllItems()).length, 3);
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 3);
      await db.close();
    },
  );
  test(
    'cache survives connection close and reopening a database file',
    () async {
      final dir = await Directory.systemTemp.createTemp('atba-cache-test-');
      final file = File('${dir.path}/cache.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      await LibraryItemCacheService(database: db)
          .saveItems([WebDownload.fromJson(transferJson(progress: 0.9))]);
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await LibraryItemCacheService(
          database: db,
        ).getAllItems()).single.progress,
        0.9,
      );
      await db.close();
      await dir.delete(recursive: true);
    },
  );
}
