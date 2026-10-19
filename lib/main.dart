import 'dart:io';

import 'package:atba/models/library_items/library_item.dart';
import 'package:atba/services/update_service.dart';
import 'package:atba/services/web_js_interop_service/web_js_interop_service.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:atba/theme/modern_theme.dart';
import 'package:atba/config/constants.dart';
import 'package:atba/models/widgets/multi_value_change_observer.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import 'package:provider/provider.dart';

import 'services/shared_prefs_service.dart';
import 'services/secure_storage_service.dart';
import 'services/torbox_service.dart';

import 'package:dynamic_color/dynamic_color.dart';

import 'screens/setup/api_screen.dart';
import 'screens/home_page.dart';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';

import 'app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) sendPostMessage();

    await initSettings();

    final sharedPrefsService = SharedPrefsService();
    await sharedPrefsService.init();

    final secureStorageService = SecureStorageService();

    final isFirstRun = sharedPrefsService.getString('isFirstRun') == null;

    final apiService = TorboxAPI(secureStorageService: secureStorageService);
    await apiService.init();

    final hasApiKey = apiService.hasApiKey;

    LibraryItem.initApiService(apiService);

    if (!kIsWeb) {
      FileDownloader().configureNotification(
        tapOpensFile: true,
        progressBar: true,
        running: TaskNotification('Downloading', '{progress} {filename}'),
        complete: TaskNotification('Download finished', '{filename}'),
        error: TaskNotification("Error", "{filename}"),
        paused: TaskNotification("Paused", "{filename}"),
        canceled: TaskNotification("Canceled", "{filename}"),
      );
    }
    if (!kIsWeb) {
      FileDownloader().configure(
        globalConfig: (Config.useExternalStorage, "always"),
      );
    }

    // Store exceptions mapped by taskId
    final Map<String, TaskException?> errorDetails = {};

    //  to listen for task status updates
    void taskStatusCallback(TaskStatusUpdate update) {
      if (update.status == TaskStatus.failed) {
        errorDetails[update.task.taskId] = update.exception;
      } else if (update.status == TaskStatus.complete ||
          update.status == TaskStatus.canceled) {
        errorDetails.remove(update.task.taskId);
      }
    }

    Future<void> notificationTapCallback(
      Task task,
      NotificationType notificationType,
    ) async {
      if (notificationType == NotificationType.error) {
        final exception = errorDetails[task.taskId];
        if (exception != null) {
          // Never log a downloader exception: it can contain a signed URL.
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/downloadError.txt');
          await file.writeAsString(
            'No se pudo completar la descarga. Comprueba la conexión, el espacio disponible y la vigencia del enlace de TorBox.',
          );
          OpenFile.open(file.path);
        }
      }
    }

    if (!kIsWeb) {
      FileDownloader().registerCallbacks(
        taskStatusCallback: taskStatusCallback,
        taskNotificationTapCallback: notificationTapCallback,
      );
    }

    runApp(
      MultiProvider(
        providers: [
          Provider<SharedPrefsService>.value(value: sharedPrefsService),
          Provider<SecureStorageService>.value(value: secureStorageService),
          ChangeNotifierProvider<TorboxAPI>.value(value: apiService),
          ProxyProvider<TorboxAPI, UpdateService>(
            update: (_, torboxApi, _) => UpdateService(torboxApi),
          ),
          ChangeNotifierProvider<AppState>(
            create: (_) => AppState(
              sharedPrefsService: sharedPrefsService,
              secureStorageService: secureStorageService,
              apiService: apiService,
            )..initializeApp(),
          ),
        ],
        child: AtbaApp(isFirstRun: isFirstRun, hasApiKey: hasApiKey),
      ),
    );
  } on Object {
    runApp(
      MaterialApp(
        title: 'ATBA Modern',
        theme: ModernTheme.build(Brightness.dark),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No se pudo iniciar el almacenamiento local. Las credenciales no se han eliminado.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: main,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> initSettings() async {
  await Settings.init(cacheProvider: SharePreferenceCache());
}

class AtbaApp extends StatelessWidget {
  final bool isFirstRun;
  final bool hasApiKey;
  const AtbaApp({required this.isFirstRun, required this.hasApiKey, super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final api = context.watch<TorboxAPI>();
    return MultiValueChangeObserver(
      cacheKeysWithDefaultValues: {
        Constants.theme: 'system',
        'modern-dynamic-colors': true,
      },
      builder: (context, values) => DynamicColorBuilder(
        builder: (light, dark) {
          final dynamicColors = values['modern-dynamic-colors'] == true;
          return MaterialApp(
            title: 'ATBA Modern',
            debugShowCheckedModeBanner: false,
            theme: ModernTheme.build(
              Brightness.light,
              dynamicColors: dynamicColors ? light : null,
            ),
            darkTheme: ModernTheme.build(
              Brightness.dark,
              dynamicColors: dynamicColors ? dark : null,
            ),
            themeMode: ModernTheme.mode(values[Constants.theme] as String?),
            home: appState.isLoading
                ? const SplashScreen()
                : appState.hasError
                ? const ErrorScreen()
                : api.hasApiKey
                ? HomeScreen(key: ValueKey(api.sessionVersion))
                : const ApiKeyScreen(),
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('An error occurred. Please restart the app.')),
    );
  }
}
