import 'package:atba/models/library_items/torrent.dart';
import 'package:atba/models/library_items/usenet.dart';
import 'package:atba/models/library_items/webdownload.dart';
import 'package:atba/screens/jobs_status_page.dart';
import 'package:atba/screens/modern/add_download_page.dart';
import 'package:atba/screens/modern/notifications_page.dart';
import 'package:atba/services/account_overview.dart';
import 'package:atba/services/library_page_state.dart';
import 'package:atba/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'common.dart';

String planName(int? plan) => switch (plan) {
  0 => 'Free',
  1 => 'Essential',
  2 => 'Pro',
  3 => 'Standard',
  _ => 'Plan no disponible',
};

class DashboardPage extends StatelessWidget {
  final VoidCallback onDownloads;
  const DashboardPage({super.key, required this.onDownloads});
  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountOverview>();
    final library = context.watch<LibraryPageState>();
    final user = account.user;
    final expiry = DateTime.tryParse(user?.premiumExpiresAt ?? '');
    final stats = account.stats?.general;
    final active = library.items
        .where((i) => i.active && !i.downloadFinished)
        .length;
    final completed = library.items.where((i) => i.downloadFinished).length;
    final failed = library.items
        .where(
          (i) =>
              i.downloadState.toLowerCase().contains('error') ||
              i.downloadState.toLowerCase().contains('fail'),
        )
        .length;
    final recent = library.items.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Scaffold(
      appBar: AppBar(
        title: const Text('ATBA Modern'),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([account.refresh(), library.refreshAll()]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Text(
              'Tu TorBox, bajo control.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('Cuenta, descargas y transferencias en un solo lugar.'),
            if (account.loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            if (account.error != null)
              StatusMessage(account.error!, onRetry: account.refresh),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            user?.email ??
                                (user == null
                                    ? 'Comprobando cuenta'
                                    : 'Usuario #${user.id}'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      planName(user?.plan),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      user?.isSubscribed == null
                          ? 'Suscripción sin información'
                          : user!.isSubscribed!
                          ? 'Suscripción activa'
                          : 'Sin renovación automática',
                    ),
                    if (expiry != null)
                      Text(
                        'Vence: ${expiry.toLocal().toString().split(' ').first} · ${expiry.difference(DateTime.now()).inDays.clamp(0, 100000)} días restantes',
                      ),
                    Text(
                      account.error == null && user != null
                          ? 'Cuenta verificada por TorBox'
                          : 'Verificación pendiente',
                    ),
                  ],
                ),
              ),
            ),
            const SectionTitle('Descargas'),
            if (library.isStale)
              StatusMessage(
                library.errorMessage ??
                    'Mostrando la caché local mientras se actualiza.',
              ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Metric('Activas', active, Icons.downloading),
                _Metric('Completadas', completed, Icons.check_circle_outline),
                _Metric(
                  'En cola',
                  library.queuedTorrents.length,
                  Icons.schedule,
                ),
                _Metric('Con error', failed, Icons.error_outline),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Biblioteca TorBox'),
              subtitle: Text(
                '${library.items.whereType<Torrent>().length} torrents · ${library.items.whereType<Usenet>().length} Usenet · ${library.items.whereType<WebDownload>().length} web',
              ),
              trailing: const Icon(Icons.arrow_forward),
              onTap: onDownloads,
            ),
            const SectionTitle('Accesos rápidos'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add_link),
                  label: const Text('Magnet / URL'),
                  onPressed: () => openAddDownload(context),
                ),
                ActionChip(
                  avatar: const Icon(Icons.upload_file),
                  label: const Text('Torrent / NZB'),
                  onPressed: () => openAddDownload(context, importFile: true),
                ),
                ActionChip(
                  avatar: const Icon(Icons.sync_alt),
                  label: const Text('Trabajos'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JobsStatusPage()),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.notifications_none),
                  label: const Text('Notificaciones'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsPage(),
                    ),
                  ),
                ),
              ],
            ),
            const SectionTitle('Estadísticas oficiales'),
            if (stats == null)
              const Text(
                'No hay estadísticas disponibles en la respuesta actual.',
              )
            else
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.download),
                      title: const Text('Datos descargados'),
                      trailing: Text(getReadableSize(stats.totalDownloaded)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.upload),
                      title: const Text('Datos subidos'),
                      trailing: Text(getReadableSize(stats.totalUploaded)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.layers_outlined),
                      title: const Text('Transferencias registradas'),
                      trailing: Text('${stats.totalItemsDownloaded}'),
                    ),
                  ],
                ),
              ),
            if (account.stats?.bandwidth?.isNotEmpty == true) ...[
              const SectionTitle('Consumo de ancho de banda'),
              ...account.stats!.bandwidth!.reversed
                  .take(7)
                  .map(
                    (point) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(point.date),
                      trailing: Text(getReadableSize(point.bytesDownloaded)),
                    ),
                  ),
            ],
            if (recent.isNotEmpty) ...[
              const SectionTitle('Actividad reciente'),
              ...recent
                  .take(5)
                  .map(
                    (i) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        i.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        i.downloadState.isEmpty ? 'En cola' : i.downloadState,
                      ),
                      onTap: onDownloads,
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  const _Metric(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            Text(label),
          ],
        ),
      ),
    ),
  );
}
