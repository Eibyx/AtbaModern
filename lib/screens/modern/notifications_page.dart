import 'package:atba/services/adaptive_poller.dart';
import 'package:atba/services/torbox_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:torbox_api/torbox_api.dart';

import 'common.dart';

String safeNotice(String message) => message
    .replaceAllMapped(RegExp(r'https?://[^\s<>]+'), (match) {
      final uri = Uri.tryParse(match.group(0)!);
      return uri?.replace(userInfo: '', query: '', fragment: '').toString() ??
          '[enlace]';
    })
    .replaceAll(
      RegExp(r'Bearer\s+\S+', caseSensitive: false),
      'Bearer [oculto]',
    );

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {
  late final AdaptivePoller _poller;
  List<NotificationData>? _items;
  String? _error;
  String _filter = 'Todas';
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poller = AdaptivePoller(
      poll: _load,
      idleInterval: const Duration(seconds: 30),
      onError: (_) {
        if (mounted) {
          setState(
            () => _error = 'No se pudieron actualizar las notificaciones. Se reintentará automáticamente.',
          );
        }
      },
    );
    _poller.start();
  }

  Future<bool> _load() async {
    final response = await context
        .read<TorboxAPI>()
        .authenticatedApi!
        .notifications
        .getNotificationFeed();
    if (!response.success) throw StateError('No disponible');
    if (mounted) {
      setState(() {
        _items = response.data ?? [];
        _items!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _error = null;
      });
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _poller.start();
    } else {
      _poller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller.dispose();
    super.dispose();
  }

  Future<void> _clear([int? id]) async {
    if (_busy ||
        !await confirmAction(
          context,
          id == null
              ? '¿Eliminar todas las notificaciones?'
              : '¿Eliminar esta notificación?',
          'TorBox eliminará los eventos seleccionados de tu cuenta.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final service = context.read<TorboxAPI>().authenticatedApi!.notifications;
      final result = id == null
          ? await service.clearAllNotifications()
          : await service.clearNotification(id);
      if (!result.success) throw StateError('No se pudo eliminar');
      await _poller.refresh();
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'No se pudo eliminar. Se conserva la lista anterior.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (_items ?? []).where((n) {
      final text = '${n.title} ${n.message}'.toLowerCase();
      return switch (_filter) {
        'Errores' => text.contains('error') || text.contains('fail'),
        'Completadas' => text.contains('complet') || text.contains('finished'),
        _ => true,
      };
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _poller.refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Eliminar todas',
            onPressed: _busy || _items?.isEmpty != false
                ? null
                : () => _clear(),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              children: ['Todas', 'Completadas', 'Errores']
                  .map(
                    (f) => ChoiceChip(
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_error != null) StatusMessage(_error!, onRetry: _poller.refresh),
          if (_items == null && _error == null) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _poller.refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: items.isEmpty ? 1 : items.length,
                itemBuilder: (context, index) {
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No hay notificaciones para este filtro.'),
                    );
                  }
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: Text(safeNotice(item.title)),
                      subtitle: Text(
                        '${safeNotice(item.message)}\n${item.createdAt}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Eliminar notificación',
                        onPressed: _busy ? null : () => _clear(item.id),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
