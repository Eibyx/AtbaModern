import 'package:atba/screens/home_page.dart';
import 'package:atba/services/account_overview.dart';
import 'package:atba/services/cache/library_item_cache_service.dart';
import 'package:atba/services/library_page_state.dart';
import 'package:atba/services/torbox_service.dart';
import 'package:atba/theme/modern_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torbox_api/torbox_api.dart';

import '../services/library_updates_test.dart' show FakeLibraryApi;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Settings.init(cacheProvider: SharePreferenceCache());
  });
  testWidgets(
    'four retained tabs and progress stay synchronized with file details',
    (tester) async {
      late AppDatabase db;
      final api = FakeLibraryApi();
      late LibraryPageState state;
      await tester.runAsync(() async {
        db = AppDatabase.forTesting(NativeDatabase.memory());
        state = LibraryPageState.withServices(
          apiService: api,
          cacheService: LibraryItemCacheService(database: db),
          autoStart: false,
        );
        await state.initialized;
        await state.refreshAll();
      });
      final account = AccountOverview(api)
        ..loading = false
        ..user = const UserData(
          id: 1,
          authId: 'example',
          email: 'user@example.test',
          plan: 2,
        );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TorboxAPI>.value(value: api),
            ChangeNotifierProvider.value(value: state),
            ChangeNotifierProvider.value(value: account),
          ],
          child: MaterialApp(
            theme: ModernTheme.build(Brightness.dark),
            home: const ModernShell(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MaterialApp), findsOneWidget);
      for (final name in [
        'Inicio',
        'Descargas',
        'Automatizaciones',
        'Cuenta',
      ]) {
        expect(find.text(name), findsWidgets);
      }
      await tester.tap(find.byIcon(Icons.cloud_download_outlined).last);
      await tester.pumpAndSettle();
      expect(find.text('10.0 %'), findsNWidgets(3));
      await tester.tap(find.text('Transferencia 1').first);
      await tester.pumpAndSettle();
      expect(find.text('10.0 % en TorBox'), findsOneWidget);
      api.progress = 0.66;
      await tester.runAsync(state.refreshAll);
      await tester.pump();
      expect(find.text('66.0 % en TorBox'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('66.0 %'), findsNWidgets(3));
      await tester.tap(find.text('Completadas').last);
      await tester.pump();
      expect(find.text('No hay elementos para este filtro.'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.auto_awesome_motion_outlined).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.cloud_download_outlined).last);
      await tester.pumpAndSettle();
      expect(find.text('No hay elementos para este filtro.'), findsOneWidget);
      state.errorMessage = 'Sin red · conservando datos';
      state.guardedNotifyListeners();
      await tester.pump();
      expect(find.text('Sin red · conservando datos'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      account.dispose();
      await tester.runAsync(db.close);
    },
  );
  test('unknown theme and filter values use honest fallbacks', () {
    expect(ModernTheme.mode('unrecognized'), ThemeMode.system);
  });
}
