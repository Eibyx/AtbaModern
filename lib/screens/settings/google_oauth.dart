import 'package:atba/services/google_drive_session.dart';
import 'package:atba/services/torbox_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class GoogleDriveIntegrationSection extends StatefulWidget {
  final TorboxAPI apiService;
  final TextEditingController googleTokenController;
  const GoogleDriveIntegrationSection({
    super.key,
    required this.apiService,
    required this.googleTokenController,
  });
  @override
  State<GoogleDriveIntegrationSection> createState() =>
      _GoogleDriveIntegrationSectionState();
}

class _GoogleDriveIntegrationSectionState
    extends State<GoogleDriveIntegrationSection> {
  bool _busy = false;
  String? _error;
  static final _oauthUrl = Uri.parse(
    'https://api.torbox.app/v1/api/integration/oauth/google',
  );

  Future<void> _save(String value, String expiry) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.apiService.saveGoogleToken(value, expiry);
      widget.googleTokenController.clear();
    } on Exception {
      _error = 'No se pudo guardar la credencial de Google de forma segura.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.apiService.googleSession;
    final expired = session?.isExpired(DateTime.now()) ?? false;
    final status = session == null
        ? 'Sin credencial local'
        : expired
        ? 'Credencial caducada · vuelve a conectar'
        : session.expiresAt == null
        ? 'Credencial guardada · vigencia sin verificar'
        : 'Credencial guardada · vence ${session.expiresAt!.toLocal()}';
    return ExpansionTile(
      leading: const Icon(Icons.drive_file_move_outline),
      title: const Text('Google Drive'),
      subtitle: Text(status),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        const Text(
          'La sesión se conserva en almacenamiento seguro. Los errores temporales de red no la eliminan. La validez real se comprueba al realizar una transferencia.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  if (kIsWeb) {
                    await launchUrl(
                      _oauthUrl,
                      mode: LaunchMode.externalApplication,
                    );
                    return;
                  }
                  final result = await Navigator.of(context)
                      .push<GoogleDriveSession>(
                        MaterialPageRoute(
                          builder: (_) => _GoogleOAuthPage(url: _oauthUrl),
                        ),
                      );
                  if (!mounted || result == null) return;
                  await _save(
                    result.accessToken,
                    result.expiresAt?.toIso8601String() ?? '',
                  );
                },
          icon: const Icon(Icons.link),
          label: Text(
            session == null
                ? 'Conectar Google Drive'
                : 'Reconectar Google Drive',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.googleTokenController,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Token manual de Google',
            helperText: 'Sin fecha conocida se mostrará como no verificado.',
          ),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _save(widget.googleTokenController.text.trim(), ''),
          child: const Text('Guardar token manual'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (session != null)
          TextButton.icon(
            icon: const Icon(Icons.link_off),
            label: const Text('Eliminar credencial local'),
            onPressed: _busy
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('¿Eliminar la conexión local?'),
                        content: const Text(
                          'La API key de TorBox se conserva. Esto no revoca el acceso de Google desde otros dispositivos.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !mounted) return;
                    try {
                      await widget.apiService.deleteGoogleToken();
                      if (mounted) setState(() {});
                    } on Exception {
                      if (mounted)
                        setState(
                          () => _error =
                              'No se pudo eliminar la credencial local.',
                        );
                    }
                  },
          ),
      ],
    );
  }
}

class _GoogleOAuthPage extends StatefulWidget {
  final Uri url;
  const _GoogleOAuthPage({required this.url});
  @override
  State<_GoogleOAuthPage> createState() => _GoogleOAuthPageState();
}

class _GoogleOAuthPageState extends State<_GoogleOAuthPage> {
  bool _finished = false;
  String? _error;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Autorizar Google Drive')),
    body: Column(
      children: [
        if (_error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url.toString())),
            initialSettings: InAppWebViewSettings(
              incognito: true,
              useShouldOverrideUrlLoading: true,
            ),
            shouldOverrideUrlLoading: (controller, action) async {
              final url = action.request.url;
              if (url == null) return NavigationActionPolicy.CANCEL;
              final uri = Uri.parse(url.toString());
              if (uri.scheme != 'https') return NavigationActionPolicy.CANCEL;
              final session = GoogleDriveSession.fromCallback(uri);
              if (session != null) {
                if (!_finished && mounted) {
                  _finished = true;
                  Navigator.pop(context, session);
                }
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
            onReceivedError: (_, __, ___) {
              if (mounted)
                setState(
                  () => _error = 'No se pudo completar la conexión. Tu sesión anterior se conserva.',
                );
            },
          ),
        ),
      ],
    ),
  );
}
