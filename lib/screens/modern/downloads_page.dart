import 'package:atba/models/library_items/library_item.dart';
import 'package:atba/models/library_items/downloadable_item.dart';
import 'package:atba/models/library_items/queued_torrent.dart';
import 'package:atba/models/library_items/torrent.dart';
import 'package:atba/models/library_items/usenet.dart';
import 'package:atba/screens/modern/add_download_page.dart';
import 'package:atba/screens/modern/file_explorer_page.dart';
import 'package:atba/services/library_page_state.dart';
import 'package:atba/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'common.dart';

enum TransferFilter { all, active, completed, waiting, failed, cached }

String transferType(LibraryItem item) => switch (item) {
  Torrent() => 'Torrent',
  Usenet() => 'Usenet',
  QueuedTorrent() => 'En cola',
  _ => 'Web',
};
bool transferMatches(LibraryItem item, TransferFilter filter) {
  final state = item.downloadState.toLowerCase();
  return switch (filter) {
    TransferFilter.all => true,
    TransferFilter.active => item.active && !item.downloadFinished,
    TransferFilter.completed => item.downloadFinished,
    TransferFilter.waiting =>
      item is QueuedTorrent ||
          state.contains('paused') ||
          state.contains('queued') ||
          state.contains('pending'),
    TransferFilter.failed =>
      state.contains('error') ||
          state.contains('fail') ||
          state == 'missingfiles',
    TransferFilter.cached =>
      (item is Torrent && item.cached) || state == 'cached',
  };
}

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});
  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final _search = TextEditingController();
  TransferFilter _filter = TransferFilter.all;
  String _sort = 'Newest';
  bool _compact = false;
  bool _busy = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _delete(LibraryPageState state) async {
    if (_busy ||
        !await confirmAction(
          context,
          '¿Eliminar ${state.selectedItems.length} elementos?',
          'Se eliminarán de TorBox. Los fallos individuales conservarán el elemento y su caché.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await state.deleteSelectedItems();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LibraryPageState>();
    final rows = state.items
        .where(
          (item) =>
              transferMatches(item, _filter) &&
              item.name.toLowerCase().contains(
                _search.text.trim().toLowerCase(),
              ),
        )
        .toList();
    rows.sort(LibraryPageState.sortingOptions[_sort]);
    const labels = [
      'Todas',
      'Activas',
      'Completadas',
      'En espera',
      'Fallidas',
      'En caché',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.isSelecting
              ? '${state.selectedItems.length} seleccionadas'
              : 'Descargas',
        ),
        actions: [
          IconButton(
            tooltip: _compact ? 'Vista de tarjetas' : 'Vista compacta',
            onPressed: () => setState(() => _compact = !_compact),
            icon: Icon(
              _compact ? Icons.view_agenda_outlined : Icons.view_list_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Actualizar biblioteca',
            onPressed: state.isRefreshing ? null : state.refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() => {}),
              decoration: const InputDecoration(
                hintText: 'Buscar en tu biblioteca',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(32) + 16,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: TransferFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => FilterChip(
                label: Text(labels[index]),
                selected: _filter.index == index,
                onSelected: (_) =>
                    setState(() => _filter = TransferFilter.values[index]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: Text('${rows.length} elementos')),
                DropdownButton<String>(
                  value: _sort,
                  underline: const SizedBox.shrink(),
                  items:
                      const [
                            'Newest',
                            'Oldest',
                            'A to Z',
                            'Largest',
                            'Smallest',
                            'Progress',
                          ]
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(switch (s) {
                                'Newest' => 'Más recientes',
                                'Oldest' => 'Más antiguos',
                                'A to Z' => 'Nombre',
                                'Largest' => 'Mayor tamaño',
                                'Smallest' => 'Menor tamaño',
                                _ => 'Progreso',
                              }),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _sort = value);
                  },
                ),
              ],
            ),
          ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StatusMessage(
                state.errorMessage!,
                onRetry: state.refreshAll,
              ),
            ),
          if (state.actionErrorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StatusMessage(state.actionErrorMessage!),
            ),
          if (state.isLoading) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: state.refreshAll,
              child: rows.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              state.isLoading
                                  ? 'Cargando biblioteca…'
                                  : 'No hay elementos para este filtro.',
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final item = rows[index];
                        final selected = state.selectedItems.any(
                          (i) => i.identity == item.identity,
                        );
                        final progress = item.progress.isFinite
                            ? item.progress.clamp(0.0, 1.0)
                            : null;
                        final card = InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onLongPress: () => state.toggleSelection(item),
                          onTap: () {
                            if (state.isSelecting) {
                              state.toggleSelection(item);
                              return;
                            }
                            if (item is DownloadableItem) {
                              openFileExplorer(context, item);
                            }
                          },
                          child: Padding(
                            padding: EdgeInsets.all(_compact ? 12 : 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.check_circle
                                          : item.downloadFinished
                                          ? Icons.cloud_done_outlined
                                          : Icons.cloud_download_outlined,
                                      color: selected
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                    if (item is QueuedTorrent)
                                      IconButton(
                                        tooltip: 'Iniciar elemento en cola',
                                        onPressed: () async {
                                          final result = await item.resume();
                                          if (context.mounted) {
                                            showResult(
                                              context,
                                              result.success
                                                  ? 'Inicio solicitado'
                                                  : 'TorBox no pudo iniciar este elemento.',
                                            );
                                          }
                                          await state.refreshAll();
                                        },
                                        icon: const Icon(Icons.play_arrow),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'TorBox · ${transferType(item)} · ${item.downloadState.isEmpty ? 'En cola' : item.downloadState}',
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 8),
                                if (progress != null && item is! QueuedTorrent)
                                  Semantics(
                                    label: 'Progreso en TorBox',
                                    value:
                                        '${(progress * 100).toStringAsFixed(1)} por ciento',
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    Text(getReadableSize(item.size)),
                                    if (progress != null &&
                                        item is! QueuedTorrent)
                                      Text(
                                        '${(progress * 100).toStringAsFixed(1)} %',
                                      ),
                                    if ((item.downloadSpeed ?? 0) > 0)
                                      Text(
                                        '${getReadableSize(item.downloadSpeed!)}/s',
                                      ),
                                    if (item.eta > 0 &&
                                        item.active &&
                                        (item.downloadSpeed ?? 0) > 0)
                                      Text(
                                        'ETA ${Duration(seconds: item.eta)}',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                        return KeyedSubtree(
                          key: ValueKey(item.identity),
                          child: _compact
                              ? card
                              : Card(
                                  color: selected
                                      ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                      : null,
                                  child: card,
                                ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: state.isSelecting
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openAddDownload(context),
              icon: const Icon(Icons.add),
              label: const Text('Añadir'),
            ),
      bottomNavigationBar: state.isSelecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: _busy ? null : () => state.clearSelection(),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                    ),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () {
                              for (final item in rows) {
                                if (!state.selectedItems.any(
                                  (i) => i.identity == item.identity,
                                )) {
                                  state.toggleSelection(item);
                                }
                              }
                            },
                      icon: const Icon(Icons.select_all),
                      label: const Text('Visibles'),
                    ),
                    if (state.selectedItems.every(
                      (i) => i is Torrent || i is Usenet || i is QueuedTorrent,
                    ))
                      TextButton.icon(
                        onPressed: _busy ? null : state.resumeSelectedItems,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Reanudar'),
                      ),
                    if (state.selectedItems.every((i) => i is Usenet))
                      TextButton.icon(
                        onPressed: _busy ? null : state.stopSelectedItems,
                        icon: const Icon(Icons.pause),
                        label: const Text('Pausar'),
                      ),
                    TextButton.icon(
                      onPressed: _busy ? null : () => _delete(state),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
