import 'package:atba/services/torbox_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:torbox_api/torbox_api.dart';

import 'common.dart';

class RssPage extends StatefulWidget {
  const RssPage({super.key});
  @override
  State<RssPage> createState() => _RssPageState();
}

class _RssPageState extends State<RssPage> {
  List<RssFeedData>? _feeds;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await context
          .read<TorboxAPI>()
          .authenticatedApi!
          .rssFeeds
          .getRssFeeds();
      if (!response.success) throw StateError('No disponible');
      if (mounted) {
        setState(() {
          _feeds = response.data ?? [];
          _error = null;
        });
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'No se pudieron cargar los feeds. RSS requiere un plan Pro y conexión con TorBox.',
        );
      }
    }
  }

  Future<void> _control(RssFeedData feed, String operation) async {
    if (_busy) return;
    if (operation == 'delete' &&
        !await confirmAction(
          context,
          '¿Eliminar el feed?',
          'Se eliminará la regla RSS en TorBox.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final response = await context
          .read<TorboxAPI>()
          .authenticatedApi!
          .rssFeeds
          .controlRssFeed(operation: operation, rssFeedId: feed.id);
      if (!response.success) throw StateError('No disponible');
      await _load();
    } on Object {
      if (mounted) {
        showResult(
          context,
          'TorBox no pudo aplicar el cambio. La regla anterior se conserva.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([RssFeedData? feed]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RssEditor(feed: feed)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Feeds RSS'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('Añadir feed'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: (_feeds?.length ?? 0) + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                const StatusMessage(
                  'Automatizaciones ejecutadas por TorBox · plan Pro. Los elementos detectados muestran si fueron descargados o ignorados.',
                ),
                if (_error != null) StatusMessage(_error!, onRetry: _load),
                if (_feeds == null && _error == null)
                  const LinearProgressIndicator(),
                if (_feeds?.isEmpty == true)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Todavía no hay feeds RSS.'),
                  ),
              ],
            );
          }
          final feed = _feeds![index - 1];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.rss_feed),
              title: Text(feed.name),
              subtitle: Text(
                '${feed.status ?? feed.state ?? 'Estado no disponible'} · cada ${feed.scanInterval ?? '—'} min\nÚltima revisión: ${feed.lastChecked}',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RssItemsPage(feed: feed)),
              ),
              trailing: PopupMenuButton<String>(
                enabled: !_busy,
                onSelected: (value) {
                  if (value == 'edit') {
                    _edit(feed);
                  } else {
                    _control(feed, value);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar regla')),
                  PopupMenuItem(value: 'update', child: Text('Revisar ahora')),
                  PopupMenuItem(value: 'pause', child: Text('Pausar')),
                  PopupMenuItem(value: 'resume', child: Text('Reanudar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class RssEditor extends StatefulWidget {
  final RssFeedData? feed;
  const RssEditor({super.key, this.feed});
  @override
  State<RssEditor> createState() => _RssEditorState();
}

class _RssEditorState extends State<RssEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _url,
      _include,
      _exclude,
      _interval,
      _age;
  bool _busy = false;
  String _type = 'torrent';
  bool? _allowDuplicates = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final f = widget.feed;
    _name = TextEditingController(text: f?.name);
    _url = TextEditingController(text: f?.url);
    _include = TextEditingController(text: f?.doRegex);
    _exclude = TextEditingController(text: f?.dontRegex);
    _interval = TextEditingController(text: '${f?.scanInterval ?? 60}');
    _age = TextEditingController(text: '${f?.dontOlderThan ?? 0}');
    _allowDuplicates = f == null ? false : f.passCheck;
    _type = f?.type ?? 'torrent';
    if (!['torrent', 'usenet', 'webdl'].contains(_type)) _type = 'torrent';
  }

  @override
  void dispose() {
    for (final c in [_name, _url, _include, _exclude, _interval, _age]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final existing = widget.feed;
    if (existing != null &&
        (existing.type == null ||
            !{'torrent', 'usenet', 'webdl'}.contains(existing.type) ||
            existing.scanInterval == null)) {
      setState(
        () => _error = 'TorBox no devolvió todos los valores actuales de esta regla. Recarga antes de editarla para evitar cambiar sus opciones por defecto.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final service = context.read<TorboxAPI>().authenticatedApi!.rssFeeds;
      final f = widget.feed;
      final response = f == null
          ? await service.addRssFeed(
              url: _url.text.trim(),
              name: _name.text.trim(),
              doRegex: _include.text,
              dontRegex: _exclude.text,
              scanInterval: int.parse(_interval.text),
              dontOlderThan: int.parse(_age.text),
              rssType: _type,
              passCheck: _allowDuplicates,
            )
          : await service.modifyRssFeed(
              rssFeedId: f.id,
              name: _name.text.trim(),
              doRegex: _include.text,
              dontRegex: _exclude.text,
              scanInterval: int.parse(_interval.text),
              dontOlderThan: int.parse(_age.text),
              rssType: _type,
              torrentSeeding: f.torrentSeeding,
              passCheck: _allowDuplicates,
            );
      if (!response.success) throw StateError('No aceptada');
      if (mounted) Navigator.pop(context, true);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'TorBox no aceptó la regla. Comprueba tu plan, el feed y sus parámetros.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.feed == null ? 'Añadir feed RSS' : 'Editar feed RSS'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (v) =>
                v?.trim().isEmpty != false ? 'Introduce un nombre' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _url,
            enabled: widget.feed == null,
            decoration: const InputDecoration(
              labelText: 'URL del feed',
              helperText:
                  'La API no permite cambiar la URL de un feed existente.',
            ),
            validator: (v) {
              final u = Uri.tryParse(v ?? '');
              return u == null ||
                      !['http', 'https'].contains(u.scheme) ||
                      u.host.isEmpty ||
                      u.userInfo.isNotEmpty
                  ? 'Introduce una URL HTTP/HTTPS sin credenciales incrustadas'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: const [
              DropdownMenuItem(value: 'torrent', child: Text('Torrent')),
              DropdownMenuItem(value: 'usenet', child: Text('Usenet')),
              DropdownMenuItem(value: 'webdl', child: Text('Web')),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) setState(() => _type = value);
                  },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _include,
            decoration: const InputDecoration(
              labelText: 'Incluir · expresión regular de TorBox',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _exclude,
            decoration: const InputDecoration(
              labelText: 'Excluir · expresión regular de TorBox',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _interval,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Intervalo de revisión (minutos)',
            ),
            validator: (v) => (int.tryParse(v ?? '') ?? 0) < 10
                ? 'El mínimo oficial es 10 minutos'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _age,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Antigüedad máxima (días; 0 sin límite)',
            ),
            validator: (v) => (int.tryParse(v ?? '') ?? -1) < 0
                ? 'Usa cero o un entero positivo'
                : null,
          ),
          SwitchListTile(
            title: const Text('Permitir duplicados del mismo enlace'),
            subtitle: _allowDuplicates == null
                ? const Text(
                    'TorBox no devuelve este valor para la regla actual. Se conserva sin modificar.',
                  )
                : null,
            value: _allowDuplicates ?? false,
            onChanged: _allowDuplicates == null || _busy
                ? null
                : (value) => setState(() => _allowDuplicates = value),
          ),
          if (_error != null) StatusMessage(_error!),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Guardando…' : 'Guardar regla'),
          ),
        ],
      ),
    ),
  );
}

class RssItemsPage extends StatefulWidget {
  final RssFeedData feed;
  const RssItemsPage({super.key, required this.feed});
  @override
  State<RssItemsPage> createState() => _RssItemsPageState();
}

class _RssItemsPageState extends State<RssItemsPage> {
  List<RssFeedItemData>? _items;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await context
          .read<TorboxAPI>()
          .authenticatedApi!
          .rssFeeds
          .getRssFeedItems(rssFeedId: widget.feed.id);
      if (!response.success) throw StateError('No disponible');
      if (mounted) {
        setState(() {
          _items = response.data ?? [];
          _error = null;
        });
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'No se pudieron obtener los elementos detectados.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.feed.name),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _items == null
        ? Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : StatusMessage(_error!, onRetry: _load),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _items!.isEmpty ? 1 : _items!.length,
            itemBuilder: (context, index) {
              if (_items!.isEmpty) {
                return const Text('No hay elementos detectados.');
              }
              final item = _items![index];
              return ListTile(
                leading: Icon(
                  item.downloaded
                      ? Icons.check_circle_outline
                      : item.ignored
                      ? Icons.block
                      : Icons.schedule,
                ),
                title: Text(item.name),
                subtitle: Text(
                  '${item.type} · ${item.status} · ${item.downloaded
                      ? 'Descargado'
                      : item.ignored
                      ? 'Ignorado'
                      : 'Pendiente'}',
                ),
              );
            },
          ),
  );
}
