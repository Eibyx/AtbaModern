import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:atba/models/library_items/downloadable_item.dart';
import 'package:atba/models/library_items/torrent.dart';
import 'package:atba/models/library_items/usenet.dart';
import 'package:atba/models/widgets/downloads_prompt.dart';
import 'package:atba/screens/jobs_status_page.dart';
import 'package:atba/services/library_page_state.dart';
import 'package:atba/services/torbox_service.dart';
import 'package:atba/services/video_playback_service.dart';
import 'package:atba/config/constants.dart';
import 'package:atba/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common.dart';

Future<void> openFileExplorer(BuildContext context, DownloadableItem item) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<LibraryPageState>(),
          child: FileExplorerPage(initialItem: item),
        ),
      ),
    );

class FileExplorerPage extends StatefulWidget {
  final DownloadableItem initialItem;
  const FileExplorerPage({super.key, required this.initialItem});
  @override
  State<FileExplorerPage> createState() => _FileExplorerPageState();
}

class _FileExplorerPageState extends State<FileExplorerPage> {
  final _search = TextEditingController();
  final Set<int> _selected = {};
  bool _bySize = false;
  bool _busy = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _perform(
    DownloadableItem item,
    List<DownloadableFile> files,
    String action,
  ) async {
    if (_busy || files.isEmpty) return;
    final api = context.read<TorboxAPI>();
    if (action == 'download' &&
        !kIsWeb &&
        Settings.getValue<String>(Constants.folderPath) == null) {
      if (!await showPermissionDialog(context) || !mounted) return;
    }
    setState(() => _busy = true);
    var done = 0;
    final links = <String>[];
    try {
      for (final file in files) {
        if (!mounted) break;
        if (action == 'download') {
          if (!(await item.downloadFile(file)).success) {
            throw StateError('No se pudo solicitar la descarga.');
          }
        } else if (action == 'drive') {
          final type = item is Torrent
              ? IntegrationFileType.torrent
              : item is Usenet
              ? IntegrationFileType.usenet
              : IntegrationFileType.webdownload;
          final response = await api.queueIntegration(
            QueueableIntegration.google,
            item.id,
            fileId: file.id,
            zip: false,
            type: type,
          );
          if (!response.success) {
            throw StateError(
              'Revisa la conexión de Google y el estado de los trabajos.',
            );
          }
        } else {
          final response = await item.getDownloadUrlByFileId(item.id, file.id);
          if (!response.success || response.data is! String) {
            throw StateError('Enlace no disponible.');
          }
          final link = response.data as String;
          if (action == 'preview') {
            if (file.mimetype.startsWith('video/')) {
              if (mounted) VideoPlaybackService.playURL(context, link);
            } else {
              await launchUrl(
                Uri.parse(link),
                mode: LaunchMode.externalApplication,
              );
            }
          } else {
            links.add(link);
          }
        }
        done++;
        if (files.length > 1) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
      if (links.isNotEmpty) {
        if (action == 'share' && !kIsWeb && Platform.isAndroid) {
          await AndroidIntent(
            action: 'android.intent.action.SEND',
            type: 'text/plain',
            arguments: {'android.intent.extra.TEXT': links.join('\n')},
          ).launchChooser('Compartir enlaces');
        } else {
          await Clipboard.setData(ClipboardData(text: links.join('\n')));
        }
      }
      if (mounted) {
        showResult(
          context,
          action == 'drive'
              ? '$done archivos encolados hacia Google Drive. Consulta Trabajos.'
              : action == 'download'
              ? '$done descargas solicitadas al dispositivo.'
              : '$done archivos procesados. Los enlaces pueden otorgar acceso temporal.',
        );
      }
    } on Object {
      if (mounted) {
        showResult(
          context,
          'Operación incompleta ($done/${files.length}). Revisa la sesión o los trabajos antes de reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryPageState>();
    final current = library.findItem(widget.initialItem.identity);
    final item = current is DownloadableItem ? current : widget.initialItem;
    final files = item.files
        .where((f) => f.name.toLowerCase().contains(_search.text.toLowerCase()))
        .toList();
    files.sort(
      _bySize
          ? (a, b) => b.size.compareTo(a.size)
          : (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    final selected = item.files.where((f) => _selected.contains(f.id)).toList();
    final progress = item.progress.isFinite
        ? item.progress.clamp(0.0, 1.0)
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivos en TorBox'),
        actions: [
          IconButton(
            tooltip: 'Trabajos de integración',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JobsStatusPage()),
            ),
            icon: const Icon(Icons.sync_alt),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: library.refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Almacenamiento remoto · ${getReadableSize(item.size)} · ${item.downloadState}',
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                  Text('${(progress * 100).toStringAsFixed(1)} % en TorBox'),
                ],
                if (current == null)
                  const StatusMessage(
                    'Este elemento ya no aparece en el último listado; se conserva la vista anterior.',
                  ),
                if (library.errorMessage != null)
                  StatusMessage(library.errorMessage!),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() => {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar archivos o extensiones',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${files.length} archivos · ${selected.length} seleccionados',
                      ),
                    ),
                    IconButton(
                      tooltip: _bySize
                          ? 'Ordenar por nombre'
                          : 'Ordenar por tamaño',
                      onPressed: () => setState(() => _bySize = !_bySize),
                      icon: const Icon(Icons.sort),
                    ),
                    IconButton(
                      tooltip: 'Seleccionar visibles',
                      onPressed: () => setState(
                        () => _selected.addAll(files.map((f) => f.id)),
                      ),
                      icon: const Icon(Icons.select_all),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return Card(
                  child: ListTile(
                    leading: Checkbox(
                      value: _selected.contains(file.id),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              if (value == true) {
                                _selected.add(file.id);
                              } else {
                                _selected.remove(file.id);
                              }
                            }),
                    ),
                    title: Text(
                      file.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${file.name.split('.').last.toUpperCase()} · ${getReadableSize(file.size)}',
                    ),
                    onTap: _busy
                        ? null
                        : () => _perform(item, [file], 'preview'),
                    trailing: PopupMenuButton<String>(
                      enabled: !_busy,
                      onSelected: (action) => _perform(item, [file], action),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'copy',
                          child: Text('Copiar enlace'),
                        ),
                        if (!kIsWeb && Platform.isAndroid)
                          const PopupMenuItem(
                            value: 'share',
                            child: Text('Compartir enlace'),
                          ),
                        const PopupMenuItem(
                          value: 'download',
                          child: Text('Descargar al dispositivo'),
                        ),
                        const PopupMenuItem(
                          value: 'drive',
                          child: Text('Enviar a Google Drive'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (files.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hay archivos disponibles para esta búsqueda.'),
            ),
        ],
      ),
      bottomNavigationBar: selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _selected.clear()),
                      child: const Text('Limpiar selección'),
                    ),
                    IconButton(
                      tooltip: 'Copiar enlaces',
                      onPressed: _busy
                          ? null
                          : () => _perform(item, selected, 'copy'),
                      icon: const Icon(Icons.copy),
                    ),
                    if (!kIsWeb && Platform.isAndroid)
                      IconButton(
                        tooltip: 'Compartir enlaces',
                        onPressed: _busy
                            ? null
                            : () => _perform(item, selected, 'share'),
                        icon: const Icon(Icons.share_outlined),
                      ),
                    IconButton(
                      tooltip: 'Descargar al dispositivo',
                      onPressed: _busy
                          ? null
                          : () => _perform(item, selected, 'download'),
                      icon: const Icon(Icons.download_outlined),
                    ),
                    IconButton(
                      tooltip: 'Enviar a Google Drive',
                      onPressed: _busy
                          ? null
                          : () => _perform(item, selected, 'drive'),
                      icon: const Icon(Icons.drive_file_move_outline),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
