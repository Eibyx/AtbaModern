import 'package:atba/services/torbox_service.dart';
import 'package:flutter/foundation.dart';
import 'package:torbox_api/torbox_api.dart';

/// Account data shared by dashboard and account tab; refreshes coalesce.
class AccountOverview extends ChangeNotifier {
  final TorboxAPI api;
  UserData? user;
  UserStatsData? stats;
  String? error;
  bool loading = true;
  bool _disposed = false;
  Future<void>? _pending;
  AccountOverview(this.api);
  Future<void> refresh() =>
      _pending ??= _load().whenComplete(() => _pending = null);
  Future<void> _load() async {
    try {
      final client = api.authenticatedApi;
      if (client == null) throw StateError('Sin sesión');
      final responses = await Future.wait([
        client.user.getUserData(),
        client.user.getStats(
          general: true,
          bandwidth: true,
          bandwidthGrouping: 'day',
        ),
      ]);
      if (_disposed) return;
      final userResponse = responses[0] as TorBoxResponse<UserData>;
      final statsResponse = responses[1] as TorBoxResponse<UserStatsData>;
      if (userResponse.success && userResponse.data != null) {
        user = userResponse.data;
      }
      if (statsResponse.success) stats = statsResponse.data;
      error = userResponse.success && statsResponse.success
          ? null
          : 'TorBox no pudo actualizar todos los datos de la cuenta.';
    } on Object {
      if (_disposed) return;
      error = 'No se pudo verificar la cuenta en este momento. Se conservan los datos anteriores.';
    }
    loading = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
