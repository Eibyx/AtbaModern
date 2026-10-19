import 'package:atba/config/constants.dart';
import 'package:atba/screens/modern/dashboard_page.dart';
import 'package:atba/screens/modern/notifications_page.dart';
import 'package:atba/screens/modern/remote_settings_page.dart';
import 'package:atba/screens/modern/account_records_page.dart';
import 'package:atba/screens/settings/google_oauth.dart';
import 'package:atba/screens/setup/api_screen.dart';
import 'package:atba/services/account_overview.dart';
import 'package:atba/services/local_event_notifier.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

import 'dart:io';

import 'package:atba/services/torbox_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _googleToken = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _googleToken.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    if (_busy ||
        !await confirmAction(
          context,
          '¿Cerrar la sesión de TorBox?',
          'Se elimina la API key de este dispositivo y su caché. La credencial local de Google se conserva hasta que la elimines explícitamente.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<TorboxAPI>().deleteApiKey();
    } on Object {
      if (mounted) {
        showResult(context, 'No se pudo eliminar la credencial local.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<TorboxAPI>();
    final overview = context.watch<AccountOverview>();
    final user = overview.user;
    final mode =
        Settings.getValue<String>(Constants.theme, defaultValue: 'system') ??
        'system';
    final dynamicColors =
        Settings.getValue<bool>('modern-dynamic-colors', defaultValue: true) ??
        true;
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(user?.email ?? 'Cuenta TorBox'),
              subtitle: Text(
                '${planName(user?.plan)} · ${overview.error == null && user != null ? 'Verificada' : 'Verificación pendiente'}',
              ),
              trailing: IconButton(
                tooltip: 'Actualizar cuenta',
                onPressed: overview.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          if (overview.error != null) StatusMessage(overview.error!),
          const SectionTitle('Administrar TorBox'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Preferencias de TorBox'),
                  subtitle: const Text(
                    'Notificaciones, torrents, descargas y CDN',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RemoteSettingsPage(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Suscripción y transacciones'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountRecordsPage(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Centro de notificaciones'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Integración con Google Drive'),
          Card(
            child: GoogleDriveIntegrationSection(
              apiService: api,
              googleTokenController: _googleToken,
            ),
          ),
          const SectionTitle('Apariencia'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Tema'),
                  trailing: DropdownButton<String>(
                    value: ['system', 'light', 'dark'].contains(mode)
                        ? mode
                        : 'system',
                    items: const [
                      DropdownMenuItem(
                        value: 'system',
                        child: Text('Automático'),
                      ),
                      DropdownMenuItem(value: 'light', child: Text('Claro')),
                      DropdownMenuItem(value: 'dark', child: Text('Oscuro')),
                    ],
                    onChanged: (value) async {
                      if (value != null) {
                        await Settings.setValue(Constants.theme, value);
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                ),
                SwitchListTile(
                  title: const Text('Colores dinámicos de Android'),
                  subtitle: const Text(
                    'Usa la paleta del sistema cuando esté disponible.',
                  ),
                  value: dynamicColors,
                  onChanged: (value) async {
                    await Settings.setValue('modern-dynamic-colors', value);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
          if (!kIsWeb && Platform.isAndroid) ...[
            const SectionTitle('Avisos en este dispositivo'),
            SwitchListTile(
              title: const Text('Notificar cambios de TorBox'),
              subtitle: const Text(
                'Completadas y fallidas detectadas mientras la app está abierta. No es entrega instantánea con la app cerrada.',
              ),
              value:
                  Settings.getValue<bool>(
                    LocalEventNotifier.settingKey,
                    defaultValue: false,
                  ) ??
                  false,
              onChanged: (value) async {
                if (value) {
                  final status = await Permission.notification.request();
                  if (!status.isGranted) {
                    if (context.mounted) {
                      showResult(
                        context,
                        'Android no ha concedido permiso para notificaciones.',
                      );
                    }
                    return;
                  }
                }
                await Settings.setValue(LocalEventNotifier.settingKey, value);
                if (mounted) setState(() {});
              },
            ),
          ],
          const SectionTitle('Credenciales'),
          const ExpansionTile(
            title: Text('Cambiar API key'),
            subtitle: Text('La anterior se conserva si la nueva no se valida.'),
            leading: Icon(Icons.key_outlined),
            childrenPadding: EdgeInsets.all(16),
            children: [ApiCredentialForm()],
          ),
          TextButton.icon(
            onPressed: _busy ? null : _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión de TorBox'),
          ),
          const SectionTitle('Acerca de ATBA Modern'),
          const Text(
            'Cliente independiente de administración TorBox. Basado en ATBA de 93Pd9s8Jt. Licencia GPL-3.0; se conservan las atribuciones del proyecto original.',
          ),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://github.com/Eibyx/AtbaModern'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Código fuente'),
          ),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'ATBA Modern',
            ),
            child: const Text('Licencias'),
          ),
        ],
      ),
    );
  }
}
