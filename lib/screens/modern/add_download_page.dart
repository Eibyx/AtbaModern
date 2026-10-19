import 'dart:io';
import 'dart:typed_data';

import 'package:atba/models/library_items/torrent.dart';
import 'package:atba/models/torbox_api_response.dart';
import 'package:atba/services/download_input.dart';
import 'package:atba/services/library_page_state.dart';
import 'package:atba/services/torbox_service.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:file_picker/file_picker.dart' as picker show FileType;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:torbox_api/torbox_api.dart';

import 'common.dart';

Future<void> openAddDownload(
  BuildContext context, {
  String? initialText,
  String? initialFile,
  bool importFile = false,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<LibraryPageState>(),
      child: AddDownloadPage(
        initialText: initialText,
        initialFile: initialFile,
        importFile: importFile,
      ),
    ),
  ),
);

class AddDownloadPage extends StatefulWidget {
  final String? initialText;
  final String? initialFile;
  final bool importFile;
  const AddDownloadPage({
    super.key,
    this.initialText,
    this.initialFile,
    this.importFile = false,
  });
  @override
  State<AddDownloadPage> createState() => _AddDownloadPageState();
}

class _AddDownloadPageState extends State<AddDownloadPage> {
  late final TextEditingController _text;
  TorboxFileUpload? _file;
  bool _busy = false;
  String? _error;
  final Map<String, String> _results = {};
  final Set<String> _accepted = {};
  final Map<String, bool> _cached = {};
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialText);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialFile != null && !kIsWeb) {
        try {
          final file = File(widget.initialFile!);
          if (await file.length() > 10 * 1024 * 1024) {
            throw const FormatException(
              'Archivo demasiado grande (máximo 10 MiB).',
            );
          }
          final bytes = await file.readAsBytes();
          if (mounted) {
            setState(
              () => _file = TorboxFileUpload(
                filename: file.uri.pathSegments.last,
                bytes: bytes,
              ),
            );
          }
        } on Object {
          if (mounted) {
            setState(
              () => _error = 'No se pudo leer el archivo compartido. Impórtalo desde el selector.',
            );
          }
        }
      } else if (widget.importFile && mounted) {
        await _pickFile();
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<DownloadInput> _inputs() {
    final lines = _text.text
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    final unique = <String, DownloadInput>{};
    for (final line in lines) {
      final input = DownloadInput.parse(line);
      unique[input.key] = input;
    }
    if (unique.length > 20) {
      throw const FormatException('Añade un máximo de 20 enlaces por lote.');
    }
    return unique.values.toList();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFile(
        type: picker.FileType.custom,
        allowedExtensions: ['torrent', 'nzb'],
      );
      if (result == null || !mounted) return;
      if ((await result.length() ?? 0) > 10 * 1024 * 1024) {
        throw const FormatException('El archivo supera 10 MiB.');
      }
      final bytes = await result.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('El archivo supera 10 MiB.');
      }
      if (mounted) {
        setState(() {
          _file = TorboxFileUpload(filename: result.name, bytes: bytes);
          _error = null;
        });
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'No se pudo importar el archivo. Usa un .torrent o .nzb de hasta 10 MiB.',
        );
      }
    }
  }

  Future<void> _checkCache() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final hashes = _inputs()
          .map((i) => i.infoHash)
          .whereType<String>()
          .toList();
      if (hashes.isEmpty) {
        throw const FormatException(
          'Introduce magnets para consultar su disponibilidad.',
        );
      }
      final response = await context.read<TorboxAPI>().checkIfTorrentCached(
        hashes,
      );
      if (!response.success || response.data is! Map) {
        throw StateError('Consulta no disponible.');
      }
      if (mounted) {
        setState(() {
          for (final hash in hashes) {
            _cached[hash] = (response.data as Map).containsKey(hash);
          }
        });
      }
    } on FormatException catch (e) {
      _error = e.message;
    } on Object {
      _error = 'TorBox no pudo comprobar la caché. No se ha creado ninguna descarga.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List> _torrentBytes(Uri uri) async {
    if (uri.scheme != 'https') {
      throw const FormatException(
        'Importa el .torrent o usa una URL HTTPS para obtenerlo.',
      );
    }
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > 10 * 1024 * 1024) {
        throw const FormatException(
          'No se pudo obtener un .torrent seguro de hasta 10 MiB.',
        );
      }
      final bytes = BytesBuilder();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        bytes.add(chunk);
        if (bytes.length > 10 * 1024 * 1024) {
          throw const FormatException('El .torrent es demasiado grande.');
        }
      }
      return bytes.takeBytes();
    } finally {
      client.close();
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.read<TorboxAPI>();
    final library = context.read<LibraryPageState>();
    try {
      final inputs = _inputs();
      if (inputs.isEmpty && _file == null) {
        throw const FormatException(
          'Introduce un enlace o importa un archivo.',
        );
      }
      for (final input in inputs) {
        if (!mounted) break;
        if (_accepted.contains(input.key)) continue;
        if (input.infoHash != null &&
            library.items.whereType<Torrent>().any(
              (t) => t.hash.toLowerCase() == input.infoHash,
            )) {
          _results[input.key] = 'Ya está en tu biblioteca.';
          _accepted.add(input.key);
          continue;
        }
        final TorboxAPIResponse response = switch (input.kind) {
          DownloadInputKind.magnet => await api.createTorrent(
            magnetLink: input.uri.toString(),
          ),
          DownloadInputKind.nzbUrl => await api.createUsenetDownload(
            link: input.uri.toString(),
          ),
          DownloadInputKind.web => await api.createWebDownload(
            input.uri.toString(),
          ),
          DownloadInputKind.torrentUrl => await api.createTorrent(
            dotTorrentFile: TorboxFileUpload(
              filename: 'import.torrent',
              bytes: await _torrentBytes(input.uri),
            ),
          ),
        };
        _results[input.key] = response.success ? 'Añadida a TorBox' : 'No se confirmó la creación. Revisa la biblioteca antes de reintentar.';
        if (response.success) _accepted.add(input.key);
        if (mounted) setState(() {});
      }
      final file = _file;
      if (file != null) {
        final bytes = file.bytes;
        if (bytes.isEmpty) {
          throw const FormatException('No se pudo leer el archivo.');
        }
        final upload = file;
        final name = file.filename.toLowerCase();
        if (!name.endsWith('.torrent') && !name.endsWith('.nzb')) {
          throw const FormatException('Importa un archivo .torrent o .nzb.');
        }
        final response = name.endsWith('.torrent')
            ? await api.createTorrent(dotTorrentFile: upload)
            : await api.createUsenetDownload(nzbFile: upload);
        if (response.success) {
          _file = null;
          _results['Archivo'] = 'Archivo añadido a TorBox';
        } else {
          _error = 'No se confirmó la creación del archivo. Comprueba la biblioteca.';
        }
      }
      await library.refreshAll();
    } on FormatException catch (e) {
      _error = e.message;
    } on Object {
      _error = 'No se confirmó la operación. Consulta tu biblioteca antes de volver a enviarla.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Añadir a TorBox')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Pega un enlace por línea. Los enlaces compartidos se revisan aquí antes de enviarse.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _text,
          minLines: 4,
          maxLines: 8,
          autocorrect: false,
          enableSuggestions: false,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Magnets, URLs web o NZB',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Importar torrent / NZB'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _checkCache,
              icon: const Icon(Icons.bolt),
              label: const Text('Comprobar caché de magnets'),
            ),
          ],
        ),
        if (_file != null)
          ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(_file!.filename),
            trailing: IconButton(
              tooltip: 'Quitar archivo',
              onPressed: _busy ? null : () => setState(() => _file = null),
              icon: const Icon(Icons.close),
            ),
          ),
        ..._cached.entries.map(
          (entry) => ListTile(
            leading: Icon(entry.value ? Icons.bolt : Icons.cloud_outlined),
            title: Text(
              entry.value
                  ? 'Disponible en caché'
                  : 'No figura en la caché consultada',
            ),
            subtitle: Text(
              entry.key,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (_error != null) StatusMessage(_error!),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: Text(_busy ? 'Procesando…' : 'Añadir descargas'),
        ),
        ..._results.entries.map(
          (entry) => ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(entry.value),
            subtitle: Text(
              entry.key.startsWith('magnet:')
                  ? 'Magnet ${entry.key.substring(7)}'
                  : 'Enlace o archivo procesado',
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'TorBox limita las creaciones no cacheadas a 60 por hora. Los fallos de envío no se reintentan automáticamente.',
        ),
      ],
    ),
  );
}
