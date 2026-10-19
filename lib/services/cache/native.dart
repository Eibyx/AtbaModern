import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';

Future<File> get databaseFile async {
  final dbFolder = await getApplicationCacheDirectory();
  return File('${dbFolder.path}/cache.db');
}

DatabaseConnection connect() {
  return DatabaseConnection.delayed(
    Future(() async {
      if (Platform.isAndroid) {
        await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
        final dbFolder = await getApplicationCacheDirectory();
        // SQLite needs an existing directory, never a database filename.
        final temp = Directory(p.join(dbFolder.path, 'torbox_cache', 'tmp'));
        await temp.create(recursive: true);
        sqlite3.tempDirectory = temp.path;
      }

      return NativeDatabase.createBackgroundConnection(await databaseFile);
    }),
  );
}
