import 'package:atba/services/torbox_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:torbox_api/torbox_api.dart';

import 'common.dart';

class RemoteSettingsPage extends StatefulWidget {
  const RemoteSettingsPage({super.key});
  @override
  State<RemoteSettingsPage> createState() => _RemoteSettingsPageState();
}

class _RemoteSettingsPageState extends State<RemoteSettingsPage> {
  UserSettings? _original;
  final Map<String, bool> _values = {};
  final _cdn = TextEditingController();
  final _driveFolder = TextEditingController();
  int? _seed;
  String? _error;
  bool _loading = true, _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cdn.dispose();
    _driveFolder.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await context
          .read<TorboxAPI>()
          .authenticatedApi!
          .user
          .getUserData(settings: true);
      if (!response.success || response.data?.settings == null) {
        throw StateError('Sin ajustes');
      }
      final settings = response.data!.settings!;
      if (!mounted) return;
      _original = settings;
      final fields = {
        'email': settings.emailNotifications,
        'web': settings.webNotifications,
        'mobile': settings.mobileNotifications,
        'rss': settings.rssNotifications,
        'zip': settings.allowZipped,
        'filename': settings.appendFilenameToLinks,
      };
      _values.clear();
      fields.forEach((key, value) {
        if (value != null) _values[key] = value;
      });
      _cdn.text = settings.cdnSelection ?? '';
      _driveFolder.text = settings.googleDriveFolderId ?? '';
      _seed = settings.seedTorrents;
      setState(() {
        _loading = false;
        _error = null;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudieron cargar los valores actuales. Reintenta antes de editar.';
        });
      }
    }
  }

  bool? _changed(String key, bool? original) =>
      _values[key] == original ? null : _values[key];
  Future<void> _save() async {
    final old = _original;
    if (old == null || _saving) return;
    setState(() => _saving = true);
    try {
      final response = await context
          .read<TorboxAPI>()
          .authenticatedApi!
          .user
          .editSettings(
            emailNotifications: _changed('email', old.emailNotifications),
            webNotifications: _changed('web', old.webNotifications),
            mobileNotifications: _changed('mobile', old.mobileNotifications),
            rssNotifications: _changed('rss', old.rssNotifications),
            allowZipped: _changed('zip', old.allowZipped),
            appendFilenameToLinks: _changed(
              'filename',
              old.appendFilenameToLinks,
            ),
            seedTorrents: _seed == old.seedTorrents ? null : _seed,
            cdnSelection: _cdn.text == old.cdnSelection || _cdn.text.isEmpty
                ? null
                : _cdn.text.trim(),
            googleDriveFolderId:
                _driveFolder.text == old.googleDriveFolderId ||
                    _driveFolder.text.isEmpty
                ? null
                : _driveFolder.text.trim(),
          );
      if (!response.success) throw StateError('Rechazado');
      if (mounted) showResult(context, 'Preferencias guardadas en TorBox.');
      if (mounted) await _load();
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'No se confirmó el guardado. Los valores anteriores se conservan hasta volver a consultarlos.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Preferencias de TorBox')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_error != null) StatusMessage(_error!, onRetry: _load),
              if (_original != null) ...[
                const SectionTitle('Notificaciones de tu cuenta'),
                ...{
                  'email': 'Correo electrónico',
                  'web': 'Web de TorBox',
                  'mobile': 'Móvil (servicio TorBox)',
                  'rss': 'Feed RSS de notificaciones',
                  'zip': 'Permitir archivos ZIP',
                  'filename': 'Añadir nombre de archivo a los enlaces',
                }.entries.map(
                  (entry) => SwitchListTile(
                    title: Text(entry.value),
                    value: _values[entry.key] ?? false,
                    subtitle: _values.containsKey(entry.key)
                        ? null
                        : const Text('Valor no disponible en la cuenta'),
                    onChanged: _saving || !_values.containsKey(entry.key)
                        ? null
                        : (value) => setState(() => _values[entry.key] = value),
                  ),
                ),
                const SectionTitle('Torrents y descargas'),
                if (_seed != null && [1, 2, 3].contains(_seed))
                  DropdownButtonFormField<int>(
                    initialValue: _seed,
                    decoration: const InputDecoration(
                      labelText: 'Siembra de torrents',
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Automática')),
                      DropdownMenuItem(value: 2, child: Text('Siempre')),
                      DropdownMenuItem(value: 3, child: Text('Nunca')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _seed = value),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cdn,
                  enabled: !_saving && _original!.cdnSelection != null,
                  decoration: const InputDecoration(
                    labelText: 'CDN preferida',
                    helperText: 'Se muestra el valor configurado en tu cuenta.',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _driveFolder,
                  enabled: !_saving && _original!.googleDriveFolderId != null,
                  decoration: const InputDecoration(
                    labelText: 'ID de carpeta de Google Drive',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                ),
              ],
            ],
          ),
  );
}
