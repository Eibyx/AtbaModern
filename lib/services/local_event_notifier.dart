import 'dart:io';

import 'package:atba/models/library_items/library_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

/// Foreground observations only: this is not push delivery or a background worker.
class LocalEventNotifier {
  static const settingKey = 'modern-local-notifications';
  final MethodChannel channel;
  final bool Function() enabled;
  final bool supported;
  String? lastError;
  LocalEventNotifier({
    MethodChannel? channel,
    bool Function()? enabled,
    bool? supported,
  }) : channel = channel ?? const MethodChannel('atba.modern/notifications'),
       enabled =
           enabled ??
           (() =>
               Settings.getValue<bool>(settingKey, defaultValue: false) ??
               false),
       supported = supported ?? (!kIsWeb && Platform.isAndroid);
  Future<bool> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!supported || !enabled()) return false;
    try {
      final shown = await channel.invokeMethod<bool>('show', {
        'id': id & 0x7fffffff,
        'title': title,
        'body': body,
      });
      lastError = shown == true
          ? null
          : 'El sistema no permitió mostrar la notificación.';
      return shown ?? false;
    } on PlatformException {
      lastError = 'Las notificaciones locales no están disponibles.';
      return false;
    } on MissingPluginException {
      lastError = 'Esta plataforma no dispone de notificaciones locales.';
      return false;
    }
  }

  Future<void> transfers(
    List<LibraryItem> before,
    List<LibraryItem> after,
  ) async {
    if (!supported || !enabled() || before.isEmpty) return;
    final old = {for (final item in before) item.identity: item};
    var emitted = 0;
    for (final item in after) {
      final previous = old[item.identity];
      if (previous == null) continue;
      final failed =
          item.downloadState.toLowerCase().contains('error') ||
          item.downloadState.toLowerCase().contains('fail');
      final wasFailed =
          previous.downloadState.toLowerCase().contains('error') ||
          previous.downloadState.toLowerCase().contains('fail');
      final completed = item.downloadFinished && !previous.downloadFinished;
      if (!completed && (!failed || wasFailed)) continue;
      await show(
        id: item.identity.hashCode,
        title: completed
            ? 'TorBox · Descarga completada'
            : 'TorBox · Descarga fallida',
        body: item.name,
      );
      if (++emitted >= 10) break;
    }
  }
}
