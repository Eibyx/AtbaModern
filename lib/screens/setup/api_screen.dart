import 'package:atba/services/torbox_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ApiKeyScreen extends StatelessWidget {
  const ApiKeyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              Icon(
                Icons.cloud_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'ATBA Modern',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Administra tu cuenta TorBox. Tu API key se comprueba antes de guardarse en almacenamiento seguro.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              const ApiCredentialForm(),
            ],
          ),
        ),
      ),
    ),
  );
}

class ApiCredentialForm extends StatefulWidget {
  const ApiCredentialForm({super.key});
  @override
  State<ApiCredentialForm> createState() => _ApiCredentialFormState();
}

class _ApiCredentialFormState extends State<ApiCredentialForm> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await context.read<TorboxAPI>().validateAndSaveApiKey(
        _controller.text,
      );
      if (!mounted) return;
      setState(
        () => _message = result.success
            ? 'API key verificada y guardada.'
            : result.detailOrUnknown,
      );
      if (result.success) _controller.clear();
    } on Object {
      if (mounted) {
        setState(
          () => _message = 'No se pudo comprobar la credencial. Tu sesión anterior se conserva.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _controller,
        enabled: !_busy,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        onSubmitted: (_) => _save(),
        decoration: const InputDecoration(
          labelText: 'API key de TorBox',
          prefixIcon: Icon(Icons.key_outlined),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Verificando…' : 'Verificar y guardar'),
      ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_message!),
        ),
    ],
  );
}
