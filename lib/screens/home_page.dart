import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:atba/screens/modern/account_page.dart';
import 'package:atba/screens/modern/add_download_page.dart';
import 'package:atba/screens/modern/automations_page.dart';
import 'package:atba/screens/modern/dashboard_page.dart';
import 'package:atba/screens/modern/downloads_page.dart';
import 'package:atba/services/account_overview.dart';
import 'package:atba/services/library_page_state.dart';
import 'package:atba/services/torbox_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:listen_sharing_intent/listen_sharing_intent.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LibraryPageState(context)),
      ChangeNotifierProvider(
        create: (_) => AccountOverview(context.read<TorboxAPI>())..refresh(),
      ),
    ],
    child: const ModernShell(),
  );
}

class ModernShell extends StatefulWidget {
  const ModernShell({super.key});
  @override
  State<ModernShell> createState() => _ModernShellState();
}

class _ModernShellState extends State<ModernShell> {
  int _index = 0;
  final Map<int, Widget> _pages = {};
  StreamSubscription<Uri>? _links;
  StreamSubscription<List<SharedMediaFile>>? _shares;
  final Map<String, DateTime> _recentInputs = {};
  bool _openingInput = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _listenForInputs();
    });
  }

  void _select(int index) {
    context.read<LibraryPageState>().setVisible(index == 0 || index == 1);
    setState(() => _index = index);
  }

  Future<void> _openInput({String? text, String? file}) async {
    if (!mounted || _openingInput) return;
    final key = text ?? file ?? '';
    if (key.isEmpty) return;
    final now = DateTime.now();
    _recentInputs.removeWhere(
      (_, time) => now.difference(time) > const Duration(seconds: 3),
    );
    if (_recentInputs.containsKey(key)) return;
    _recentInputs[key] = now;
    _openingInput = true;
    try {
      await openAddDownload(context, initialText: text, initialFile: file);
    } finally {
      _openingInput = false;
    }
  }

  Future<void> _shared(List<SharedMediaFile> files) async {
    // Review one shared payload at a time; no unsolicited remote mutations.
    for (final file in files) {
      if (!mounted) return;
      if (file.type == SharedMediaType.file) {
        await _openInput(file: file.path);
      } else if (file.type == SharedMediaType.text ||
          file.type == SharedMediaType.url) {
        await _openInput(text: file.path);
      }
    }
  }

  Future<void> _listenForInputs() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final appLinks = AppLinks();
      _links = appLinks.uriLinkStream.listen(
        (uri) {
          if (uri.scheme == 'magnet' ||
              uri.scheme == 'https' ||
              uri.scheme == 'http') {
            _openInput(text: uri.toString());
          }
        },
        onError: (Object error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enlace externo no válido.')),
            );
          }
        },
      );
      final initial = await appLinks.getInitialLink();
      if (initial != null &&
          mounted &&
          ['magnet', 'https', 'http'].contains(initial.scheme)) {
        await _openInput(text: initial.toString());
      }
      if (!mounted) return;
      _shares = ReceiveSharingIntent.instance.getMediaStream().listen(
        _shared,
        onError: (Object error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se pudo leer el contenido compartido. Usa Añadir para importarlo.',
                ),
              ),
            );
          }
        },
      );
      final initialFiles = await ReceiveSharingIntent.instance
          .getInitialMedia();
      if (mounted && initialFiles.isNotEmpty) await _shared(initialFiles);
      ReceiveSharingIntent.instance.reset();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La recepción de enlaces no está disponible. Puedes añadirlos manualmente.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _links?.cancel();
    _shares?.cancel();
    super.dispose();
  }

  Widget _page(int index) => _pages.putIfAbsent(
    index,
    () => switch (index) {
      0 => DashboardPage(onDownloads: () => _select(1)),
      1 => const DownloadsPage(),
      2 => const AutomationsPage(),
      _ => const AccountPage(),
    },
  );
  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: List.generate(
        4,
        (i) => _pages.containsKey(i) || i == _index
            ? _page(i)
            : const SizedBox.shrink(),
      ),
    );
    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.space_dashboard_outlined),
        selectedIcon: Icon(Icons.space_dashboard),
        label: 'Inicio',
      ),
      NavigationDestination(
        icon: Icon(Icons.cloud_download_outlined),
        selectedIcon: Icon(Icons.cloud_download),
        label: 'Descargas',
      ),
      NavigationDestination(
        icon: Icon(Icons.auto_awesome_motion_outlined),
        selectedIcon: Icon(Icons.auto_awesome_motion),
        label: 'Automatizaciones',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Cuenta',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations
                      .map(
                        (d) => NavigationRailDestination(
                          icon: d.icon,
                          selectedIcon: d.selectedIcon,
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: destinations,
          ),
        );
      },
    );
  }
}
